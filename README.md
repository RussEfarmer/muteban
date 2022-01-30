# Muteban for ULX Admin Mod
This addon, an extension to ULX admin mod, heavily expands on the capabilities of the mute and gag commands. Its main features include fixing mute evasion, setting a timer on mutes, permamuting, muting disconnected players, and reporting what admin muted which player.
## Features
- Fixes mute & gag evasion (Mutes don't disappear on disconnect)
- Timer feature to mute & gag for a certain amount of time (5 minutes, 2 hours, 2 weeks, 2 years, or even forever!)
- Can add or remove mutes & gags on disconnected players by steamid
- Can add reasons to mutes & gags
- Command to list current mutes or gags
- Command to lookup information about a mute or gag by steamid
- Mute override protection

## Mute Override Protection
In ULX ban, if a moderator has access to the ban command, they can take any steamid thats banned and set it to any value. However, sometimes we don't want moderators to be able to effectively unban a permanently banned player by setting their ban to 1 minute. This addon does not have the same problem; in the top of the file, you can set how much time each user group should be able to mute or gag for. If you set the trusted group to be able to only mute for 2 hours, not only will they be blocked from setting a mute greater than two hours, they cannot override a mute made for any length over 2 hours. This way, if an admin permanently mutes someone, you can't have a test moderator or something remove it.

## Command Reference
ulx muteban <ply> <length> <reason> - Mutes a player for the length specified, 0 for permamute, default length is 5 minutes
ulx gagban <ply> <length> <reason> - Gags a player for the length specified, 0 for permagag, default length is 5 minutes
ulx unmuteban <ply> - Unmutes a player
ulx ungagban <ply> - Ungags a player
ulx mutebanid <steamid> <length> <reason> - Mutes a steamid for the length specified, 0 for permamute, default length is 5 minutes
ulx gagbanid <steamid> <length> <reason> - Gags a steamid for the length specified, 0 for permagag, default length is 5 minutes
ulx unmutebanid <steamid> - Unmutes a steamid
ulx ungagbanid <steamid> - Ungags a steamid
ulx mutebannedplayers - Lists players muted that are connected, and how long they are muted for
ulx gagbannedplayers - Lists players gagged that are connected, and how long they are gagged for
ulx mutebaninfo <steamid> - Queries information about a mute. Lists username at time of mute, unmute date, time left on mute, mute reason, the admin and the admin steamid.
ulx gagbaninfo <steamid> - Queries information about a gag. Lists username at time of gag, ungag date, time left on gag, gag reason, the admin and the admin steamid.
