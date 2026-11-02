# TowerDefense — Design Document

Living document. When a feature contradicts a pillar, change the feature, not the pillar.

## 1. Vision
An anime-inspired Roblox tower defense where **who you bring and how they interact** is the game.
Every unit is a character with a recognisable mechanic; teams are puzzles you solve with
synergies, not spreadsheets you solve with the highest DPS number. Sessions are short, every run
pays out something usable, and the collection grows through fun events rather than grind walls.

## 2. Pillars
1. **Passives are in-character mechanics.** A passive must do something you can *see* and
   *play around*: Mogumo summons Divine Dogs that run back down the track. "+10% damage" is
   not a passive; it is a stat. Every passive should answer "what would this character do?"
2. **Units + passives define teams; traits are small side bonuses.** Team identity comes from
   unit choice and passive interplay (control + burst, economy + scaling, etc.). Traits add a
   few percent in a narrow direction and **no trait is universally best** — each trades
   something or only shines in some compositions.
3. *(Planned, not implemented yet)* **Event capsules give the cool stuff; rerolls are a fallback; capsules are limited.**
   Event-exclusive units and skins come from capsules earned by playing the event. Capsules
   are limited per event so they feel special. Rerolls (for traits / stats) are a safety
   net, never the main chase.
4. **Grind must be fun and every run pays.** Every completed or failed run grants usable
   rewards scaled by effort. No 0.01% drops. No systems that reward AFK macros (rewards cap
   per run, require engagement such as placing/upgrading, diminishing returns for repeated
   identical idle runs).

## 3. Core loop
```
Lobby ──► Loadout (up to 6 units) ──► Portal: choose Map + Mode ──► Map
  ▲                                                                   │
  │                                                         Vote start / countdown
  │                                                                   ▼
Summon / Upgrade ◄── Rewards (gems, unit XP, player XP) ◄── Waves (win / lose)
```
- **In-match** gold is earned from kills and wave bonuses and spent on placing, upgrading,
  selling units. It resets every match.
- **Out of match** progression (gems, XP, units, XP food items, milestones; rerolls/capsules planned) persists via PlayerData.

## 4. Progression & economy
| Currency | Scope | Faucets | Sinks |
|---|---|---|---|
| Gold (in-match cash) | match | start cash, kills, wave bonus, farm units | placing, upgrades |
| Gems | persistent | match rewards, milestones (planned: first clears, quests, events) | planned: summons, capsules (event), cosmetics |
| Unit XP | per unit instance | match rewards to equipped units | — (levels raise DAMAGE only: mult = 1 + 4.14·t^1.1725, t = (L−1)/79, up to 5.14× at L80) |
| Player XP | persistent | match rewards | — (unlocks maps/modes, loadout slots) |
| Rerolls | persistent | events, milestones, duplicate units | trait rerolls |
| Gold (persistent `gold` field) | reserved | — | reserved for upgrades/crafting later |

Rules of thumb:
- A loss still pays (≈40–60% of a win at the same wave count). Rewards scale with waves cleared.
- First clear of a Story stage pays a one-time bonus; repeats pay the normal rate.
- *(Planned)* Daily soft caps on gem income from repeated runs beat hard walls — prefer diminishing
  returns over zero.
- Duplicates are never wasted: convert into rerolls or unit XP.

## 5. Unit design rules
### Roles
- **DPS** — kills things. Single-target (Sniper) or sustained (Rapid).
- **Support** — makes others better *through a mechanic* (marks enemies, chains attacks,
  extends status durations). Not flat aura buffs as the main identity.
- **Control** — slows, stuns, pushes back, splits paths (Mogumo's dogs are control/DPS).
- **Farm / economy** — generates gold over waves; costs placement slots and early tempo.

Every unit: one role primary, at most one secondary. Placement cap (`maxPlaced`) controls
how much of a role you can stack.

### Passive guidelines
Good:
- *Divine Dogs* (Mogumo): every Nth attack spawns dogs running backward along the path,
  hitting each enemy once. Readable, positional, rewards placement near the path start.
- A swordsman whose every 3rd hit is a dash that **stuns the first enemy** it passes.
- A fire mage whose burn **spreads to a nearby enemy when the burned target dies**.
Bad:
- "+15% damage to all units." (stat buff, no character)
- "5% chance to instantly kill any enemy." (random, unreadable, breaks bosses)
- "Gains 1% damage per second forever." (degenerate scaling, AFK-friendly)

### Upgrades
4 levels by default. Upgrades change numbers *and* may enhance the passive (more dogs,
shorter cooldown). The final level should feel like a power spike, not +5%.

## 6. Enemy taxonomy
- **Ground** — default; follows path.
- **Flying** — follows path at height; some units cannot hit air (`canHitAir = false`).
- **Boss** — large HP, slow, often immune to stun (reduced effect), pays big rewards.

Modifiers (combinable):
- **Armor** — flat % damage reduction (0–0.9). Countered by high single hits / armor pen.
- **Shield** — separate pool consumed before HP. Countered by burst / multi-hit.
- **Regen** — HP per second. Countered by burn / sustained DPS.

Status interactions:
| Status | Effect | Stacking |
|---|---|---|
| Slow | speed × (1 − amount) | strongest wins, duration refreshes |
| Stun | speed 0 | longest remaining wins; bosses take 50% duration |
| Burn | damage per second | stacks up to `maxStacks`, each stack own timer |

## 7. Traits philosophy
Traits are rolled on a unit instance (`trait` field). Small, directional, with trade-offs:
- *Swift*: +attack speed, −range. *Far-Sighted*: +range, −attack speed.
- *Thrifty*: −placement cost, −damage. *Brutal*: +crit chance, +upgrade cost.
No trait should be the default pick for every unit. If telemetry shows one trait on >40% of
endgame units, it is nerfed or redesigned.

## 8. Modes roadmap
1. **Story** (stub): fixed number of waves per map, win condition, first-clear rewards.
2. **Infinite**: endless scaling waves; rewards per wave milestone; leaderboard later.
3. **Challenges**: rotating modifiers (no upgrades, flying-only waves, half gold).
4. **Raids**: co-op boss encounters with mechanics; raid-exclusive materials.
5. **Events** *(planned)*: time-limited maps/modes with capped event capsules.

## 9. Live-ops / seasonal plan — Planned (not implemented yet)
None of this exists in code yet: no event capsules, quests, seasons or daily gem caps. These are
design intent. Planned economy rows: **Event capsules** (per event, capped; faucets: event play,
event milestones; sink: opening for event units/skins) and **Quests** (gem faucet).
- 4–6 week seasons. Each season: 1 event map/mode, 1–3 event units via capsules, skins.
- Capsules earned only via event play and milestones; capped per account per event.
- Returning event units appear in later reruns — no permanent FOMO.
- Balance patch mid-season; changelog in-game.

## 10. Monetization ethics
- No pay-to-win exclusives in competitive leaderboards.
- No paid random boxes with hidden odds; always show odds; pity systems where randomness exists.
- Cosmetics, convenience (extra loadout presets), and battle-pass style tracks that are fully
  earnable through play are the preferred revenue paths.
- Never sell capsules beyond the event cap.

## Trading System — Implementation Plan (Deferred)

Status: deferred, not started. Do not build this until the prerequisites below are met. Follow these steps exactly when it is picked up.

### Core rules
- Items never live in MemoryStore. MemoryStore is not permanent (data can be evicted or lost), and its quota is small: about 64KB + 1.2KB per player, so roughly 664KB for the whole game at 500 players.
- Items stay in each player's saved data (the session-locked `Profiles_v1` DataStore profile). The swap happens in memory on the one server both players are on. Cross-server trades: teleport both players to one server first.
- MemoryStore only handles the cross-server parts:
  - per-player trade locks
  - trade invites
  - an optional public offer board later
- No PvP. Trading is the only player-to-player interaction.
- Level requirement: player level 10 (`PlayerLevel.UNLOCKS.Trade = 10` in `src/shared/PlayerLevel.luau`). Check it on the server with `PlayerData.checkUnlock(plr, "Trade")`.
- Placeholders already exist: the pink Trading lobby circle and the Trade panel (`LobbyFeatures` / `LobbyUI` / `Theme`). Wire into them; don't create new ones.

### Flow (server-authoritative)
1. Request: player A invites player B (level gate checked for both; invite via MemoryStore inbox + MessagingService nudge if cross-server).
2. Lock both players in MemoryStore with a 2-minute expiry (TTL 120s). Claim atomically with UpdateAsync, in userId order. If either lock is already taken, cancel. Never steal a lock.
3. Offer units: each player adds/removes units in the Trade panel; the server holds the trade session in a Luau table.
4. Both accept.
5. 5-second countdown. Any change to either offer cancels both accepts and the countdown.
6. Recheck: every offered unit is still owned by its player (by uid) and is not on the hotbar/loadout. Block fuse/feed on units that are in an active trade.
7. Write a trade record to a separate DataStore (`Trades_v1`) with status `committed` (trade id, both userIds, both unit lists).
8. Swap both players' items in one uninterrupted, non-yielding block (no waits or yields inside).
9. Save both players immediately, using the save retries with backoff.
10. Mark the trade record `done` and release both MemoryStore locks.

### Crash recovery
- If the server crashes between the two saves, the `committed` trade record lets the next server that loads either player finish the other player's half.
- Each profile remembers the trade IDs it has already applied (`appliedTrades`), so applying a trade twice is a no-op and nothing duplicates.
- On profile load: check `Trades_v1` for this player's `committed` trades not in `appliedTrades`, apply them, save, and mark `done` when both sides are applied.

### Prerequisites (DONE)
The three PlayerData fixes were required first and are done in commit `7d83550` (`src/server/Services/PlayerData.luau`):
1. Save retries with exponential backoff, including on leave and BindToClose.
2. No forced lock steal: wait for the lock to be released or go stale, otherwise kick.
3. Reload on lost session: if another server takes over, stop saving the stale copy and reload or kick.

## Mogumo — Evolution Reward (Deferred)

- Mogumo is NOT a banner unit and must NOT be in the summon pool.
- He is the highest-tier, hardest-to-get unit of the zero update, obtained only by grinding and evolving: the player must evolve a base unit into Mogumo using evolution materials.
- Evolution is quest-based for the strongest/best units and material-based for other units.
- Do not add Mogumo to any banner, summon config or drop table.
