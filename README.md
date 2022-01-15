# muteban
This addon, an extension to ULX, adds the muteban and gagban commands. This allows admin to mute and gag players exactly like you would to ban a player from the server.
## Problems with ULX mute/gag
ULX Admin Mod's features are quite amazing, but the mute and gag commands, two of the most used moderation tools in the addon, have two big problems:
1. Mutes don't stick! When a player disconnects or the map changes, previously muted or gagged players can talk again.
2. You can't put a timer on mutes. Staff forget all the time to unmute players, which is really annoying. Why can't I just say I want to mute them for 5 minutes?

## Problems with my old fix
To solve these two problems, I made an addon called Persistent Gags and Mutes (I just call it timed mutes and gags), but that included its own problems:
1. Mute times had an accuracy of +-1 minute. This is because of how the "timed" part of timed mutes and gags worked, which is just a timer that whacks off a minute from the players mute timer every minute. The timer doesn't start at the time the mute command is issued, so its never exactly how many minutes you entered.
2. A players muted minutes only counted down while the player is connected. This makes sense, but not at a scale of, say, a one day mute. Instead of a player being muted for 24 real life hours, they would be muted for 24 playing hours, meaning you would have to play the server for 24 hours for your mute to clear.
3. Players didn't know when they were muted or gagged. The command echo shows up at the time of them being muted, but if they disconnect and reconnect 30 minutes later, they have no obvious way of knowing they are muted.
