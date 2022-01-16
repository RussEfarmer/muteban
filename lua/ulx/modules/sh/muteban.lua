

local function mb_initialize()
	if sql.TableExists("mb_mutebandata") && sql.TableExists("mb_gagbandata") then
		print("Mute/gagban tables are ready!")
	else
		if not sql.TableExists("mb_mutebandata") then
			sql.Query("CREATE TABLE IF NOT EXISTS mb_mutebandata (steamid VARCHAR(255) PRIMARY KEY, username VARCHAR(255), ban_length INT, ban_time INT, reason VARCHAR(255), admin_username VARCHAR(255), admin_steamid VARCHAR(255));")
			print("Muteban table created for the first time")
		end
		if not sql.TableExists("mb_gagbandata") then
			sql.Query("CREATE TABLE IF NOT EXISTS mb_gagbandata (steamid VARCHAR(255) PRIMARY KEY, username VARCHAR(255), ban_length INT, ban_time INT, reason VARCHAR(255), admin_username VARCHAR(255), admin_steamid VARCHAR(255));")
			print("Gagban table created for the first time")
		end
	end
end

--oh god
local function mb_addban(steamid, length, reason, admin, type)
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

	local timeNow = os.time()
	if type == "gag" then
		--Update existing mute record
		local playerexists_query = sql.Query("SELECT * FROM mb_mutebandata WHERE steamid = "..sql.SQLStr(steamid)..";")
		if playerexists_query then
			sql.Query("UPDATE mb_mutebandata SET ban_length = "..sql.SQLStr(length)..", reason = "..sql.SQLStr(reason)..", admin_username = "..sql.SQLStr(admin_name)..", admin_steamid = "..sql.SQLStr(admin_steamid).." WHERE steamid = "..sql.SQLStr(steamid)
		end
	end
end
mb_initialize()