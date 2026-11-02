# Playtest Checklist (regular player, no dev menu)

Each step has numbered actions and PASS/FAIL criteria. Write your results in the **Result** line under each section. Every value below was checked against the code at the time of writing. Anything marked **NOT IMPLEMENTED YET / SKIP** does not exist in the game yet.

Result legend: `PASS` / `FAIL` / `SKIP`. On any FAIL, take a screenshot of the screen **and** the Output window, then fill in the bug template at the bottom.

---

## 0. Setup

**Internal testers (Studio + Rojo):**
1. Open a terminal in the repo folder (e.g. `C:\Projects\TowerDefense-repo`) and run `git pull`, then `rojo serve`.
2. Open the place in Roblox Studio. In the Rojo plugin, click **Connect**. If it was already connected, click **Disconnect** and then **Connect** again.
3. Turn on saving: **Home > Game Settings > Security > Enable Studio Access to API Services**, then click **Save**. The place must be published for this option to exist. If you can't enable it, the game uses a temporary in-memory save, so progress resets every time you stop. In that case, skip sections 5 and 6.
4. Open Output: **View > Output**. Keep it visible the whole time.
5. Press **Play** (F5).

**External testers (published game):** just join the game from Roblox. You can't see Output there; report what you see on screen.

Result: ____

---

## 1. Join

1. Start the game with a **new** account (or one with no saved data) and wait in the lobby.
2. Watch the screen during the first few seconds.

PASS if all of these are true:
- [ ] The lobby loads and you can walk around.
- [ ] No **red** lines in Output. Orange warnings are covered in section 8.
- [ ] The level bar reads exactly **`Level 1 [0/100]`** with an empty fill.
- [ ] A **new** account starts with **no units** and shows **0 Gems, 0 Gold, 0 Rerolls**.
- [ ] A **"Choose your starter"** screen appears over the lobby. It shows one card: **Basic**.
- [ ] Before choosing, pressing **P** / Play shows the toast *"Choose your starter unit first"* and no stage starts.
- [ ] Click **Choose** (try double-clicking). You get exactly **one** Basic on the hotbar, Gems become **500**, and the screen closes.
- [ ] Rejoin: the starter screen does **not** come back, and you still have 1 Basic and 500 Gems.
- [ ] An **older** account that already had units does not see the starter screen.
- [ ] The text "Label" does not appear anywhere on screen.

FAIL if any of these are false.

Result: ____

---

## 2. Summon

Default values: **50 Gems per roll**. x1 = 50, x10 = 500, x50 = 2500 (no bonus). Rates: Rare 78.5%, Epic 21.5% (Legendary 3% and Mythic 0.5% pass down to Epic because no summonable unit has those rarities yet). Pity: Epic guaranteed by roll **300**. The banner changes every **30 minutes** and is the same on every server. **Mogumo is never in the banner.**

1. Press **F** or walk into the gold Summon circle.
- [ ] The Summon panel opens (not "Coming soon"). It shows banner unit cards (Basic, Rapid, Sniper, never Mogumo), a **"rotates in mm:ss"** countdown that ticks down, **Pity 0 / 300**, the x1/x10/x50 buttons with their Gem cost, and a **Rates** button.
2. Click **Rates**.
- [ ] A popup lists the rarity percentages and units. Close it with **X**.
3. With 500 Gems, click **Summon x1**.
- [ ] Gems go **500 -> 450** right away. One card pops in, with a **Skip** button during the reveal. Pity goes up by 1 unless the result was Epic (Epic resets it to 0). The new unit appears in the Units panel.
4. Click **Summon x10** with fewer than 500 Gems.
- [ ] Toast *"Not enough Gems"*. Gems do not change.
5. Settings > Summon: turn on **Skip summon animation**, then summon again.
- [ ] All result cards appear at once.
6. Settings > Summon: turn on **Auto-sell** with the threshold **Rare**, then summon.
- [ ] Rare results show **"Auto-sold +10"**, are not added to your units, and Gold goes up right away. Epic results are kept. Picking **Mythic** as the threshold asks you to click again to confirm.
7. Units panel: select a unit that is **not** on your hotbar and click **Sell for N Gold** (Rare 10, Epic 20, Legendary 40, Mythic 100).
- [ ] The unit is removed and Gold goes up. Selling a hotbar unit, or your last unit, is refused with a toast. Mythic and above ask you to confirm.
8. Press **P** / Play and click **Rates** in the map picker.
- [ ] The same rates popup opens.

Result: ____

---

## 3. Place a unit in a stage

1. Press **P** or click **Play**, choose a map (Training Grounds or Zigzag Valley) and a mode (**Story** = 10 waves, or **Infinite**).
2. You start the match with **200 cash**. Press **1–6** to choose a hotbar unit, then click a valid spot beside the path. Press **Q** to cancel placement.
3. Place several units. In-match placement costs: Basic 50, Rapid 90, Sniper 120 (Mogumo 150, but he can no longer be summoned; only old test accounts still own him).

PASS if:
- [ ] The placement preview shows; units can't be placed on the path or overlapping other units.
- [ ] The cost is deducted; trying to place without enough cash shows **"Not enough money!"**.
- [ ] Units attack enemies inside their range and switch to new targets.
- [ ] No freezes or lag spikes during waves.
- [ ] No red errors in Output.

Result: ____

---

## 4. Complete a stage

How rewards are calculated:
- **Player XP** = 10 per wave cleared (halved on a loss) + 50 if you win, multiplied by the mode scale.
- **Gems** = 5 per wave cleared (halved on a loss) + 50 if you win, + 50 extra on the first win of that map and mode. Then multiplied by the mode scale and capped at 500 per run (minimum 1).
- **Unit stage XP** (each equipped unit) = 20 per wave + 200 if you win, multiplied by the mode scale. Losses are **not** halved.
- **Mode scale:** Story = **1.0**, Infinite = **0.8**. Infinite has no win; it always ends in a loss.
- **Player level:** you need 100 × (Level − 1)² total XP, so Level 2 = 100, Level 3 = 400, Level 10 = 8,100.

Expected results:

| Run | Player XP | Gems | Unit XP each |
|---|---|---|---|
| Story win, 10 waves (first clear) | 150 | 150 | 400 |
| Story win again | 150 | 100 | 400 |
| Story loss after 4 waves | 20 | 10 | 80 |
| Infinite, 5 waves | 20 | 10 | 80 |

For a new account, a first Story win (150 XP) takes you to **Level 2**, and the bar should read `Level 2 [50/300]`.

1. Win a Story run (or lose one and use the loss row above).
2. Read the results screen, then return to the lobby.

PASS if:
- [ ] The results screen shows VICTORY or DEFEAT, map and mode, waves cleared, time, **Kills**, **Damage** (your total damage), **+Gems**, **+XP**, **Player Lv**, and per-unit XP lines.
- [ ] The numbers match the table above.
- [ ] The lobby level bar and Gems update to match.
- [ ] The unit cards show unit XP / level changes where expected.
- **MVP:** NOT IMPLEMENTED YET / SKIP. There is no MVP on the results screen.

Result: ____

---

## 5. Leave and rejoin: CRITICAL data-safety check

This tests the new save fixes: saves retry on failure, the game never takes over another server's data lock, and a server that loses the player's session reloads their data instead of keeping an old copy.

1. Before leaving, write down your Level bar text, Gems, unit levels/XP, Gold/Rerolls, and the **Pity X / 300** number in the Summon panel.
2. Leave the game: stop Play in Studio, or leave the published game.
3. **Wait about 10 seconds**, then rejoin.

PASS if:
- [ ] Level, XP, Gems, Gold, units (and their levels/XP), loadout and **Pity** are exactly what you wrote down.
- [ ] No red errors in Output.

Expected and **not** a bug: if you rejoin very quickly in the published game, the previous server may still hold your data. The game then **waits up to 90 seconds** while loading. If it's still held after that, you'll be kicked with *"Your data is still open on another server. Please wait a minute and rejoin."* Just rejoin after a minute. FAIL only if your data comes back wrong, or this keeps happening after waiting.

Result: ____

---

## 6. Failed-save check (OPTIONAL / ADVANCED, Studio with API access only)

There is no button that forces a save to fail. Practical ways to test:
- **A. Lose access while playing:** play with API access enabled and earn some XP. Then, while still in Play, open Game Settings and turn **off** Studio Access to API Services. Wait 60 seconds for the autosave (which may now fail), then stop. Results vary; some Studio versions apply the setting only on the next Play.
- **B. Network loss:** play, earn XP, briefly disconnect your internet, wait about 60 seconds, then reconnect.

What to look for in Output (exact text, name = your player):
- `[TD:PlayerData] save failed for <name> attempt 1/4 <error>`, then attempts 2/4, 3/4 and 4/4, about 1s, 2s and 4s apart.
- On recovery: `[TD:PlayerData] save for <name> succeeded on attempt N`
- If every attempt fails: `[TD:PlayerData] ERROR save FAILED for <name> after retries; progress since last save may be lost`
- During shutdown: `[TD:PlayerData] save for <name> : out of shutdown time budget, no more retries`
- Session takeover (only seen when two servers are involved): `save for <name> skipped: session lock is held by another server (lost lock); not writing stale data`, then `lost session lock for <name> ; dropping stale copy and reloading`
- Waiting on a lock: `profile for <name> locked by another server ... waiting (attempt N)` / `giving up on <name> : still locked by another server after N s (not stealing)`

PASS if: the retry lines appear, and after reconnecting, a rejoin shows at most the progress since the last successful save missing. Nothing else should be wrong, and no unit or currency should be duplicated.

Result: ____

---

## 7. Dev menu hidden for regular players

How it is gated: the client menu (`DevMenu.luau`) is only built when `RunService:IsStudio()` is true. The server cheat remotes (`Dev.luau`, Net `studioOnly`) are never created outside Studio, and every server handler checks again. In Studio it opens with **F2**.

1. Join the **published** game from the Roblox app (not Studio). Studio Team Test also counts as Studio, so it is not a valid test here.
2. Press **F2** and look for any dev or cheat buttons.

PASS if:
- [ ] Nothing opens, and there are no sandbox, infinite cash or god mode options.
- (Optional, Studio) F2 does open the menu in Studio, which is expected.

Result: ____

---

## 8. Orange DataStore warnings

- An orange line `[TD:PlayerData] DataStore unavailable, using in-memory mock (progress resets on stop)` in Studio means API access is off. This is **expected**. Either enable access (section 0, step 3) or ignore it, but then sections 5 and 6 can't be tested.
- Other orange DataStore throttling or "request queue" warnings in Studio are usually harmless. Note them if they repeat a lot.
- **Red** lines are never expected. Always report them.

Result: ____

---

## Bug report template

```
Title:
Section / step #:
Studio or published game:
What I did (steps):
What I expected:
What actually happened:
Output screenshot (red/orange lines) attached: yes / no
Screen screenshot attached: yes / no
Happens every time? yes / no / sometimes
Account: new / existing (level __)
```
