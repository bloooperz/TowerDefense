
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

## Lobby UI (`client/Lobby/LobbyUI.luau`, components in `client/UI/`)
All UI is built in code, with no StarterGui instances. Rojo then owns every line, diffs stay reviewable, and the UI can read registries directly.
- `UI/Theme`: colors, outline stroke, gloss gradient, outlined label (card glow lives in `UI/Shape`).
- `UI/Button`: rounded glowing icon button with a shortcut letter, an optional "New!" tag and hover/press UIScale tweens. Click handlers run under `Log.try`.
- `UI/Panel`: modal panel with a title, a "Coming soon" body and a close button. `Panel.register({open, close})` adds any panel (MapSelect included) to the one-open-at-a-time manager, which provides `toggle`, `closeCurrent` and closing on Esc.
- `UI/Card`: unit card with a ViewportFrame portrait (cube plus topper), rarity border, Lv, cost, name, damage-type badge and element badge.
- The lobby is visible only while `MatchState == "lobby"`; the in-match Hotbar and HUD are unchanged.
- **Play** sends `RequestPlay`. The server responds exactly as if the player had stepped into the portal: it offers a pick or a join, or rejects with a toast.
- Shortcuts: I Inventory, K Units, T Trade, F Summon, P Play, J Quests, B Battlepass, U Profile, G Friends.
- Data: Gems, Gold, Rerolls, Xp, Loadout and LoadoutLevels player attributes. The level bar uses `PlayerLevel.progress`.

## Unit display metadata
Unit definitions carry `rarity` (Common/Rare/Epic/Legendary/Mythic), `damageType` (Physical/Magical) and an optional `element` (Fire/Ice/Lightning/Shadow/...).
**These are display-only for now.** Combat.damage ignores them. Future hooks are resistances by damage type and element in `Damage.compute` opts, set via the `source` table.
