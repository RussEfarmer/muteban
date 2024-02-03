--Addon written on 1/30/2022 by RussEfarmer
--CONFIG
-------------------------------------------------
--Configure rank ban time limits. This sets how long a rank can ban for just like in ULX, but adds additional protection that prevents long bans from being overridden by less privaged ranks.
--The syntax is RANK_TIME_LIMITS["rank"] = time in minutes
--Ranks not in this list can override all bans and mute for any duration
--Don't define anything to turn off this feature
local RANK_TIME_LIMITS = {}
RANK_TIME_LIMITS["donor"] = 15
RANK_TIME_LIMITS["superdonor"] = 15
RANK_TIME_LIMITS["trusted"] = 120
RANK_TIME_LIMITS["dtmod"] = 720 -- 12 hours
RANK_TIME_LIMITS["moderator"] = 20160 -- 2 weeks

--------------------------------------------------
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
			sql.Query("INSERT INTO mb_mutebandata (steamid, username, ban_length, ban_time, reason, admin_username, admin_steamid) VALUES ("..sql.SQLStr(ply_steamid)..", "..sql.SQLStr(ply_username)..", "..length..", "..timeNow..", "..sql.SQLStr(reason)..", "..sql.SQLStr(admin_username)..", "..sql.SQLStr(admin_steamid)..");")
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
			admin_username = admin:Name()
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
			sql.Query("UPDATE mb_mutebandata SET username = "..sql.SQLStr(username)..", ban_length = "..length..", ban_time = "..timeNow..", reason = "..sql.SQLStr(reason)..", admin_username = "..sql.SQLStr(admin_username)..", admin_steamid = "..sql.SQLStr(admin_steamid).." WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		else
			--Create new record
			sql.Query("INSERT INTO mb_mutebandata (steamid, username, ban_length, ban_time, reason, admin_username, admin_steamid) VALUES ("..sql.SQLStr(ply_steamid)..", "..sql.SQLStr(username)..", "..length..", "..timeNow..", "..sql.SQLStr(reason)..", "..sql.SQLStr(admin_username)..", "..sql.SQLStr(admin_steamid)..");")
		end
	--Gags
	elseif type == "gag" then
		local playerexists_query = sql.Query("SELECT * FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		if playerexists_query then
			--Update existing gag record
			sql.Query("UPDATE mb_gagbandata SET username = "..sql.SQLStr(username)..", ban_length = "..length..", ban_time = "..timeNow..", reason = "..sql.SQLStr(reason)..", admin_username = "..sql.SQLStr(admin_username)..", admin_steamid = "..sql.SQLStr(admin_steamid).." WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		else
			--Create new record
			sql.Query("INSERT INTO mb_gagbandata (steamid, username, ban_length, ban_time, reason, admin_username, admin_steamid) VALUES ("..sql.SQLStr(ply_steamid)..", "..sql.SQLStr(username)..", "..length..", "..timeNow..", "..sql.SQLStr(reason)..", "..sql.SQLStr(admin_username)..", "..sql.SQLStr(admin_steamid)..");")
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
			ply:SetNWBool("mb_gagged", false)
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
			local target_ply = player.GetBySteamID(steamid)
			if target_ply then
				target_ply:SetNWBool("mb_gagged", false)
			end
			--Remove record
			sql.Query("DELETE FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
			return true
		else return false end
	end
end

--Check if a player is muted by ID, returns true if muted
local function mb_playerIsMuted(steamid)
	local querycheck = sql.Query("SELECT steamid FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(steamid)..";")
	if querycheck then
		return true
	else return false end
end

--Check if a player is gagged by ID, returns true if gagged
local function mb_playerIsGagged(steamid)
	local querycheck = sql.Query("SELECT steamid FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(steamid)..";")
	if querycheck then
		return true
	else return false end
end

--Get data relating to a steamid's ban, returns table with keys equal to field names
--Mutes
local function mb_getMuteInfo(steamid)
	return sql.QueryRow("SELECT * FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(steamid)..";")
end

--Gags
local function mb_getGagInfo(steamid)
	return sql.QueryRow("SELECT * FROM mb_gagbandata WHERE steamid = "..sql.SQLStr(steamid)..";")
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

--Used for override security in the ULX commands
--Returns false on error, then the error message
local function mb_bansecurity(calling_ply, target_ply, minutes, type)
	if type == "gag" then
		local caller_ug = "Console"
		if calling_ply:IsValid() then
			caller_ug = calling_ply:GetUserGroup()
		end
		if RANK_TIME_LIMITS[caller_ug] then
			local authorized_minutes = RANK_TIME_LIMITS[caller_ug]
			--Permagag check
			if minutes == 0 then
				return false, "You cannot permanently gag"
			end
			--Gagging over time check
			if minutes > authorized_minutes then
				return false, "You cannot gag for more than "..ULib.secondsToStringTime(authorized_minutes*60)
			end
			if mb_playerIsGagged(target_ply:SteamID()) == true then
				local gagdata = mb_getGagInfo(target_ply:SteamID())
				--Normal gag override check
				if tonumber(gagdata["ban_length"]) > authorized_minutes*60 then
					return false, "Player is gagged for "..ULib.secondsToStringTime(gagdata["ban_length"])..", you cannot override a gag of this length"
				end
				--Permagag override check
				if tonumber(gagdata["ban_length"]) == 0 then
					return false, "You cannot override a permanent gag"
				end
			end
		end
	elseif type == "mute" then
		local caller_ug = "Console"
		if calling_ply:IsValid() then
			caller_ug = calling_ply:GetUserGroup()
		end
		if RANK_TIME_LIMITS[caller_ug] then
			local authorized_minutes = RANK_TIME_LIMITS[caller_ug]
			--Permamute check
			if minutes == 0 then
				return false, "You cannot permanently mute"
			end
			--Muting over time check
			if minutes > authorized_minutes then
				return false, "You cannot mute for more than "..ULib.secondsToStringTime(authorized_minutes*60)
			end
			if mb_playerIsMuted(target_ply:SteamID()) == true then
				local mutedata = mb_getMuteInfo(target_ply:SteamID())
				--Normal mute override check
				if tonumber(mutedata["ban_length"]) > authorized_minutes*60 then
					return false, "Player is muted for "..ULib.secondsToStringTime(mutedata["ban_length"])..", you cannot override a mute of this length"
				end
				--Permamute override check
				if tonumber(mutedata["ban_length"]) == 0 then
					return false, "You cannot override a permanent mute"
				end
			end
		end
	end
end

local function mb_unbansecurity(calling_ply, target_ply, type)
	if type == "gag" then
		local caller_ug = "Console"
		if calling_ply:IsValid() then
			caller_ug = calling_ply:GetUserGroup()
		end
		if RANK_TIME_LIMITS[caller_ug] then
			local authorized_minutes = RANK_TIME_LIMITS[caller_ug]
			if mb_playerIsGagged(target_ply:SteamID()) == true then
				local gagdata = mb_getGagInfo(target_ply:SteamID())
				--Normal gag override check
				if tonumber(gagdata["ban_length"]) > authorized_minutes*60 then
					return false, "Player is gagged for "..ULib.secondsToStringTime(gagdata["ban_length"])..", you cannot remove a gag of this length"
				end
				--Permagag override check
				if tonumber(gagdata["ban_length"]) == 0 then
					return false, "You cannot remove a permanent gag"
				end
			end
		end
	elseif type == "mute" then
		local caller_ug = "Console"
		if calling_ply:IsValid() then
			caller_ug = calling_ply:GetUserGroup()
		end
		if RANK_TIME_LIMITS[caller_ug] then
			local authorized_minutes = RANK_TIME_LIMITS[caller_ug]
			if mb_playerIsMuted(target_ply:SteamID()) == true then
				local mutedata = mb_getMuteInfo(target_ply:SteamID())
				--Normal mute override check
				if tonumber(mutedata["ban_length"]) > authorized_minutes*60 then
					return false, "Player is muted for "..ULib.secondsToStringTime(mutedata["ban_length"])..", you cannot remove a mute of this length"
				end
				--Permamute override check
				if tonumber(mutedata["ban_length"]) == 0 then
					return false, "You cannot remove a permanent mute"
				end
			end
		end
	end
end

local function mb_banidsecurity(calling_ply, steamid, minutes, type)
	if type == "gag" then
		local caller_ug = "Console"
		if calling_ply:IsValid() then
			caller_ug = calling_ply:GetUserGroup()
		end
		if RANK_TIME_LIMITS[caller_ug] then
			local authorized_minutes = RANK_TIME_LIMITS[caller_ug]
			--Permagag check
			if minutes == 0 then
				return false, "You cannot permanently gag"
			end
			--Gagging over time check
			if minutes > authorized_minutes then
				return false, "You cannot gag for more than "..ULib.secondsToStringTime(authorized_minutes*60)
			end
			if mb_playerIsGagged(steamid) == true then
				local gagdata = mb_getGagInfo(steamid)
				--Normal gag override check
				if tonumber(gagdata["ban_length"]) > authorized_minutes*60 then
					return false, "Player is gagged for "..ULib.secondsToStringTime(gagdata["ban_length"])..", you cannot override a gag of this length"
				end
				--Permagag override check
				if tonumber(gagdata["ban_length"]) == 0 then
					return false, "You cannot override a permanent gag"
				end
			end
		end
	elseif type == "mute" then
		local caller_ug = "Console"
		if calling_ply:IsValid() then
			caller_ug = calling_ply:GetUserGroup()
		end
		if RANK_TIME_LIMITS[caller_ug] then
			local authorized_minutes = RANK_TIME_LIMITS[caller_ug]
			--Permamute check
			if minutes == 0 then
				return false, "You cannot permanently mute"
			end
			--Muting over time check
			if minutes > authorized_minutes then
				return false, "You cannot mute for more than "..ULib.secondsToStringTime(authorized_minutes*60)
			end
			if mb_playerIsMuted(steamid) == true then
				local mutedata = mb_getMuteInfo(steamid)
				--Normal mute override check
				if tonumber(mutedata["ban_length"]) > authorized_minutes*60 then
					return false, "Player is muted for "..ULib.secondsToStringTime(mutedata["ban_length"])..", you cannot override a mute of this length"
				end
				--Permamute override check
				if tonumber(mutedata["ban_length"]) == 0 then
					return false, "You cannot override a permanent mute"
				end
			end
		end
	end
end

local function mb_unbanidsecurity(calling_ply, steamid, type)
	if type == "gag" then
		local caller_ug = "Console"
		if calling_ply:IsValid() then
			caller_ug = calling_ply:GetUserGroup()
		end
		if RANK_TIME_LIMITS[caller_ug] then
			local authorized_minutes = RANK_TIME_LIMITS[caller_ug]
			if mb_playerIsGagged(steamid) == true then
				
				local gagdata = mb_getGagInfo(steamid)
				--Normal gag override check
				if tonumber(gagdata["ban_length"]) > authorized_minutes*60 then
					return false, "Player is gagged for "..ULib.secondsToStringTime(gagdata["ban_length"])..", you cannot remove a gag of this length"
				end
				--Permagag override check
				if tonumber(gagdata["ban_length"]) == 0 then
					return false, "You cannot remove a permanent gag"
				end
			end
		end
	elseif type == "mute" then
		local caller_ug = "Console"
		if calling_ply:IsValid() then
			caller_ug = calling_ply:GetUserGroup()
		end
		if RANK_TIME_LIMITS[caller_ug] then
			local authorized_minutes = RANK_TIME_LIMITS[caller_ug]
			if mb_playerIsMuted(steamid) == true then
				local mutedata = mb_getMuteInfo(steamid)
				--Normal mute override check
				if tonumber(mutedata["ban_length"]) > authorized_minutes*60 then
					return false, "Player is muted for "..ULib.secondsToStringTime(mutedata["ban_length"])..", you cannot remove a mute of this length"
				end
				--Permamute override check
				if tonumber(mutedata["ban_length"]) == 0 then
					return false, "You cannot remove a permanent mute"
				end
			end
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
--Set timer smaller for debugging
timer.Create("mb_ban_scrubber", 600, 0, mb_scrubbans)


--ULX STUFF
--MORE COMMENTS BECAUSE I KEEP LOSING IT WHILE SCROLLING

--Muteban ULX command, based largely on ulx ban
function ulx.muteban( calling_ply, target_ply, minutes, reason)
	local secsuccess, secreason = mb_bansecurity(calling_ply, target_ply, minutes, "mute")
	if secsuccess == false then
		ULib.tsayError(calling_ply, secreason)
		return
	end
	--Assembles ban reason
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
	--Security
	local secsuccess, secreason = mb_unbansecurity(calling_ply, target_ply, "mute")
	if secsuccess == false then
		ULib.tsayError(calling_ply, secreason)
		return
	end
	--Unban
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
	--Security
	local secsuccess, secreason = mb_bansecurity(calling_ply, target_ply, minutes, "gag")
	if secsuccess == false then
		ULib.tsayError(calling_ply, secreason)
		return
	end
	--Assembles ban reason
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
	--Security
	local secsuccess, secreason = mb_unbansecurity(calling_ply, target_ply, "gag")
	if secsuccess == false then
		ULib.tsayError(calling_ply, secreason)
		return
	end
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
	local secsuccess, secreason = mb_banidsecurity(calling_ply, steamid, minutes, "mute")
	if secsuccess == false then
		ULib.tsayError(calling_ply, secreason)
		return
	end
	--Gets nick if possible
	local target_ply = player.GetBySteamID(steamid)
	if target_ply == false then
		nick = nil
	else
		nick = target_ply:Nick()
	end
	local time = "for #s"
	if minutes == 0 then time = "permanently" end
	local str = "#A muted steamid #s "
	displayid = steamid
	if nick then
		displayid = displayid .. " (" .. nick .. ")"
	end
	str = str .. time
	if reason and reason ~= "" then str = str .. " (#s)" end
	ulx.fancyLogAdmin( calling_ply, str, displayid, minutes ~= 0 and ULib.secondsToStringTime( minutes * 60 ) or reason, reason )
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
	local secsuccess, secreason = mb_unbanidsecurity(calling_ply, steamid, "mute")
	if secsuccess == false then
		ULib.tsayError(calling_ply, secreason)
		return
	end
	--Gets nick if possible
	local target_ply = player.GetBySteamID(steamid)
	if target_ply == false then
		nick = nil
	else
		nick = target_ply:Nick()
	end
	local result = mb_unbanid(steamid, "mute")
	if result == true then
		if nick then
			ulx.fancyLogAdmin( calling_ply, "#A unmuted steamid #s", steamid .. " (" .. nick .. ")" )
		else
			ulx.fancyLogAdmin( calling_ply, "#A unmuted steamid #s", steamid )
		end
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
	--Security
	local secsuccess, secreason = mb_banidsecurity(calling_ply, target_ply, minutes, "gag")
	if secsuccess == false then
		ULib.tsayError(calling_ply, secreason)
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
		displayid = displayid .. " (" .. nick .. ")"
	end
	str = str .. time
	if reason and reason ~= "" then str = str .. " (#s)" end
	ulx.fancyLogAdmin( calling_ply, str, displayid, minutes ~= 0 and ULib.secondsToStringTime( minutes * 60 ) or reason, reason )
	mb_banid(steamid, minutes*60, reason, calling_ply, "gag")
end
local gagbanid = ulx.command( "Chat", "ulx gagbanid", ulx.gagbanid, "!gagbanid" )
gagbanid:defaultAccess( ULib.ACCESS_ADMIN )
gagbanid:addParam{ type=ULib.cmds.StringArg, hint="steamid" }
gagbanid:addParam{ type=ULib.cmds.NumArg, default=5, hint="Minutes, 0 for perma", ULib.cmds.optional, ULib.cmds.allowTimeString, min=0 }
gagbanid:addParam{ type=ULib.cmds.StringArg, hint="", ULib.cmds.optional, ULib.cmds.TakeRestOfLine}
gagbanid:help( "Gags a player by ID for some time, or forever.")


--Ungagbanid
function ulx.ungagbanid( calling_ply, steamid)
	steamid = string.upper(steamid)
	if not ULib.isValidSteamID(steamid) then
		ULib.tsayError(calling_ply, "Invalid Steamid")
		return
	end
	--Security
	local secsuccess, secreason = mb_unbanidsecurity(calling_ply, steamid, "gag")
	if secsuccess == false then
		ULib.tsayError(calling_ply, secreason)
		return
	end
	--Gets nick if possible
	local target_ply = player.GetBySteamID(steamid)
	if target_ply == false then
		nick = nil
	else
		nick = target_ply:Nick()
	end
	--Does the work
	local result = mb_unbanid(steamid, "gag")
	if result == true then
		if nick then
			ulx.fancyLogAdmin( calling_ply, "#A ungagged steamid #s", steamid .. " (" .. nick .. ")" )
		else
			ulx.fancyLogAdmin( calling_ply, "#A ungagged steamid #s", steamid )
		end
	else
		ULib.tsayError(calling_ply, "Player is not gagged")
	end
end
local ungagbanid = ulx.command( "Chat", "ulx ungagbanid", ulx.ungagbanid, "!ungagbanid" )
ungagbanid:defaultAccess( ULib.ACCESS_ADMIN )
ungagbanid:addParam{ type=ULib.cmds.StringArg, hint="steamid" }
ungagbanid:help( "Unmutes a player by steamid")

--Check muted players currently connected
function ulx.mutebannedplayers(calling_ply)
	timeNow = os.time()
	for k,v in pairs(player.GetHumans()) do
		if mb_playerIsMuted(v:SteamID()) then
			local mutedata = mb_getMuteInfo(v:SteamID())
			local timeleft = ULib.secondsToStringTime((mutedata["ban_time"] + mutedata["ban_length"]) - timeNow)
			if tonumber(mutedata["ban_length"]) == 0 then
				ulx.tsay(calling_ply, mutedata["username"].." ("..mutedata["steamid"]..") is muted by "..mutedata["admin_username"].." ("..mutedata["admin_steamid"]..") permanently because of "..mutedata["reason"])
			else
				ulx.tsay(calling_ply, mutedata["username"].." ("..mutedata["steamid"]..") is muted by "..mutedata["admin_username"].." ("..mutedata["admin_steamid"]..") for "..timeleft.." because of "..mutedata["reason"])
			end
		end
	end
end
local mutebannedplayers = ulx.command( "Chat", "ulx mutebannedplayers", ulx.mutebannedplayers, "!mutebannedplayers", true )
mutebannedplayers:defaultAccess( ULib.ACCESS_ADMIN )
mutebannedplayers:help("Lists players connected that are muted")

--Check gagged players currently connected
function ulx.gagbannedplayers(calling_ply)
	timeNow = os.time()
	for k,v in pairs(player.GetHumans()) do
		if mb_playerIsGagged(v:SteamID()) then
			local gagdata = mb_getGagInfo(v:SteamID())
			local timeleft = ULib.secondsToStringTime((gagdata["ban_time"] + gagdata["ban_length"]) - timeNow)
			if tonumber(gagdata["ban_length"]) == 0 then
				ulx.tsay(calling_ply, gagdata["username"].." ("..gagdata["steamid"]..") is gagged by "..gagdata["admin_username"].." ("..gagdata["admin_steamid"]..") permanently because of "..gagdata["reason"])
			else
				ulx.tsay(calling_ply, gagdata["username"].." ("..gagdata["steamid"]..") is gagged by "..gagdata["admin_username"].." ("..gagdata["admin_steamid"]..") for "..timeleft.." because of "..gagdata["reason"])
			end
		end
	end
end
local gagbannedplayers = ulx.command( "Chat", "ulx gagbannedplayers", ulx.gagbannedplayers, "!gagbannedplayers", true )
gagbannedplayers:defaultAccess( ULib.ACCESS_ADMIN )
gagbannedplayers:help("Lists players connected that are gagged")

--Check a steamid's mute info
function ulx.gagbaninfo(calling_ply, steamid)
	steamid = string.upper(steamid)
	if not ULib.isValidSteamID(steamid) then
		ULib.tsayError(calling_ply, "Invalid Steamid")
		return
	end
	timeNow = os.time()
	if mb_playerIsGagged(steamid) then
		local gagdata = mb_getGagInfo(steamid)
		ulx.tsay(calling_ply, "User: "..gagdata["username"].." ("..gagdata["steamid"]..")")
		if tonumber(gagdata["ban_length"]) == 0 then
			ulx.tsay(calling_ply, "Ungag date: Never")
		else
			ulx.tsay(calling_ply, "Time left: "..ULib.secondsToStringTime((gagdata["ban_time"] + gagdata["ban_length"]) - timeNow))
			ulx.tsay(calling_ply, "Ungag date: "..os.date('%d-%b-%Y', (gagdata["ban_time"] + gagdata["ban_length"])))
		end
		ulx.tsay(calling_ply, "Reason: "..gagdata["reason"])
		ulx.tsay(calling_ply, "Date gagged: "..os.date('%d-%b-%Y', gagdata["ban_time"]))
		ulx.tsay(calling_ply, "Admin: "..gagdata["admin_username"].." ("..gagdata["admin_steamid"]..")")
	else
		ULib.tsayError(calling_ply, "Player is not gagged")
	end
end
local gagbaninfo = ulx.command( "Chat", "ulx gagbaninfo", ulx.gagbaninfo, "!gagbaninfo", true )
gagbaninfo:addParam{ type=ULib.cmds.StringArg, hint="steamid" }
gagbaninfo:defaultAccess( ULib.ACCESS_ADMIN )
gagbaninfo:help("Shows information about a gag")

function ulx.mutebaninfo(calling_ply, steamid)
	steamid = string.upper(steamid)
	if not ULib.isValidSteamID(steamid) then
		ULib.tsayError(calling_ply, "Invalid Steamid")
		return
	end
	timeNow = os.time()
	if mb_playerIsMuted(steamid) then
		local mutedata = mb_getMuteInfo(steamid)
		ulx.tsay(calling_ply, "User: "..mutedata["username"].." ("..mutedata["steamid"]..")")
		if tonumber(mutedata["ban_length"]) == 0 then
			ulx.tsay(calling_ply, "Unmute date: Never")
		else
			ulx.tsay(calling_ply, "Time left: "..ULib.secondsToStringTime((mutedata["ban_time"] + mutedata["ban_length"]) - timeNow))
			ulx.tsay(calling_ply, "Unmute date: "..os.date('%d-%b-%Y', (mutedata["ban_time"] + mutedata["ban_length"])))
		end
		ulx.tsay(calling_ply, "Reason: "..mutedata["reason"])
		ulx.tsay(calling_ply, "Date muted: "..os.date('%d-%b-%Y', mutedata["ban_time"]))
		ulx.tsay(calling_ply, "Admin: "..mutedata["admin_username"].." ("..mutedata["admin_steamid"]..")")
	else
		ULib.tsayError(calling_ply, "Player is not muted")
	end
end
local mutebaninfo = ulx.command( "Chat", "ulx mutebaninfo", ulx.mutebaninfo, "!mutebaninfo", true )
mutebaninfo:addParam{ type=ULib.cmds.StringArg, hint="steamid" }
mutebaninfo:defaultAccess( ULib.ACCESS_ADMIN )
mutebaninfo:help("Shows information about a mute")