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
3. **Event capsules give the cool stuff; rerolls are a fallback; capsules are limited.**
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
- **Out of match** progression (gems, XP, units, rerolls, capsules) persists via PlayerData.

## 4. Progression & economy
| Currency | Scope | Faucets | Sinks |
|---|---|---|---|
| Gold (in-match cash) | match | start cash, kills, wave bonus, farm units | placing, upgrades |
| Gems | persistent | match rewards, first clears, quests, events | summons, capsules (event), cosmetics |
| Unit XP | per unit instance | match rewards to equipped units | — (levels raise unit base stats slightly) |
| Player XP | persistent | match rewards | — (unlocks maps/modes, loadout slots) |
| Rerolls | persistent | events, milestones, duplicate units | trait rerolls |
| Event capsules | per event, capped | event play, event milestones | opening for event units/skins |
| Gold (persistent `gold` field) | reserved | — | reserved for upgrades/crafting later |

Rules of thumb:
- A loss still pays (≈40–60% of a win at the same wave count). Rewards scale with waves cleared.
- First clear of a Story stage pays a one-time bonus; repeats pay the normal rate.
- Daily soft caps on gem income from repeated runs beat hard walls — prefer diminishing
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
5. **Events**: time-limited maps/modes with capped event capsules.

## 9. Live-ops / seasonal plan
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
