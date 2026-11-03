# Blender → Roblox beginner workflow

A beginner roadmap for making unit models in Blender for this game: R6-style blocky anime characters with hair and clothing, original DMCA-safe designs, all free tools.

Related docs:
- [BLOCKBENCH_WORKFLOW.md](BLOCKBENCH_WORKFLOW.md): the simpler Blockbench route.
- [UNIT_MODELS.md](UNIT_MODELS.md): how the game finds and uses a unit model.

## 1. Tutorials, in order

1. **PlayerMotion: Blender Game Development Basics** (free, 12 lessons, total beginner, every click explained):
   https://playermotion.games/lessons/blender-foundations
2. **PlayerMotion: Create Your Own Game Characters** (free; an original low-poly character built from simple shapes, with a colour palette and a triangle budget):
   https://playermotion.games/lessons/ztgc-06-create-game-characters
3. **YouTube: "How to 3D Model Roblox Characters (Blender Tutorial)"**, made with Tower Defense Simulator skins in mind. It shows how to trace an R6 rig exported from Studio, plus Mirror, loop cuts, extrude, bevel and inset:
   https://www.youtube.com/watch?v=6YlWYGVo7KI
4. **Roblox Creator Hub docs** (official):
   - Export settings: https://create.roblox.com/docs/art/modeling/export-requirements
   - Modeling specifications: https://create.roblox.com/docs/art/modeling/specifications
   - 3D Importer: https://create.roblox.com/docs/art/modeling/3d-importer
5. **KW Studio: free Blender-to-Roblox 3D modeling course**: https://kwstudio.org/b/learn-roblox-3d-modeling
   (Note: this showed up in search results, but the site blocked a direct check, so it couldn't be confirmed to load.)

## 2. FBX export from Blender

1. Go to File > Export > FBX (.fbx).
2. Set **Path Mode** to **Copy** and turn **Embed Textures** on (the button next to it).
3. Set Transform > **Apply Scalings** to **FBX Unit Scale**.
4. Under Armature, turn **Add Leaf Bones** off.
5. Turn **Bake Animation** off (static unit models have no animation).
6. Click **Export FBX**.

## 3. Import into Studio

1. In Studio, go to **File > Import** and pick the `.fbx`.
2. In the import preview, set:
   - Scale Unit: **Studs**
   - World Forward: **Front**
   - World Up: **Top**
   - Rig Type: **No Rig**
   - Anchored: **on**
   - Upload to Roblox: **off** while testing, so the inventory doesn't fill up with copies.
3. Fix any warning icons in the hierarchy, then click **Import**.
4. Rename the imported model to the unit id (for example `Basic`).
5. Move it to **ReplicatedStorage > Assets > UnitModels**. The game picks it up from there automatically; see [UNIT_MODELS.md](UNIT_MODELS.md).

## 4. What to learn first

1. View navigation: orbit, pan, zoom and the numpad views.
2. Switching between Object and Edit mode with **Tab**.
3. **G / R / S** (move, rotate, scale), plus an axis letter and a number, for example `G Z 1`.
4. **Shift+D** to duplicate and **H** to hide (Alt+H to show again).
5. Tracing a reference: export an R6 rig from Studio as OBJ at position 0,0,0, import it into Blender, and model over it.
6. Extrude (**E**), loop cut (**Ctrl+R**), inset (**I**) and bevel (**Ctrl+B**).
7. The **Mirror** modifier, so you only model one side.
8. Hair: add loop cuts to a stretched cube, then rotate and move faces or vertices to bend each strand.
9. Colour, step by step: first a simple material colour per part, then vertex colours, then UV unwrap with a PNG texture.
10. Cleanup before export: apply rotation and scale (Ctrl+A), centre the model at the world origin, and fix normals.

## 5. Common beginner mistakes

- **Wrong size in Studio:** usually scale that wasn't applied. Press Ctrl+A > Rotation & Scale before exporting.
- **Invisible or see-through faces:** flipped normals. In Edit mode, select everything and use **Mesh > Normals > Recalculate Outside**.
- **Missing textures:** Path Mode wasn't set to Copy, or Embed Textures was off.
- **Mesh rules** (from Roblox's specifications):
  - at most **20,000 triangles per mesh**;
  - the mesh has to be closed, with no holes or exposed backfaces;
  - every piece needs some thickness (no flat planes).
- **Model offset from where it should be:** it wasn't centred at the world origin. Studio's "Set Pivot to Scene Origin" is on by default.

## 6. Scale: test early

Roblox doesn't publish an exact metres-to-studs conversion for Blender. Before building a full character, send one simple test model (such as a cube the size of an R6 torso) all the way into Studio. Fix the size there, then keep the same settings for everything after that.

## 7. Optional: the Roblox Blender plugin

Roblox publishes an open-source reference add-on, "Upload to Roblox", that uploads straight from Blender as a Package:
https://github.com/Roblox/roblox-blender-plugin (download the zip from Releases; it needs Blender 3.2+).
For a beginner, the plain FBX export and import above is simpler, so start with that.
