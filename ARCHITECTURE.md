
## Error visibility (no silent failures)

- **Log module** (`Shared/Log`): `local log = Log.new("Match")` gives `log.info/warn/error`, all prefixed `[TD:Match]`.
  `Log.try(tag, what, fn, ...)` runs `fn` under `xpcall`, warns `ERROR in <what>` plus a traceback, and returns the pcall results. It never throws.
- **Remote handlers** (`Net.on`): a handler **returns a reason string to reject**. Net then warns `<player> <remote> rejected: <reason>` and fires `Notify(reason, "error")` to that client, which shows it as a toast. Bad args become "Bad request (X)", and a thrown error becomes "Server error (X)" plus a traceback. Rate-limit drops are warned, throttled to once per 5 s.
- **Wrapped in Log.try:** ability hooks and `new`, tower attacks, the Combat/Towers tick, kill/leak listeners, player data load and change listeners, map building, enemy spawns and the wave loop (a crash notifies players and resets the match), the portal loop, and each server and client init step.
- **Client:** `Toast.show(text, kind)` handles server notices and local reasons. Client failures go to Output with `[TD:Client]`.
- **Build stamp:** `Config.BUILD` is printed by both server and client (`[TD:Main] server starting, build X`). If the two don't match, or the line is missing, Studio is running stale scripts.
- **Pure rules** (`PlacementRules`) return reason strings, so client preview, server authority and tests all agree.

## Portal flow
When a player enters the portal circle (edge-triggered), the server sends `OpenMapSelect {kind="pick"}` (idle) or `{kind="join", mapName, modeName, players}` (waiting). Nobody is moved until the client confirms with `ChooseMap`/`JoinMatch`. The offer stays valid for 120 s, even after stepping out. While a match is running, entering the portal shows an "in progress" toast.
