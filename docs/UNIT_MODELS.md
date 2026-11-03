# Unit models

Every unit is drawn through `src/shared/UnitModels.luau`. One registry feeds:

- in-match towers (`src/server/Towers.luau`): the cube part is still the hitbox (range, selection,
  attributes, Lv tag); when a model exists the cube turns invisible and the model stands on it.
- portraits (`src/client/UI/Card.luau` `Card.portrait`): Units panel, summon result cards and the
  summon screen featured units.

Source order per unit id (the unit's module name, e.g. `Basic`):

1. `ReplicatedStorage.Assets.UnitModels.<UnitId>` (a `Model`): your real model.
2. Built-in procedural placeholder (`UnitModels.PLACEHOLDERS`: Basic, Rapid, Sniper), Parts only.
3. The original cube (rarity-colored in portraits).

No asset ids or Toolbox models are referenced from code.

## Adding a real model (Studio)

1. Sync the project with Rojo so `ReplicatedStorage > Assets > UnitModels` exists. Both folders
   use `$ignoreUnknownInstances`, so models you add in Studio are not deleted by Rojo.
2. Put your model in `ReplicatedStorage > Assets > UnitModels` and rename it to the unit id
   exactly (`Basic`, `Rapid`, `Sniper`, `Mogumo`, ...). It must be a `Model`.
3. Remove every `Script`, `LocalScript` and `ModuleScript` inside it (the registry also strips
   them on clone, but do not ship them). Toolbox models in particular can hide scripts; search
   the model in the Explorer for `Script` before keeping it.
4. Face it toward -Z (Roblox "front"). Optional: set `PrimaryPart` (else HumanoidRootPart or the
   largest part is used). Size does not matter: it is scaled so its largest side is
   1.3x the unit's `size` in matches and framed automatically in portraits. Feet go on the ground.
5. Save the place. Rojo does not write Studio changes back to the repo; to version a model,
   right-click it > Save to File (`.rbxm`) into `assets/UnitModels/` and map it in
   `default.project.json` under `Assets.UnitModels`.

All parts are made Anchored, CanCollide/CanQuery/CanTouch false and Massless; the model is
visual only. Templates are looked up once and cached (`UnitModels.reset()` clears it).
