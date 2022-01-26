--Addon written on 1/17/2022 by RussEfarmer
--UTILITIES
--Initialize our tables
local function mb_initialize()
	if sql.TableExists("mb_mutebandata") && sql.TableExists("mb_gagbandata") then
		print("Mute/gagban tables are ready")
	else
		--Creates tables mb_mutebandata & mb_gagbandata, creates indexes mb_mutebandata_index and mb_gagbandata_index
		if not sql.TableExists("mb_mutebandata") then
			sql.Query("CREATE TABLE IF NOT EXISTS mb_mutebandata (steamid VARCHAR(255) PRIMARY KEY, username VARCHAR(255), ban_length INT, ban_time INT, reason VARCHAR(255), admin_username VARCHAR(255), admin_steamid VARCHAR(255));")
			sql.Query("CREATE INDEX IF NOT EXISTS mb_mutebandata_index ON mb_mutebandata (steamid);")
			print("Muteban table created for the first time")
		end
		if not sql.TableExists("mb_gagbandata") then
			sql.Query("CREATE TABLE IF NOT EXISTS mb_gagbandata (steamid VARCHAR(255) PRIMARY KEY, username VARCHAR(255), ban_length INT, ban_time INT, reason VARCHAR(255), admin_username VARCHAR(255), admin_steamid VARCHAR(255));")
			sql.Query("CREATE INDEX IF NOT EXISTS mb_gagbandata_index ON mb_gagbandata (steamid);")
			print("Gagban table created for the first time")
		end
	end
end


--Does the heavy lifting of checking mutes of connected players. Will be ran on a timer. Efficiency improvements to be made here! Try to get the queries down.
--Query volume shouldnt be a big problem with the numbers we're working with since we're not committing any data extremely fast, and we have an index.
local function mb_bancheck()
	for k,v in pairs(player.GetAll()) do
		if not v then return end
		--Mute check
		local player_query = sql.QueryRow("SELECT steamid, ban_time, ban_length FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(v:SteamID())..";")
		if player_query then
			local timebanned = player_query["ban_time"]
			local banlength = player_query["ban_length"]
			local timenow = os.time()
			if ((timebanned + banlength) < timenow) and tonumber(banlength) ~= 0 then
				--Prevent command injection by targeting with steamid
				RunConsoleCommand("ulx", "unmuteban", "$"..v:SteamID())
			end
		end
		--Gag check
		local player_query = sql.QueryRow("SELECT steamid, ban_time, ban_length FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(v:SteamID())..";")
		if player_query then
			local timebanned = player_query["ban_time"]
			local banlength = player_query["ban_length"]
			local timenow = os.time()
			if ((timebanned + banlength) < timenow) and tonumber(banlength) ~= 0 then
				RunConsoleCommand("ulx", "ungagban", "$"..v:SteamID())
				v:SetNWBool("mb_gagged", false)
			else
				--Set boolean in the entity object for our gag hook
				v.mb_gagged = true
				v:SetNWBool("mb_gagged", true)
			end
		end
	end
end

--Adds and updates ban records
local function mb_addban(ply, length, reason, admin, type)
	if not ply:IsValid() then return end
	if reason == "" then reason = nil end
	--Set up admin name/steamid
	local admin_username, admin_steamid
	if admin then
		if admin:IsValid() then
			admin_username = admin:Nick()
			admin_steamid = admin:SteamID()
		else
			admin_username = "(Console)"
			admin_steamid = nil
		end
	
	end
	--Get steamid and nickname to store
	local ply_steamid = ply:SteamID()
	local ply_username = ply:Nick()
	local timeNow = os.time()
	--DANGER ZONE: DATABASE UPDATES & INSERTS
	--Mutes
	if type == "mute" then
		local playerexists_query = sql.Query("SELECT * FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		if playerexists_query then
			--Update existing mute record
			sql.Query("UPDATE mb_mutebandata SET username = "..sql.SQLStr(ply_username)..", ban_length = "..length..", ban_time = "..timeNow..", reason = "..sql.SQLStr(reason)..", admin_username = "..sql.SQLStr(admin_username)..", admin_steamid = "..sql.SQLStr(admin_steamid).." WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		else
			--Create new record
			sql.Query("INSERT INTO mb_mutebandata (steamid, username, ban_length, ban_time, reason, admin_username, admin_steamid) VALUES ("..sql.SQLStr(ply_steamid)..", "..sql.SQLStr(ply_username)..", "..length..", "..timeNow..", "..sql.SQLStr(reason)..", "..sql.SQLStr(admin_name)..", "..sql.SQLStr(admin_steamid)..");")
		end

	--Gags
	elseif type == "gag" then
		local playerexists_query = sql.Query("SELECT * FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		if playerexists_query then
			--Update existing gag record
			sql.Query("UPDATE mb_gagbandata SET username = "..sql.SQLStr(ply_username)..", ban_length = "..length..", ban_time = "..timeNow..", reason = "..sql.SQLStr(reason)..", admin_username = "..sql.SQLStr(admin_username)..", admin_steamid = "..sql.SQLStr(admin_steamid).." WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		else
			sql.Query("INSERT INTO mb_gagbandata (steamid, username, ban_length, ban_time, reason, admin_username, admin_steamid) VALUES ("..sql.SQLStr(ply_steamid)..", "..sql.SQLStr(ply_username)..", "..length..", "..timeNow..", "..sql.SQLStr(reason)..", "..sql.SQLStr(admin_username)..", "..sql.SQLStr(admin_steamid)..");")
		end
	end
	mb_bancheck()
end 

--Adds bans by ID
local function mb_banid(steamid, length, reason, admin, type)
	local ply_steamid = steamid
	if reason == "" then reason = nil end
	--Set up admin name/steamid
	--NEEDS FIXING FOR NON-PLAYER CALLING PLY
	local admin_username, admin_steamid
	if admin then
		admin_username = "(Console)"
		admin_steamid = nil
		if admin:IsValid() then
			admin_name = admin:Name()
			admin_steamid = admin:SteamID()
		end
	end
	--Look up steamid to see if we can get their username
	local plybysteamid = player.GetBySteamID(steamid)
	if plybysteamid == false then
		username = nil
	else
		username = plybysteamid:Nick()
	end
	local timeNow = os.time()
	--DANGER ZONE: DATABASE UPDATES & INSERTS
	--Mutes
	if type == "mute" then
		local playerexists_query = sql.Query("SELECT * FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		if playerexists_query then
			--Update existing mute record
			sql.Query("UPDATE mb_mutebandata SET username = "..sql.SQLStr(username)..", ban_length = "..length..", ban_time = "..timeNow..", reason = "..sql.SQLStr(reason)..", admin_username = "..sql.SQLStr(admin_name)..", admin_steamid = "..sql.SQLStr(admin_steamid).." WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		else
			--Create new record
			sql.Query("INSERT INTO mb_mutebandata (steamid, username, ban_length, ban_time, reason, admin_username, admin_steamid) VALUES ("..sql.SQLStr(ply_steamid)..", "..sql.SQLStr(username)..", "..length..", "..timeNow..", "..sql.SQLStr(reason)..", "..sql.SQLStr(admin_name)..", "..sql.SQLStr(admin_steamid)..");")
		end
	--Gags
	elseif type == "gag" then
		local playerexists_query = sql.Query("SELECT * FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		if playerexists_query then
			--Update existing gag record
			sql.Query("UPDATE mb_gagbandata SET username = "..sql.SQLStr(username)..", ban_length = "..length..", ban_time = "..timeNow..", reason = "..sql.SQLStr(reason)..", admin_username = "..sql.SQLStr(admin_name)..", admin_steamid = "..sql.SQLStr(admin_steamid).." WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		else
			--Create new record
			sql.Query("INSERT INTO mb_gagbandata (steamid, username, ban_length, ban_time, reason, admin_username, admin_steamid) VALUES ("..sql.SQLStr(ply_steamid)..", "..sql.SQLStr(username)..", "..length..", "..timeNow..", "..sql.SQLStr(reason)..", "..sql.SQLStr(admin_name)..", "..sql.SQLStr(admin_steamid)..");")
		end
	end
	mb_bancheck()
end

--Returns true if success, false if failure
local function mb_unban(ply, type)
	local ply_steamid = ply:SteamID()
	--Mutes
	--DANGER ZONE: DELETES MUTE/GAG RECORDS
	if type == "mute" then
		local playerexists_query = sql.Query("SELECT steamid FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		if playerexists_query then
			--Remove record
			sql.Query("DELETE FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
			return true
		else return false end
	elseif type == "gag" then
		local playerexists_query = sql.Query("SELECT * FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		if playerexists_query then
			--Remove record
			sql.Query("DELETE FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
			return true
		else return false end
	end
	mb_bancheck()
end

local function mb_unbanid(steamid, type)
	local ply_steamid = steamid
	--Mutes
	--DANGER ZONE: DELETES MUTE/GAG RECORDS
	if type == "mute" then
		local playerexists_query = sql.Query("SELECT * FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		if playerexists_query then
			--Remove record
			sql.Query("DELETE FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
			return true
		else return false end
	elseif type == "gag" then
		local playerexists_query = sql.Query("SELECT * FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		if playerexists_query then
			--Remove record
			sql.Query("DELETE FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
			return true
		else return false end
	end
end


--Check if a player is muted by ID
local function mb_playerIsMuted(steamid)
	local querycheck = sql.Query("SELECT * FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(steamid)..";")
	if querycheck then
		return true
	else return false end
end

--Check if a player is gagged by ID
local function mb_playerIsGagged(steamid)
	local querycheck = sql.Query("SELECT * FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(steamid)..";")
	if querycheck then
		return true
	else return false end
end

--Scrubs the database
--DANGER ZONE: DELETES DATABASE RECORDS
local function mb_scrubbans()
	local timeNow = os.time()
	--Mutes
	local mutesquery = sql.Query("SELECT steamid, ban_time, ban_length FROM mb_mutebandata;")
	if not mutesquery then return true end
	for k,v in pairs(mutesquery) do
		if ((v["ban_time"] + v["ban_length"]) < timeNow) and tonumber(v["ban_length"]) ~= 0 then
			sql.Query("DELETE FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(v["steamid"])..";")
		end
	end
	--Gags
	local gagsquery = sql.Query("SELECT steamid, ban_time, ban_length FROM mb_gagbandata;")
	if not gagsquery then return true end
	for k,v in pairs(gagsquery) do
		if ((v["ban_time"] + v["ban_length"]) < timeNow) and tonumber(v["ban_length"]) ~= 0 then
			sql.Query("DELETE FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(v["steamid"])..";")
		end
	end
end



--The bone zone
--(Where code actually runs)
if SERVER then
	--Run init
	mb_initialize()
	--Gag hook
	--We can't query the db straight from this hook without causing massive lag, so ply.mb_gagged is used instead. Keep it updated! mb_checkbans() should do the trick.
	hook.Add("PlayerCanHearPlayersVoice", "mb_gaghook", function(listener, talker)
		if talker.mb_gagged then return false end
	end)

	--Prevents gag evades
	hook.Add("PlayerAuthed", "mb_gagevadehook", function(ply)
		mb_bancheck()
		if mb_playerIsGagged(ply:SteamID()) then
			ply.mb_gagged = true
		else ply.mb_gagged = false end
	end)

	--Mute hook, no need to check for evades here since we query every time a message is sent
	hook.Add("PlayerSay", "mb_mutehook", function(ply) 
		mb_bancheck()
		if mb_playerIsMuted(ply:SteamID()) then
			ULib.tsay(ply, "You are muted. No-one can see your messages!")
			return "" end
	end)
end

if CLIENT then
	--Basically a rip of permagag notification code
	local lastGagNotifTime = -1
	hook.Add("PlayerStartVoice", "mb_gagnotif", function(ply)
		if ply:GetNWBool("mb_gagged") == true then
			if (lastGagNotifTime + 10) < CurTime() then
				ULib.tsay(ply, "You are gagged. Nobody can hear you!")
				lastGagNotifTime = CurTime()
			end
		end
	end)
end
--Refresh and scrub timers
timer.Create("mb_refreshtimer", 1, 0, mb_bancheck)
--Every 15 minutes or so
timer.Create("mb_ban_scrubber", 1, 0, mb_scrubbans)


--ULX STUFF
--MORE COMMENTS BECAUSE I KEEP LOSING IT WHILE SCROLLING

--Muteban ULX command, based largely on ulx ban
function ulx.muteban( calling_ply, target_ply, minutes, reason)
	local time = "for #s"
	if minutes == 0 then time = "permanently" end
	local str = "#A muted #T "..time
	if reason and reason ~= "" then str = str.. " (#s)" end
	ulx.fancyLogAdmin( calling_ply, str, target_ply, minutes ~= 0 and ULib.secondsToStringTime(minutes * 60) or reason, reason)
	mb_addban(target_ply, minutes*60, reason, calling_ply, "mute")
end
local muteban = ulx.command( "Chat", "ulx muteban", ulx.muteban, "!muteban" )
muteban:defaultAccess( ULib.ACCESS_ADMIN )
muteban:addParam{ type=ULib.cmds.PlayerArg }
muteban:addParam{ type=ULib.cmds.NumArg, default=5, hint="Minutes, 0 for perma", ULib.cmds.optional, ULib.cmds.allowTimeString, min=0 }
muteban:addParam{ type=ULib.cmds.StringArg, hint="", ULib.cmds.optional, ULib.cmds.TakeRestOfLine}
muteban:help( "Mutes a player for some time, or forever.")


--Unmuteban
function ulx.unmuteban(calling_ply, target_ply)
	local result = mb_unban(target_ply, "mute")
	if result == true then
		ulx.fancyLogAdmin( calling_ply, "#A unmuted #T", target_ply )
	else
		ULib.tsayError(calling_ply, "Player is not muted")
	end
end
local unmuteban = ulx.command( "Chat", "ulx unmuteban", ulx.unmuteban, "!unmuteban" )
unmuteban:defaultAccess( ULib.ACCESS_ADMIN )
unmuteban:addParam{ type=ULib.cmds.PlayerArg }
unmuteban:help( "Unmutes a player." )


--Gagban
function ulx.gagban( calling_ply, target_ply, minutes, reason)
	local time = "for #s"
	if minutes == 0 then time = "permanently" end
	local str = "#A gagged #T "..time
	if reason and reason ~= "" then str = str.. " (#s)" end
	ulx.fancyLogAdmin( calling_ply, str, target_ply, minutes ~= 0 and ULib.secondsToStringTime(minutes * 60) or reason, reason)
	mb_addban(target_ply, minutes*60, reason, calling_ply, "gag")
end
local gagban = ulx.command( "Chat", "ulx gagban", ulx.gagban, "!gagban" )
gagban:defaultAccess( ULib.ACCESS_ADMIN )
gagban:addParam{ type=ULib.cmds.PlayerArg }
gagban:addParam{ type=ULib.cmds.NumArg, default=5, hint="Minutes, 0 for perma", ULib.cmds.optional, ULib.cmds.allowTimeString, min=0 }
gagban:addParam{ type=ULib.cmds.StringArg, hint="", ULib.cmds.optional, ULib.cmds.TakeRestOfLine}
gagban:help( "Gag a player for some time, or forever." )


--Ungagban
function ulx.ungagban( calling_ply, target_ply)
	local result = mb_unban(target_ply, "gag")
	if result == true then
		ulx.fancyLogAdmin( calling_ply, "#A ungagged #T", target_ply )
	else
		ULib.tsayError(calling_ply, "Player is not gagged")
	end
end
local ungagban = ulx.command( "Chat", "ulx ungagban", ulx.ungagban, "!ungagban" )
ungagban:defaultAccess( ULib.ACCESS_ADMIN )
ungagban:addParam{ type=ULib.cmds.PlayerArg }
ungagban:help( "Ungags a player." )


--Mutebanid
function ulx.mutebanid( calling_ply, steamid, minutes, reason)
	steamid = string.upper(steamid)
	if not ULib.isValidSteamID(steamid) then
		ULib.tsayError(calling_ply, "Invalid Steamid")
		return
	end
	--Gets nick if possible
	local target_ply = player.GetBySteamID(steamid)
	if target_ply == false then
		nick = nil
	else
		nick = target_ply:Nick()
	end
	
	--Assembles ban reason
	local time = "for #s"
	if minutes == 0 then time = "permanently" end
	local str = "#A muted steamid #s "
	displayid = steamid
	if nick then
		displayid = displayid.." ("..nick..") "
	end
	if reason and reason ~= "" then str = str .. "for #4s" end
	ulx.fancyLogAdmin( calling_ply, str, displayid, minutes ~= 0 and ULib.secondsToStringTime( minutes * 60 ) or reason, reason)
	mb_banid(steamid, minutes*60, reason, calling_ply, "mute")
end
local mutebanid = ulx.command( "Chat", "ulx mutebanid", ulx.mutebanid, "!mutebanid" )
mutebanid:defaultAccess( ULib.ACCESS_ADMIN )
mutebanid:addParam{ type=ULib.cmds.StringArg, hint="steamid" }
mutebanid:addParam{ type=ULib.cmds.NumArg, default=5, hint="Minutes, 0 for perma", ULib.cmds.optional, ULib.cmds.allowTimeString, min=0 }
mutebanid:addParam{ type=ULib.cmds.StringArg, hint="", ULib.cmds.optional, ULib.cmds.TakeRestOfLine}
mutebanid:help( "Mutes a player by ID for some time, or forever.")


--Unmutebanid
function ulx.unmutebanid( calling_ply, steamid)
	steamid = string.upper(steamid)
	if not ULib.isValidSteamID(steamid) then
		ULib.tsayError(calling_ply, "Invalid Steamid")
		return
	end
	--Gets nick if possible
	local target_ply = player.GetBySteamID(steamid)
	if target_ply == false then
		nick = nil
	else
		nick = target_ply:Nick()
	end
	--Assembles ban reason
	local str = "#A unmuted steamid #s "
	local displayid = steamid
	if nick then
		displayid = displayid.." ("..nick..") "
	end
	
	--Does the work
	local result = mb_unbanid(steamid, "mute")
	if result == true then
		ulx.fancyLogAdmin( calling_ply, str, displayid)
	else
		ULib.tsayError(calling_ply, "Player is not muted")
	end
end
local unmutebanid = ulx.command( "Chat", "ulx unmutebanid", ulx.unmutebanid, "!unmutebanid" )
unmutebanid:defaultAccess( ULib.ACCESS_ADMIN )
unmutebanid:addParam{ type=ULib.cmds.StringArg, hint="steamid" }
unmutebanid:help( "Unmutes a player by steamid")


--Gagbanid
function ulx.gagbanid( calling_ply, steamid, minutes, reason)
	steamid = string.upper(steamid)
	if not ULib.isValidSteamID(steamid) then
		ULib.tsayError(calling_ply, "Invalid Steamid")
		return
	end
	--Gets nick if possible
	local target_ply = player.GetBySteamID(steamid)
	if target_ply == false then
		local nick = nil
	else
		local nick = target_ply:Nick()
	end
	
	--Assembles ban reason
	local time = "for #s"
	if minutes == 0 then time = "permanently" end
	local str = "#A gagged steamid #s "
	displayid = steamid
	if nick then
		displayid = displayid.."("..nick..") "
	end
	if reason and reason ~= "" then str = str .. " (#4s)" end
	ulx.fancyLogAdmin( calling_ply, str, displayid, minutes ~= 0 and ULib.secondsToStringTime( minutes * 60 ) or reason, reason)
	mb_banid(steamid, minutes*60, reason, calling_ply, "gag")
end
local gagbanid = ulx.command( "Chat", "ulx gagbanid", ulx.gagbanid, "!gagbanid" )
gagbanid:defaultAccess( ULib.ACCESS_ADMIN )
gagbanid:addParam{ type=ULib.cmds.StringArg, hint="steamid" }
gagbanid:addParam{ type=ULib.cmds.NumArg, default=5, hint="Minutes, 0 for perma", ULib.cmds.optional, ULib.cmds.allowTimeString, min=0 }
gagbanid:addParam{ type=ULib.cmds.StringArg, hint="", ULib.cmds.optional, ULib.cmds.TakeRestOfLine}
gagbanid:help( "Gags a player by ID for some time, or forever.")


--Unmutebanid
function ulx.ungagbanid( calling_ply, steamid)
	steamid = string.upper(steamid)
	if not ULib.isValidSteamID(steamid) then
		ULib.tsayError(calling_ply, "Invalid Steamid")
		return
	end
	--Gets nick if possible
	local target_ply = player.GetBySteamID(steamid)
	if target_ply == false then
		nick = nil
	else
		nick = target_ply:Nick()
	end
	--Assembles ban reason
	local str = "#A unmuted steamid #s "
	local displayid = steamid
	if nick then
		displayid = displayid.." ("..nick..") "
	end
	
	--Does the work
	local result = mb_unbanid(steamid, "gag")
	if result == true then
		ulx.fancyLogAdmin( calling_ply, str, displayid)
	else
		ULib.tsayError(calling_ply, "Player is not gagged")
	end
end
local ungagbanid = ulx.command( "Chat", "ulx ungagbanid", ulx.ungagbanid, "!ungagbanid" )
ungagbanid:defaultAccess( ULib.ACCESS_ADMIN )
ungagbanid:addParam{ type=ULib.cmds.StringArg, hint="steamid" }
ungagbanid:help( "Unmutes a player by steamid")