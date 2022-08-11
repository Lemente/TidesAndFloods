local abm_long_delay = 10
local abm_short_delay = 0.2

local get_node = minetest.get_node

-- a list of nodes that should not be considered land/shore
local water_or_air = {
		["air"] = true,
		["default:water_source"] = true,
		["default:water_flowing"] = true,
--		["default:river_water_source"] = true,
		["default:river_water_flowing"] = true,
		["tides:water"] = true,
		["tides:air"] = true,
		["tides:wave"] = true,
		["tides:surface"] = true,
		["tides:offshore_water"] = true,
		["tides:seawater"] = true,
		["tides:shorewater"] = true,
		["ignore"] = true --/!\--
		}

-- To DO : target every airlike node?
local air_and_friends = {
		["air"] = true,
		["default:water_flowing"] = true,
		["default:river_water_flowing"] = true,
--		["tides:wave"] = true,
		["ignore"] = true --/!\--
		}

local water_and_friends = {
		["default:water_source"] = true,
		["default:water_flowing"] = true,
--		["default:river_water_source"] = true,
		["default:river_water_flowing"] = true,
		["tides:water"] = true,
		["tides:air"] = true,
		["tides:wave"] = true,
		["tides:offshore_water"] = true,
		["tides:seawater"] = true,
		["tides:shorewater"] = true,
		["ignore"] = true --/!\--
		}

-- OFFSHORE_WATER ABM
minetest.register_abm({
	name="tidesandfloods:offshore_water_abm",
	nodenames={"tides:offshore_water"},
	interval = abm_long_delay, --increase for performance. No need to check for it every seconds
	chance = 1,
	catch_up = false,
	action=function(pos,node)
		local cardinal_pos ={
				{x=pos.x+1, y=pos.y, z=pos.z},
				{x=pos.x-1, y=pos.y, z=pos.z},
				{x=pos.x, y=pos.y, z=pos.z+1},
				{x=pos.x, y=pos.y, z=pos.z-1}
			}
		local cardinal_node = {
				get_node({x=pos.x+1, y=pos.y, z=pos.z}).name,
				get_node({x=pos.x-1, y=pos.y, z=pos.z}).name,
				get_node({x=pos.x, y=pos.y, z=pos.z+1}).name,
				get_node({x=pos.x, y=pos.y, z=pos.z-1}).name
			}
		if pos.y < tidesandfloods.sealevel then
			minetest.set_node(pos,{name="tides:seawater"})
			for i = 1,4 do
			local status = "active"
				if minetest.compare_block_status(cardinal_pos[i], status) ~= true then
--				if cardinal_node[i] == ignore then
					minetest.set_node({x=pos.x, y=pos.y+1, z=pos.z},{name="tides:offshore_water"})
				break
				end
			end
		end
		if pos.y == tidesandfloods.sealevel then
			for i = 1,4 do
				if air_and_friends[cardinal_node[i]] then
					minetest.set_node(cardinal_pos[i],{name="tides:wave"})
				end
			end
		end

	end
})

-- WAVE ABM
minetest.register_abm({
	name="tidesandfloods:wave_abm",
	nodenames={"tides:wave"},
	interval = abm_short_delay,
	chance = 1,
	catch_up = false,
	action=function(pos,node)
		local cardinal_pos =  {{x=pos.x+1, y=pos.y, z=pos.z},
							   {x=pos.x-1, y=pos.y, z=pos.z},
							   {x=pos.x, y=pos.y, z=pos.z+1},
							   {x=pos.x, y=pos.y, z=pos.z-1}}

		local cardinal_node = {get_node(cardinal_pos[1]).name,
							   get_node(cardinal_pos[2]).name,
							   get_node(cardinal_pos[3]).name,
							   get_node(cardinal_pos[4]).name}

		local cardinal_down_pos =  {{x=pos.x+1, y=pos.y-1, z=pos.z},
								    {x=pos.x-1, y=pos.y-1, z=pos.z},
								    {x=pos.x, y=pos.y-1, z=pos.z+1},
								    {x=pos.x, y=pos.y-1, z=pos.z-1}}

		local cardinal_down_node = {get_node(cardinal_down_pos[1]).name,
								    get_node(cardinal_down_pos[2]).name,
								    get_node(cardinal_down_pos[3]).name,
								    get_node(cardinal_down_pos[4]).name}
		local edge_x = pos.x % 16
		local edge_z = pos.z % 16
		-- TIDE GOES DOWN
		if pos.y > tidesandfloods.sealevel then
			minetest.set_node(pos,{name="air"})
			minetest.after(0.1, function()
				for i = 1,4 do
					if water_and_friends[cardinal_node[i]] and cardinal_node[i] ~= "tides:wave" then
						 minetest.set_node(cardinal_pos[i],{name="tides:wave"})
					end
				end
			end)
			-- CHANGE NODES BELOW
				if get_node({x=pos.x, y=pos.y-1, z=pos.z}).name == "tides:seawater" then -- make node below wave or mapblock edge
					if (edge_x == 0 or edge_x == 15) and (edge_z == 0 or edge_z == 15) then -- if node border mapblock
						minetest.set_node({x=pos.x, y=pos.y-1, z=pos.z},{name="tides:offshore_water"})
						do return end
					end
					for i = 1,4 do
						if water_or_air[cardinal_down_node[i]] == nil then
							minetest.set_node({x=pos.x, y=pos.y-1, z=pos.z},{name="tides:shorewater"})
							do return end
							break
						end
					end
				end
			--minetest.set_node(pos,{name="air"})
		-- TIDE GOES UP
		elseif pos.y <= tidesandfloods.sealevel then
			-- look for air around, set wave there, become seawater
			for i = 1,4 do
			local drawtype = minetest.registered_nodes[cardinal_node[i]].drawtype
			local plant = minetest.get_item_group(cardinal_node[i], "flora")
			+ minetest.get_item_group(cardinal_node[i], "grass")
			+ minetest.get_item_group(cardinal_node[i], "flowers")
			+ minetest.get_item_group(cardinal_node[i], "sapling")
			local float = minetest.get_item_group(cardinal_node[i], "float")
				if air_and_friends[cardinal_node[i]]
					or (drawtype == "plantlike" and plant >= 1)
					or float >= 1
					then
					-- make things from float group rise with the tide
					if float >= 1 then
						local cardinal_pos_up = vector.add(cardinal_pos[i],(vector.new(0,1,0)))
						local cardinal_node_up = get_node(cardinal_pos_up).name
						if air_and_friends[cardinal_node_up] then
--							local float_node = cardinal_node[i]
							minetest.set_node(cardinal_pos[i], {name = tostring(cardinal_node_up)})
							minetest.set_node(cardinal_pos_up, {name = cardinal_node[i]})
						else break
						end
					end
					--minetest.chat_send_all("found air")
					minetest.after(0.1, function()
						minetest.set_node(cardinal_pos[i],{name="tides:wave"})
						if (edge_x == 0 or edge_x == 15) and (edge_z == 0 or edge_z == 15) then -- if node border mapblock
							--minetest.chat_send_all("become offshore_water")
							minetest.set_node({x=pos.x, y=pos.y, z=pos.z},{name="tides:offshore_water"})
						else
							--minetest.chat_send_all("don't become offshore_water")
							local shore = false
							for  j = 1,4 do --check for shore
								if water_or_air[cardinal_node[j]] == nil then
									--minetest.chat_send_all("become shorewater")
									minetest.set_node(pos,{name="tides:shorewater"})
									shore = true
									break
								end
							end
							if shore == false then --else become seawater
								--minetest.chat_send_all("become seawater" .. tostring(pos))
								minetest.set_node(pos,{name="tides:seawater"})
							end
						end
					end)
				end
			end
			for i = 1,4 do
				if water_or_air[cardinal_node[i]] == nil then
					minetest.set_node(pos,{name="tides:shorewater"})
				end
			end
			-- CLEAN BELOW THE SURFACE AS TIDE GOES
--			minetest.chat_send_all("node below is " .. tostring(get_node({x=pos.x, y=pos.y-1, z=pos.z}).name))
			local node_below = get_node({x=pos.x, y=pos.y-1, z=pos.z}).name
			if  node_below ~= "tides:seawater" and water_and_friends[node_below] then
--				minetest.chat_send_all("turning it to seawater ")
				minetest.set_node({x=pos.x, y=pos.y-1, z=pos.z},{name="tides:seawater"})
				--do return end -- we don't need to look further once it has been turned to seawater
			end
			--if surrounded by seawater, become seawater
		local seawater = 0
			for i = 1,4 do
				if water_and_friends[cardinal_node[i]] then
					seawater = seawater + 1
				end
			end
			if seawater == 4 then
				if (edge_x == 0 or edge_x == 15) and (edge_z == 0 or edge_z == 15) then -- if node border mapblock
					minetest.set_node({x=pos.x, y=pos.y, z=pos.z},{name="tides:offshore_water"})
				else
					minetest.set_node({x=pos.x, y=pos.y, z=pos.z},{name="tides:seawater"})
				end
			end
		end
	end
})

-- SHOREWATER ABM
minetest.register_abm({
	name="tidesandfloods:shorewater_abm",
	nodenames={"tides:shorewater"},
	interval = abm_long_delay,
	chance = 1,
	catch_up = false,
	action=function(pos,node)
		local cardinal_pos =  {
			{x=pos.x+1, y=pos.y, z=pos.z},
			{x=pos.x-1, y=pos.y, z=pos.z},
			{x=pos.x, y=pos.y, z=pos.z+1},
			{x=pos.x, y=pos.y, z=pos.z-1}
		}
		local cardinal_node = {
			get_node(cardinal_pos[1]).name,
			get_node(cardinal_pos[2]).name,
			get_node(cardinal_pos[3]).name,
			get_node(cardinal_pos[4]).name
		}
		if pos.y > tidesandfloods.sealevel then
			minetest.set_node(pos,{name="tides:wave"})
	elseif pos.y <= tidesandfloods.sealevel then
			local count_water = 0
			for j = 1,4 do
				if air_and_friends[cardinal_node[j]] then
					minetest.set_node(pos,{name="tides:seawater"})
					break
				end
				if water_and_friends[cardinal_node[j]] then
					count_water = count_water + 1
				end
			end
			if count_water == 4 then
				minetest.set_node(pos,{name="tides:seawater"})
			end
		end
	end
})