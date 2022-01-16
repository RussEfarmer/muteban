
--Database setup
local function mb_initialize()
	if sql.TableExists("mb_mutebandata") && sql.TableExists("mb_gagbandata") then
		print("Mute/gagban tables are ready")
	else
		--Creates tables mb_mutebandata & mb_gagbandata, creates indexes mb_mutebandata_index and mb_gagbandata_index
		if not sql.TableExists("mb_mutebandata") then
			sql.Query("CREATE TABLE IF NOT EXISTS mb_mutebandata (steamid VARCHAR(255) PRIMARY KEY, username VARCHAR(255), ban_length INT, ban_time INT, reason VARCHAR(255), admin_username VARCHAR(255), admin_steamid VARCHAR(255));")
			sql.Query("CREATE INDEX IF NOT EXISTS mb_mutebandata_index ON mb_mutebandata (steamid)")
			print("Muteban table created for the first time")
		end
		if not sql.TableExists("mb_gagbandata") then
			sql.Query("CREATE TABLE IF NOT EXISTS mb_gagbandata (steamid VARCHAR(255) PRIMARY KEY, username VARCHAR(255), ban_length INT, ban_time INT, reason VARCHAR(255), admin_username VARCHAR(255), admin_steamid VARCHAR(255));")
			sql.Query("CREATE INDEX IF NOT EXISTS mb_gagbandata_index ON mb_gagbandata (steamid)")
			print("Gagban table created for the first time")
		end
	end
end
mb_initialize()

--Sets up data from our ULX commands and updates the database
local function mb_addban(ply, length, reason, admin, type)
	if reason == "" then reason = nil end

	--Set up admin name/steamid
	local admin_username, admin_steamid
	if admin then
		admin_username = "(Console)"
		admin_steamid = nil
		if admin:IsValid() then
			admin_name = admin:Name()
			admin_steamid = admin:SteamID()
		end
	end
	local ply_steamid = ply:SteamID()
	local ply_username = ply:Nick()

	local timeNow = os.time()
	if type == "mute" then
		print(admin_name)
		print(admin_steamid)
		--Update existing mute record
		local playerexists_query = sql.Query("SELECT * FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(ply_steamid)..";")
		if playerexists_query then
			sql.Query("UPDATE mb_mutebandata SET username = "..sql.SQLStr(ply_username)..", ban_length = "..length..", ban_time = "..timeNow..", reason = "..sql.SQLStr(reason)..", admin_username = "..sql.SQLStr(admin_name)..", admin_steamid = "..sql.SQLStr(admin_steamid).." WHERE steamid = "..sql.SQLStr(ply_steamid))
		else
			sql.Query("INSERT INTO mb_mutebandata (steamid, username, ban_length, ban_time, reason, admin_username, admin_steamid) VALUES ("..sql.SQLStr(ply_steamid)..", "..sql.SQLStr(ply_username)..", "..length..", "..timeNow..", "..sql.SQLStr(reason)..", "..sql.SQLStr(admin_name)..", "..sql.SQLStr(admin_steamid)..")")
		end
	end
end 


--Muteban ULX command, based largely on ulx ban
function ulx.muteban( calling_ply, target_ply, minutes, reason)
	minutes = math.ceil(minutes)
	local time = "for #s"
	if minutes == 0 then time = "permanently" end
	local str = "#A muted #T "..time
	if reason and reason ~= "" then str = str.. " (#s)" end
	ulx.fancyLogAdmin( calling_ply, str, target_ply, minutes ~= 0 and ULib.secondsToStringTime(minutes * 60) or reason, reason)

	mb_addban(target_ply, minutes, reason, calling_ply, "mute")
end
local muteban = ulx.command( "Chat", "ulx muteban", ulx.muteban, "!muteban" )
muteban:defaultAccess( ULib.ACCESS_ADMIN )
muteban:addParam{ type=ULib.cmds.PlayerArg }
muteban:addParam{ type=ULib.cmds.NumArg, default=5, hint="Minutes, 0 for perma", ULib.cmds.optional, ULib.cmds.allowTimeString, min=0 }
muteban:addParam{ type=ULib.cmds.StringArg, hint="", ULib.cmds.optional, ULib.cmds.TakeRestOfLine}
muteban:help( "Mutes a player for some time, or forever." )

--Gagban command
function ulx.gagban( calling_ply, target_ply, minutes, reason)
	minutes = math.ceil(minutes)
	local time = "for #s"
	if minutes == 0 then time = "permanently" end
	local str = "#A gagged #T "..time
	if reason and reason ~= "" then str = str.. " (#s)" end
	ulx.fancyLogAdmin( calling_ply, str, target_ply, minutes ~= 0 and ULib.secondsToStringTime(minutes * 60) or reason, reason)

	mb_addban(target_ply, minutes, reason, calling_ply, "gag")
end
local gagban = ulx.command( "Chat", "ulx gagban", ulx.gagban, "!gagban" )
gagban:defaultAccess( ULib.ACCESS_ADMIN )
gagban:addParam{ type=ULib.cmds.PlayerArg }
gagban:addParam{ type=ULib.cmds.NumArg, default=5, hint="Minutes, 0 for perma", ULib.cmds.optional, ULib.cmds.allowTimeString, min=0 }
gagban:addParam{ type=ULib.cmds.StringArg, hint="", ULib.cmds.optional, ULib.cmds.TakeRestOfLine}
gagban:help( "Gag a player for some time, or forever." )