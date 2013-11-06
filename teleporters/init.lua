-- Teleporters mod by Zeg9
-- Licensed under the WTFPL
-- Have fun :D

teleporters = {}

--Configuration
local PLAYER_COOLDOWN = 1
local going_up_effect = true
-- end config

teleporters.copy_pos = function (_pos)
	return {x=_pos.x, y=_pos.y, z=_pos.z}
end

teleporters.is_safe = function (pos)
	ok = false
	if minetest.env:get_node(pos).name ~= "air" then
		pos.y = pos.y +1
		if minetest.env:get_node(pos).name == "air" then
			pos.y = pos.y +1
			if minetest.env:get_node(pos).name == "air" then
				ok = true
			end
			pos.y = pos.y -1
		end
		pos.y = pos.y -1
	end
	return ok
end

teleporters.find_safe = function (_pos)
	pos = teleporters.copy_pos(_pos)

	pos.x = pos.x +1
	if teleporters.is_safe(pos) then return pos end

	pos.x = pos.x -2
	if teleporters.is_safe(pos) then return pos end

	pos.x = pos.x +1
	pos.z = pos.z +1
	if teleporters.is_safe(pos) then return pos end

	pos.z = pos.z -2
	if teleporters.is_safe(pos) then return pos end

	return _pos
end


dofile(minetest.get_modpath("teleporters").."/legacy.lua")

teleporters.make_formspec = function (meta)
	formspec = "size[6,3]" ..
	"field[1,1.25;4.5,1;desc;Description;"..meta:get_string("infotext").."]"..
	"button_exit[2,2;2,1;save;Save]"
	return formspec
end

teleporters.teleport = function (params)
	params.obj:setpos(params.target)
	print(dump(params.target))
end

teleporters.reset_cooldown = function (params)
	teleporters.is_teleporting[params.playername] = false
end

teleporters.selected = {}
-- teleporters.selected[player_name] = pos


local hacky_swap_node = function(pos,name)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local meta0 = meta:to_table()
	if node.name == name then
		return
	end
	node.name = name
	local meta0 = meta:to_table()
	minetest.set_node(pos,node)
	meta = minetest.get_meta(pos)
	meta:from_table(meta0)
end

-- Nodes and items

minetest.register_node("teleporters:unlinked", {
	description = "Teleporter (unlinked)",
	tiles = {
		"teleporters_top_unlinked.png",
		"teleporters_bottom.png",
		"teleporters_side.png",
	},
	groups = {cracky=1,not_in_creative_inventory=1},
	sounds = default.node_sound_stone_defaults(),
	on_receive_fields = function(pos, formname, fields, sender)
		if fields.desc then
			local meta = minetest.env:get_meta(pos)
			meta:set_string("infotext",fields.desc)
			meta:set_string("formspec",teleporters.make_formspec(meta))
		end
	end,
	drop = "teleporters:teleporter",
})
minetest.register_node("teleporters:teleporter", {
	description = "Teleporter",
	tiles = {
		--"teleporters_top.png",
		{name="teleporters_top_animated.png", animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=0.5}},
		"teleporters_bottom.png",
		"teleporters_side.png",
	},
	groups = {cracky=1},
	sounds = default.node_sound_stone_defaults(),
	light_source = 10,
	after_place_node = function(pos, placer, itemstack)
		local meta = minetest.get_meta(pos)
		local name = placer:get_player_name()
		meta:set_string("infotext","Teleporter")
		meta:set_string("formspec",teleporters.make_formspec(meta))
		if teleporters.selected[name] ~= nil then
			-- link teleporters
			local target = teleporters.selected[name]
			if target.x == pos.x
			and target.y == pos.y
			and target.z == pos.z then
				hacky_swap_node(pos, "teleporters:unlinked")
			else
				local target_name = minetest.get_node(target).name
				if target_name ~= "teleporters:unlinked" then
					teleporters.selected[name] = nil
					return
				end
				meta:set_string("target",minetest.pos_to_string(target))
				local target_meta = minetest.get_meta(target)
				target_meta:set_string("target",minetest.pos_to_string(pos))
				hacky_swap_node(pos, "teleporters:teleporter")
				hacky_swap_node(target, "teleporters:teleporter")
				teleporters.selected[name] = nil
			end
		else
			hacky_swap_node(pos, "teleporters:unlinked")
			teleporters.selected[name] = pos
			local playername = placer:get_player_name()
			if playername ~= nil then
				minetest.chat_send_player(playername, '<teleporter> ('..pos.x..' | '..pos.y..' | '..pos.z..')')
			end
		end
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		if fields.desc then
			local meta = minetest.env:get_meta(pos)
			meta:set_string("infotext",fields.desc)
			meta:set_string("formspec",teleporters.make_formspec(meta))
		end
	end,
	node_placement_prediction = "teleporters:unlinked",
})


teleporters.is_teleporting = {}

teleporters.use_teleporter = function(obj,pos)
	if obj:is_player() then
		if teleporters.is_teleporting[obj:get_player_name()] then
			return
		end
		teleporters.is_teleporting[obj:get_player_name()] = true
	end
	local meta = minetest.env:get_meta(pos)
	local target = pos
	if meta:get_string("target") ~= "" then
		target = minetest.string_to_pos(meta:get_string("target"))
	elseif meta:get_int("id") > 0 then -- Compatibility with older versions
		if meta:get_int("id") %2 == 0 then
			target = teleporters.network[meta:get_int("id")-1]
		else
			target = teleporters.network[meta:get_int("id")+1]
		end
		meta:set_string("target",minetest.pos_to_string(target)) -- convert to new behavior
		meta:set_string("formspec", teleporters.make_formspec(meta))
	end

	local newpos = teleporters.find_safe(teleporters.copy_pos(target))
	if obj:is_player() then
		minetest.sound_play("teleporters_teleport",{gain=1,to_player=obj:get_player_name()})
	end
	newpos.y = newpos.y + .5
	if going_up_effect then
		newpos.y = newpos.y-1
		teleporters.teleport({obj=obj,target=newpos})
		newpos.y = newpos.y+1
	end
	minetest.after(.1, teleporters.teleport, {obj=obj,target=newpos}) -- TODO: particles and change player yaw
	if obj:is_player() then
		minetest.after(PLAYER_COOLDOWN, teleporters.reset_cooldown, {playername=obj:get_player_name()})
	end
end

-- ABM is kept for items and other objects (eg. ufos)
minetest.register_abm({
	nodenames = {"teleporters:teleporter"},
	interval = 1,
	chance = 1,
	action = function(pos, node)
		local meta = minetest.env:get_meta(pos)
		--[[if meta:get_string("target") ~= "" then
			local target = minetest.string_to_pos(meta:get_string("target"))
			local target_name = minetest.get_node(target).name
			if target_name ~= "ignore" and target_name ~= "teleporters:teleporter" then -- target has been removed, unlink
				meta:set_string("target","")
				hacky_swap_node(pos,"teleporters:unlinked")
			end
		end]]
		pos.y = pos.y+.5
		local objs = minetest.env:get_objects_inside_radius(pos, .5)
		pos.y = pos.y -.5
		for _, obj in pairs(objs) do
			teleporters.use_teleporter(obj,pos)
		end
	end,
})

-- globalstep for players
minetest.register_globalstep(function(dtime)
	for i, player in ipairs(minetest.get_connected_players()) do
		pos = player:getpos()
		pos = {x=math.floor(pos.x+.5),y=math.floor(pos.y),z=math.floor(pos.z+.5)}
		if minetest.get_node(pos).name == "teleporters:teleporter" then
			teleporters.use_teleporter(player,pos)
		end
	end
end)

-- Crafting

minetest.register_craft({
	output = "teleporters:teleporter",
	recipe = {
		{"default:mese_crystal", "default:coal_lump", "default:mese_crystal"},
		{"default:steel_ingot", "default:obsidian", "default:steel_ingot"},
		{"default:diamond", "default:diamond", "default:diamond"}
	},
})

