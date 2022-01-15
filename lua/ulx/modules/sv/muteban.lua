
--Table setup
local function mb_createtables()
	if sql.TableExists("muteban_data") && sql.TableExists("gagban_data") then
		Msg("Mute/gagban tables are present")
	else
		if not sql.TableExists("mb_mutebandata") then
			sql.Query("CREATE TABLE IF NOT EXISTS muteban_data (STEAMID VARCHAR(255), LENGTH INT, REASON VARCHAR(255), ADMIN VARCHAR(255));")
		end
		if not sql.TableExists("mb_gagbandata") then
			sql.Query("CREATE TABLE IF NOT EXISTS gagban_data (STEAMID VARCHAR(255), LENGTH INT, REASON VARCHAR(255), ADMIN VARCHAR(255));")
		end
	end
end

local function 