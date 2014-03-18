-- How often (in seconds) ports file saves, if there have been modifications
local save_delay = 20

-- location of save file.  Should be in /path_to_minetest/mods/mod_dir_name/ports
local ports_file = minetest.get_modpath('lyghtport')..'/ports'

-- port arrays
local portpos = {}

-- when to update the save file
local updated = false

-- load port locations from file
local function loadports()
	local input = io.open(ports_file, "r")
	if input then
		-- read forever
		while true do
			local x = input:read("*n")
			if x == nil then
				-- reached end of file
				break
			end
			
			local y = input:read("*n")
			local z = input:read("*n")
			local key = input:read("*l")
			local point, user = string.match(key, " *([%w%-]+) *(%w*)")
			
			-- initialize our variable
			if not portpos[user] then
			 	portpos[user] = {}
			end
			portpos[user][point] = {x = x, y = y, z = z}
		end

		io.close(input)
	else
		-- No file, set an empty array
		portpos = {}
	end
end

loadports()

-- register our chat commands.  if these conflict with another addon, feel free to change them.  Just remember the "Usage" messages.
minetest.register_privilege("port", "Can use /port and /setport commands")
minetest.register_privilege("port_other", "Can use /port <player> command | /summon <player>")
minetest.register_privilege("setport_other", "Can use /setport <player> command")

-- Teleport player to a saved location
minetest.register_chatcommand("port", {
	privs = {port=true},
	description = "Teleport yourself or another player to a saved point",
	func = function(name, param)

		-- were the correct number of parameters sent? 2+
		if param == "" then
			minetest.chat_send_player(name, "Usage: /port <location> | /port <player> <location>")
			return
		end

		-- split the string
		local user, point = string.match(param, " *([%w%-]+) *(%w*)")

		-- switch user/point strings when there is no user set
		if not point or point == "" then
			point = user
			user = name
		end

		-- Do we have permissions to port the user? 
		if user ~= name then
			if not minetest.get_player_privs(name)["port_other"] then
				minetest.chat_send_player(name, "You do not have sufficient permissions to run this command (missing privileges: port_other)")
				return
			end
		end
	
		-- Does the specified port location exist?
		if not portpos[user][point] then
			minetest.chat_send_player(name, "I can not find the port location. Use /setport <location> | /setport <player> <location> first.")
			return
		end

		-- Make sure our target player exists
		local player = minetest.env:get_player_by_name(user)
		if player == nil then
			return
		end

		-- port the player
		player:setpos(portpos[user][point])
		minetest.chat_send_player(name, "Teleported " .. user .. " to " .. point .. ".")
	end,
})

-- Save location to teleport player to
minetest.register_chatcommand("setport", {
	privs = {port=true},
	description = "Save a port location for you or another player",
	func = function(name, param)

		-- make sure we receive args
		if param == "" then
			minetest.chat_send_player(name, "Usage: /setport <location> | /setport <player> <location>")
			return
		end

		local user, point = string.match(param, "([%w%-]+) *(%w*)")

		if point ~= "" then
			if not minetest.get_player_privs(name)["setport_other"] then
				minetest.chat_send_player(name, "You do not have sufficient permissions to run this command (missing privileges: setport_other)")
				return
			end
		else
			point = user
			user = name
		end

		-- Make sure the player saving is still in game
		local player = minetest.env:get_player_by_name(name)

		if player == nil then
			return
		else
			-- Save location based on calling player's location
			local pos = player:getpos()
			minetest.chat_send_player(name, "Saving " .. point .. " - " .. user)
			if not portpos[user] then
				portpos[user] = {}
			end
			portpos[user][point] = pos
			updated = true
		end
	end,
})

local save_time = 0

-- Save every x seconds
minetest.register_globalstep(function(dtime)
	-- increase counter
	save_time = save_time + dtime
	if save_time > save_delay then
		save_time = save_time - save_delay
		-- Do we have anything to update?
		if updated then
			-- open file and save teleport locations
			local output = io.open(ports_file, "w")
			for user, a in pairs(portpos) do
				for point, v in pairs(a) do
			   		output:write(v.x .. " " .. v.y .. " " .. v.z .. " " .. point .. " " .. user .. "\n")
			   	end
			end
			io.close(output)
			updated = false
		end
	end
end)

-- Teleport another player to your location
minetest.register_chatcommand("summon", {
	privs = {port_other=true},
	description = "Summon other players to your location",
	func = function(name, param)
		local user

		if param == "" then 
			minetest.chat_send_player(name, "Usage: /summon <player>.  Note: You cannot summon yourself")
			return
		else
			user = string.match(param, "(%w+)")
		end

		-- make sure both players still exist
		local player = minetest.env:get_player_by_name(user)
		local summoner = minetest.env:get_player_by_name(name)

		if player == nil or summoner == nil then
			return false
		end

		-- Get summoner's position and port the target player
		local pos = summoner:getpos()
		player:setpos(pos)
	end,
})

-- Show the teleport location of players by name
minetest.register_chatcommand("showports", {
	privs = {port=true},
	description = "Show your point ports point",
	func = function(name, param)
		local user
		if param ~= "" then
			user = string.match(param, "(%w+)")
			if not minetest.get_player_privs(name)["port_other"] then
				minetest.chat_send_player(name, "You do not have permission to run this command (missing privileges: port_other)")
				return
			end
		else
			user = name
		end

		local player = minetest.env:get_player_by_name(name)
		-- make sure player still exists
		if player == nil then
			return false
		end

		-- empty array?
		if not portpos[user] then
			minetest.chat_send_player(name, "The player does not have any port locations set.  Set them by using /setport <location> | /setport <player> <location>")
			return
		else
			-- display list of saved locations
			minetest.chat_send_player(name, "Saved locations for " .. user .. " :")
			for point, a in pairs(portpos[user]) do
				minetest.chat_send_player(name, "  "..point)
			end
		end
	end,
})
