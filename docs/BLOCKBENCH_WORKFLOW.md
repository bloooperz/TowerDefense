# Blockbench to Roblox: R6 Unit Model Workflow

How to make an original R6-style unit model for free with Blockbench and plug it into the game's unit model system (see `docs/UNIT_MODELS.md`).
Steps marked *(unverified)* could not be confirmed against official docs.

## Stage 1: Export an R6 block rig from Studio (OBJ)
1. In Studio: **Avatar tab > Rig Builder > R6 > Block Rig** *(unverified: exact menu labels)*. A dummy appears in Workspace.
2. Move it to the world center, position (0, y, 0).
3. In the **Explorer**, right-click the rig > **Export Selection** and save as `.obj` (the option doesn't appear when right-clicking in the 3D view; newer builds may nest it under **Save/Export**). See [DevForum: export rig as OBJ](https://devforum.roblox.com/t/how-to-export-rig-as-an-object-file/2785916).
4. Studio writes an `.obj`, an `.mtl`, and usually a `.png`. Studio exports OBJ only.

## Stage 2: Import into Blockbench (Generic Model)
1. **File > New > Generic Model** (no game limits, supports per-face UV and multiple textures). See [Blockbench formats](https://blockbench.net/wiki/blockbench/formats/).
2. **File > Import > OBJ** and pick the rig `.obj`. Use OBJ; FBX import isn't supported *(unverified)*.
3. No official R6 template was found; **File > Plugins** is worth a quick look, but the Studio export works.

## Stage 3: Keep the R6 body as a locked reference and model on top
1. In the **Outliner**, put all imported body parts in a group named `REF_R6` and **lock** it.
2. Make one group per new piece: `Hair`, `Jacket`, `Pauldron`, `Weapon`, etc. Build from chunky cubes. Give every cube thickness (Roblox needs watertight meshes with volume). See [Roblox mesh specifications](https://create.roblox.com/docs/en-us/art/modeling/specifications.md).
3. Texturing:
   - **Textures panel > Create Texture**: 256x256 for hair/props, 512x512 for clothing; 1024 max. See [texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications).
   - Paint in the **Paint** tab. One texture per mesh (a MeshPart takes one texture).
   - Leave a few pixels of padding between UV islands to avoid color bleed; keep UVs inside the 0-1 square.
4. Save the source with **File > Save Model** (`.bbmodel`) and back it up. It's the editable master and proof the work is yours.

## Stage 4: Export glTF and bring it into the game
1. Hide or delete `REF_R6`.
2. **File > Export > Export glTF Model (.gltf/.glb)** (keeps pieces separate, embeds textures). See [Blockbench export formats](https://blockbench.net/wiki/guides/export-formats/).
   - Set export scale to 16 so 16 Blockbench units = 1 stud *(unverified; the game auto-scales anyway)*.
   - Use a recent Blockbench; versions before 4.7.0 flipped glTF texture UVs.
3. In Studio: **File > Import 3D** ([3D Importer docs](https://create.roblox.com/docs/en-us/art/modeling/3d-importer.md)). Settings:
   - Scale Unit: **Stud**
   - World Forward: **Front**
   - World Up: **Top**
   - Rig Type: **No Rig**
   - Click **Import**.
4. Clean up:
   - Select every MeshPart: **Anchored = true**, **CanCollide = false**, **CanTouch = false**.
   - Delete empty/cage models the import added.
   - Set the Model's **PrimaryPart** to the torso piece and rotate so it faces **-Z** (Studio's front).
   - Missing texture? Import the `.png` and paste its ID into the MeshPart's **TextureID** ([Meshes docs](https://create.roblox.com/docs/parts/meshes)). A SurfaceAppearance overrides TextureID.
5. Rename the Model to the unit's exact id (`Basic`, `Rapid`, `Sniper`, `Mogumo`), move it to **ReplicatedStorage > Assets > UnitModels**, and save the place. The registry resizes it, strips scripts and disables collisions/clicks. No rig or animation needed yet.

## Gotchas
- **Separate R6 parts:** each R6 body part is its own mesh. It's only a reference, so don't ship it. For animation later, model accessories per limb (e.g. head + hair together).
- **Triangle limit:** 20,000 triangles per mesh. Blocky models come nowhere close.
- **Import uploads to Roblox:** importing uploads meshes and textures as assets, so the place must be saved/published to Roblox.
- **Moderation delay:** textures can sit "pending" in moderation for a while *(unverified: duration, ID verification requirements)*.
- **Inside-out faces / flipped model:** enable **Invert Negative Faces** in the importer, or fix faces in Blockbench.
- **Transparency:** PNG alpha works; use fully opaque or fully clear pixels only.
- **OBJ vs glTF:** OBJ uses the `.mtl` for materials and loses the part hierarchy; glTF keeps both.

## Staying DMCA-safe
- Make an original design: keep the general feel, but change the silhouette, colors, accessories and name.
- Don't use the original character's name or symbols, ripped meshes, traced official art, or Toolbox/catalog assets.
- Keep your `.bbmodel` files and painted textures as proof the work is yours.
