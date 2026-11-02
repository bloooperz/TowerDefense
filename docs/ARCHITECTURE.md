# Architecture

Rojo maps `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`,
`src/client` → `StarterPlayer.StarterPlayerScripts.Client`.

## Module map
```
shared/
  Config            global constants (economy, vote timer, refunds, target modes)
  Net               remote definitions (+ arg types, rate limits); server & client API
  Units/            unit registry; one module per unit (Basic, Sniper, Rapid, Mogumo)
  Enemies/          enemy registry (Basic, Fast, Tank, Flying, Boss)
  Maps/             map registry with waypoint paths (TrainingGrounds, Zigzag)
  Modes/            mode registry (Story, Infinite)
  Path              PURE polyline math (position at distance, nearest distance)
  UnitStats         PURE stats at level, max level, caps
  Damage            PURE damage formula (multipliers, armor, crit)
  StatusLogic       PURE status stacking & queries (slow/stun/burn)
  Waves             PURE wave generator (enemy groups per wave)
  Rewards           PURE match reward formula
  DataSchema        PURE player data defaults + versioned migrations
server/
  Main.server       boot: Net, PlayerData, World, Match
  World             builds lobby, builds/clears a map from a Map definition
  Enemies           live enemies: distance-along-path math, statuses, regen, shields, health bars
  Combat            damage pipeline + per-player stats + kill hooks
  Towers            placed units, attack loop, upgrades, sell, ability host
  AbilityApi        utility API abilities use (enemies in range, damage, status, effects)
  Abilities/        one module per unit ability (Mogumo)
  Match             lobby → map select → vote → waves → results → lobby
  Services/PlayerData  DataStore wrapper with session locks, autosave, migrations, mock
client/
  Main.client       wires everything
  Net (shared)      client side of remotes
  PathRenderer     moves enemy parts locally from replicated (Dist, CheckTime, Speed)
  Hotbar            loadout-driven hotbar with caps
  Placement         ghost, ring, cursor reasons
  UnitPanel         upgrade / sell / targeting
  Hud               wave, HP, vote, cash, unit list
  MapSelect         portal UI (map + mode)
  Results           victory / defeat screen
  MyUnits, Style    helpers
tests/              lune specs for PURE modules (`lune run tests/run`)
```

## Data flow
- **Server is authoritative.** Clients only send intents through `Net` (Place, Upgrade, Sell,
  SetTargeting, Vote, ChooseMap, ReturnToLobby). Every handler validates types, rate, ownership,
  cash and match state.
- **Replication via attributes**, not remote spam:
  - `ReplicatedStorage.MatchInfo`: MatchState, MapId, ModeId, Wave, WaveTotal, EnemiesLeft,
    BaseHP, BaseMaxHP, Countdown, Votes, InMatch, MaxWaves.
  - Player: `Voted`, `Loadout` (comma-separated unit ids), `Gems`, `Level`.
  - Unit parts: UnitId, UnitType, OwnerId, Level, Spent, Targeting.
  - Enemy parts: Dist, CheckTime, Speed, Height (map from MatchInfo.MapId). Client `PathRenderer` computes
    the position each frame with `Path.positionAt`; the server uses the **same** math.
- **Movement** is time-based: `dist = Dist + (serverNow − CheckTime) × Speed`. When speed
  changes (status), the server "checkpoints" (writes new Dist/CheckTime/Speed). No physics.
- **Server tick** (10 Hz): statuses expire/burn, regen, leaks, ability `onTick`.

## How to add…
### A unit
1. Create `shared/Units/MyUnit.luau` returning a table (see `Basic.luau`): `id`, `name`,
   `cost`, `size`, `range`, `damage`, `rate`, `maxPlaced`, optional `upgrades`, `topper`,
   `unique`, `canHitAir`, `ability`, `abilityConfig`, `role`.
2. Optional ability: `server/Abilities/MyUnit.luau` (see below). Set `ability = "MyUnit"`.
3. Add its id to `Config.STARTER_LOADOUT` or grant it via data.
### An ability
Module returns `{ new = function(tower, cfg, api) return obj end }`. Object may implement:
`onPlace()`, `onAttack(target)`, `onTick(dt)`, `onUpgrade(level)`, `onEnemyKilled(enemy)`,
`onWaveStart(wave)`, `cleanup()`. `tower.ability.cfg` is updated on upgrade. Use `api`
(`AbilityApi`): `enemiesInRange`, `damage`, `applyStatus`, `spawnEffect`, `path`, `now`.
### An enemy
`shared/Enemies/MyEnemy.luau`: `id, hp, speed, size, color, armor?, shield?, regen?, flying?,
boss?, reward`. Reference it from `Waves` or a map's wave list.
### A status effect
Add to `StatusLogic.DEFS` with `stacking = "max" | "longest" | "stack"` and parameters. Update
`StatusLogic.speedMult` / `tickDamage` if it affects movement or damage over time.
### A map
`shared/Maps/MyMap.luau`: `id, name, waypoints` (relative to `Config.MAP_ORIGIN`),
`trackWidth`, `bounds` (half extents), `spawnOffset`, optional `waves` override.
### A mode
`shared/Modes/MyMode.luau`: `id, name, maxWaves` (nil = infinite), `hpScale`, `rewardScale`.
