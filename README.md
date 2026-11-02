# TowerDefense

An anime-style Roblox tower defense game built with [Rojo](https://rojo.space/). The content is data-driven: units, enemies, maps and modes each live in their own registry. Player profiles are saved, and every run pays out rewards.

See **[docs/DESIGN.md](docs/DESIGN.md)** for the game design pillars and **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** for the module map and how to add each content type.

## Setup
1. Clone: `git clone https://github.com/bloooperz/TowerDefense.git`
2. In the folder, run `rojo serve`.
3. Open a Baseplate place in Studio, open the Rojo plugin, click **Connect**.
4. Keep the default `SpawnLocation` near (0, 0, 0), not under the portal at (0, 0, -30). Press Play.
5. Optional: to test real saving in Studio, turn on *Game Settings → Security → Enable Studio Access to API Services*. Without it, profiles use an in-memory mock (a warning is printed) and reset when you stop.

To get updates, run `git pull` while `rojo serve` is running. Studio syncs automatically.

## Layout
| Folder | Syncs to | Contents |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | Config, Net, registries (`Units/`, `Enemies/`, `Maps/`, `Modes/`), pure logic (Path, Damage, StatusLogic, Waves, Rewards, UnitStats, DataSchema) |
| `src/server` | `ServerScriptService.Server` | Main (10 Hz sim tick), World, Match, Enemies, Combat, Towers, AbilityApi, `Abilities/`, `Services/PlayerData` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Main, PathRenderer, Hud, Hotbar, Placement, UnitPanel, MapSelect, Results, MyUnits, Style |
| `tests` | — | lune unit tests for the pure shared modules |

## Playing
- Walk into the purple portal. If no match is open, a **map and mode picker** appears. Pick a map (Training Grounds or Zigzag Valley) and a mode (Story: 10 waves, or Infinite), then press **Start**. Other players who walk into the portal join that match.
- **Vote Start** toggles your ready vote. The match begins when everyone has voted or when the 30 s countdown ends.
- The hotbar shows your **loadout** (up to 6 units; you start with Basic, Sniper, Rapid and Mogumo). Use **1–6** or click a slot, then **left-click** to place. **Q** or **right-click** cancels.
- Click a placed unit to open its panel: targeting, upgrade, sell.
- Enemies: Grunt, Runner, Tank (armored), Flyer (hovers; dogs can't hit it) and Boss (shield and regen, appears every 10th wave and on Story's final wave). Health bars show HP, with the shield in blue.
- When the match ends, a **Victory/Defeat** screen shows waves cleared, time, kills, damage, and the gems and XP you earned. Losses still pay about half.

## Adding content (short version — details in ARCHITECTURE.md)
- **Unit:** add `src/shared/Units/Name.luau` returning `{ name, cost, size, range, damage, rate, maxPlaced, upgrades = {...} }`. For a passive, add `ability = "Name"` and `src/server/Abilities/Name.luau` with `new(tower, cfg, api)` and any hooks: `onPlace`, `onAttack`, `onTick`, `onUpgrade`, `onEnemyKilled`, `onWaveStart`, `cleanup`.
- **Enemy:** `src/shared/Enemies/Name.luau` with `{ hp, speed, size, reward, color, armor?, shield?, regen?, flying?, boss? }`.
- **Map:** `src/shared/Maps/Name.luau` with `waypoints`, `trackWidth`, `bounds`, `groundSize` and `spawnOffset`. It appears in the picker automatically.
- **Mode:** `src/shared/Modes/Name.luau` with `{ name, maxWaves?, hpScale, rewardScale }`.
- **Remote:** add an entry to `Net.DEFS` with argument types and a rate limit.
- **Saved field:** bump `DataSchema.VERSION`, add a migration and update `default`. Add a test.

## Tests
```
lune run tests/run
```
These cover path math, the damage formula, status stacking, the wave generator, rewards, unit stats and data migrations.

## Mogumo (unique)
$150, 1 per player. Passive **Divine Dogs**: every 4th attack, a dog spawns on the track nearest Mogumo and runs backward toward the spawn. It bites each ground enemy it meets (40 damage plus a 0.4 s stun; bosses take half the stun). Upgrades raise dog damage and the dog cap, and at Lv 4 a dog comes every 3rd attack.
