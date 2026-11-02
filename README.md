# TowerDefense

A small Roblox tower defense game (lobby + portal, START button, unit hotbar) set up for [Rojo](https://rojo.space/).

## Setup
1. Clone: `git clone https://github.com/bloooperz/TowerDefense.git`
2. In the folder, run `rojo serve`.
3. Open a Baseplate place in Studio, open the Rojo plugin, click **Connect**.
4. Keep the default `SpawnLocation` near (0, 0, 0) (not under the portal at (0, 0, -30)). Press Play.

To get updates: `git pull` while `rojo serve` is running — Studio syncs automatically.

## Layout
| Folder | Syncs to |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` (Config) |
| `src/server` | `ServerScriptService.Server` (Main, World, Match, Enemies, Towers, Abilities/) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` (Main, Hotbar, Placement) |

## Controls
- Walk into the purple circle in the lobby to go to the map.
- **START** button begins the waves (you can place units before starting).
- **1 / 2 / 3 / 4** (or click a slot) to pick a unit, move the mouse to aim, **left-click** to place.
- **Q** or **right-click** cancels.

## Adding a unit
Add an entry to `Config.UNITS` in `src/shared/Config.luau`:
```lua
{ name = "Splash", cost = 150, size = 3, range = 20, damage = 40, rate = 1.0 },
```
The hotbar builds itself from that list (keys 1–6 are bound). Waves are tuned in `Config.waveInfo`.

## Unique units
**Mogumo** (slot 4, $150, unique: 1 per player) — white cube with a black slab on top.
- Attack: 15 damage, range 22, every 0.8s.
- Passive **Divine Dogs**: every 4th attack spawns a black dog on the nearest point of the track. It runs backward toward the enemy spawn (20 studs/s, up to 3s), dealing 40 damage once to each enemy it passes. Max 2 dogs per Mogumo.

To add another unique unit:
1. Add a `Config.UNITS` entry with `unique = true`, optional `topper = Color3`, `ability = "Name"` and an `abilityConfig` table.
2. Create `src/server/Abilities/Name.luau` exposing `new(tower, cfg)` returning an object with `onAttack(target)` and `cleanup()` (see `Mogumo.luau`).
