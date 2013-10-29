
teleporters.network = {}

teleporters.file = minetest.get_worldpath()..'/teleporters'

teleporters.load = function()
	local f = io.open(teleporters.file, "r")  
	if f then
		local contents = f:read()
		io.close(f)
		if contents ~= nil then 
			local entries = contents:split(";") 
			for i,entry in pairs(entries) do
				local id, coords = unpack(entry:split(":"))
				local p = {}
				p.x, p.y, p.z = string.match(coords, "^([%d.-]+)[, ] *([%d.-]+)[, ] *([%d.-]+)$")
				if p.x and p.y and p.z then
					teleporters.network[tonumber(id)] = {x = tonumber(p.x),y= tonumber(p.y),z = tonumber(p.z)}
				end
			end
		end
	end
end

teleporters.load()

