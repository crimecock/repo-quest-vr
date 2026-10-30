# Porting to R.E.P.O. 0.5.0 (Unity 6000.3)

**English** · [Русский](repo-0.5.0.ru.md)

> The RepoXR patches below (`patches/repoxr/0001-0029`) are also the code of
> [crimecock/RepoXR](https://github.com/crimecock/RepoXR/tree/repo-0.5.0) (branch `repo-0.5.0`), the PC fork; its
> [docs/repo-0.5.0.md](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/docs/repo-0.5.0.md) covers the PC side
> (Unity 6 XR libraries, FixPluginTypesSerialization, the Addressables catalog).

## The pipeline

The builder (`builder/QuestBuilder.Cli`, .NET 8) runs in steps and remembers each one in the work folder's
`state.json`; a step whose inputs did not change is skipped.

1. **export**: AssetRipper 2.0.0 (headless, through its local web API) turns the game into a Unity project. Shaders are
   placeholders, the game's code stays as DLLs.
2. **bake**: HarmonyBaker bakes RepoXR's Harmony patches into the game's assemblies (IL2CPP cannot patch at runtime),
   together with RepoXR.Standalone's `[Replaces]` overrides (Discord, window, MetaManager.Start and others).
3. **project**: Python scripts turn the export into the Quest project: packages instead of DLLs (`package_swap.py`),
   the game assemblies renamed to `REPO.Game`, original GUIDs and Resources names, working shaders instead of
   placeholders (`shader_states.py` + `generate_shaders.py`), XR packages and source edits to Input System, uGUI and
   PostProcessing (`patch_packages.py`), per-pixel lamps, RepoXR, SteamShim, libopus.
4. **unity**: two batch-mode Unity runs: `QuestBuild.Prepare` (settings, Addressables groups, XR), then
   `QuestBuild.BuildApk` (Addressables content, then the APK: IL2CPP ARM64, Vulkan, OpenXR).

## R.E.P.O. 0.5.0's new features in VR

What [the 0.5.0 update](https://store.steampowered.com/news/app/3241660) brought, and what happens to it in the
headset. *Adapted* means this fork changed something for it, *as is* means it comes with the game's own files and code
and needs nothing, *to check* means it has not been tried on a Quest yet. As of 1.0.7-qc21 the build plays on a Quest 3:
the menus, the Steam login, the singleplayer lobby and the levels; multiplayer, vehicles and weapons are still being
checked.

| New in 0.5.0 | In VR | Status |
|---|---|---|
| The game moved to Unity 6 | The whole port had to follow: Unity 6000.3, new package versions, Addressables 2 with a binary catalog, the audio and settings AssetRipper could not read, and Unity 6 turning engine methods RepoXR patches into managed code. The table below has each step | Adapted |
| Gamepad support | VR controllers are the input; the game's new gamepad layer is not used. Menus click through the new `UIClick` key, which RepoXR answers with the pointer's trigger (patch 0009), stay in pointer mode instead of switching to keyboard/gamepad navigation (patch 0010), hover areas fit the world-space menu (0011), the pointers' UI module runs instead of the game's mouse module (0012), and the first main menu is unblocked without its intro (0017) | Adapted; menus work on the headset (1.0.7-qc10) |
| Localization, 21 languages | Comes with the game. The builder reads the game's real Addressables catalog (`catalog.bin`), so all languages are in; the stale `catalog.json` next to it had half of them. RepoXR's own VR settings stay English | As is |
| News, Discord and YouTube buttons in the main menu | They sit on the main menu canvas like the other buttons, so the VR pointer reaches them. A link would leave the game for the Quest browser | To check |
| 10 new cosmetics | Cosmetics now ship as one Addressables bundle per label; the Unity project gets one group per label, so they all build in. Unlocks are kept on the headset (RepoXR.Standalone's `CosmeticsCloud`, adapted to 0.5.0's `MetaManager`) | Adapted |
| New level (Sunstone Valley Resort), new enemy (Pony), new rooms, new items (Human Gun, Human Adventure Cable, Recharge Orb) | Game content: exported and built like the rest. `LevelCulling` handles the new level like any other | As is, to check |
| Expression wheel with previews | RepoXR has its own radial expression menu; its input patch was carried over. The game's previews render with their own cameras into textures, which the camera fix leaves alone | To check |
| *Item Unequip Auto Hold* (Settings → Gameplay, on by default) | An item taken out of an inventory slot stays on the grab beam until the grab is pressed again; off, it falls when the grab is let go. In VR the trigger both takes the item out and grabs: RepoXR's forced hold had to follow the toggle release into `GrabInputActiveGet` (patch 0019) | Adapted; grabbing works on the headset (1.0.7-qc12) |
| Gun aim: a held gun turns to point along the line from the camera through the grab point (`ItemGun.AimTargetUpdate`) | RepoXR holds objects relative to the hand, so the aim measured from the head pointed elsewhere whenever head and hand did. Patch 0020 measures it from the hand: the gun points along the grab beam. Fire: right grip ([controls](controls.md#weapons)) | Adapted, to check |
| Whip (new melee item): crack and fling are mouse/gamepad gestures | Patch 0029: while you hold it, the gestures read how fast your hand turns (snap back and forward to crack, also from over the shoulder; swing to fling what it caught); it also needed the camera aim targets to expire again, which RepoXR skipped. VR Settings → Input → *Whip Sideways Sensitivity* (0.5), *Whip Crack Sensitivity* (1) | Adapted (qc22); works on PC, to check on the Quest |
| Melee "grab lead" | Gamepad only (`MeleeGrabLeadGet` aims a held melee weapon ahead of the gamepad's camera); in VR the weapon is in your hand | Not used in VR |
| Tumble climb rework | RepoXR turns the climb with your hand; the game moved that rotation to `ClimbTargetUpdate`, and the patch moved with it (patch 0009). Needs the Tumble Climb upgrade, stamina and a level wall (layer Default) within about 3 m | Adapted; works on PC (RepoXR fork), to check on the Quest |
| Vehicles (scooter, snow bike, golf cart) with their own keys; holding on to a vehicle toggles by default | RepoXR's steering patches follow the new code (`ControlCameraForward`, snow bike `DriveHeadingUpdate`). The new keys have no VR actions: accelerate/brake/drift ride on the left stick (the snow bike's throttle and steering analog), `VehicleGrab` on the grab trigger as a toggle like in the game, and vehicles take input without the game's own action map (patch 0019). [How to drive](controls.md#vehicles) | Adapted, to check |
| A new text prompt page (`MenuPagePopUpTextInput`) | RepoXR's VR keyboard and the in-headset Steam login use it now; the old rename page is gone | Adapted, to check |
| A platform layer for Steam (`SteamPlatform`) | Calls Steam APIs the Quest's SteamShim did not have; added (`SteamApps`, achievement progress, gamepad keyboard) | Adapted |
| Shop mirror | Rendered by the game's own reflection camera into a texture; in the headset it is one flat image, not a stereo mirror | To check |
| Microphone keeps working between levels; voice chat fixes | Photon Voice as in the game | As is |

## What changed in 0.5.0, and what this fork does about it

| In R.E.P.O. 0.5.0 | Effect | Fix |
|---|---|---|
| Unity 6000.3.17f1 instead of 2022.3.62f3 | The project has to be built with Unity 6 | `kit.json`: Unity 6000.3.17f1 (cf0352b38e81). Unity 6's built-in shader source comes from Unity's CDN without a pinned hash; the hash is logged |
| AssetRipper cannot read the PlayerSettings ("Read 944 but expected 948 for asset type 129") | No `ProjectSettings.asset`: the builder took the export for failed ("no project in the export folder"), and Unity would make default settings | The export counts as done with `ProjectVersion.txt` + `TagManager.asset`. `QuestBuild.RestoreGameSettings` restores what was read from `globalgamemanagers`: semiwork/REPO, **gamma** colour space, both input handlers (activeInputHandler 2), preloaded InputSystem_Actions, InputSystem.inputsettings and Localization Settings, .NET Framework API level |
| Newer packages | The game's code is compiled against them | Versions matched by comparing the game DLLs' types with each version's sources ([needle-mirror](https://github.com/needle-mirror)) and the small differences between versions; list and reasons in `scripts/package_swap.py` |
| TextMeshPro is part of uGUI 2.0 (Unity 6) | There is no separate TMP package | `Unity.TextMeshPro.dll` and `Unity.InternalAPIEngineBridge.004.dll` are replaced by the built-in uGUI 2.0.0; `patch_packages.py` finds `Button.cs` at its new path |
| Addressables 2.9.1 loads the binary `catalog.bin` | The `catalog.json` next to it is a stale leftover (no cosmetics, half the languages) | `BinaryStorageBuffer` decoder in `addressables_catalog.py`; `GameInstall.AddressablesCatalog` picks `catalog.bin` when `settings.json` names it |
| Addressables 2.x only reads binary catalogs | RepoXR's own Android catalog (`catalog_0.1.json`, Addressables 1.x) would not load | `ENABLE_JSON_CATALOG`: both catalogs are JSON |
| Cosmetics packed by label (`cosmetics_assets_cosmetics-arms`) | — | `AddressablesRestore`: one group per label |
| 712 addressable assets instead of 28 | `restore_guids.py`'s 712-way regex alternation ran for hours | One `guid: …` regex with a dictionary lookup |
| AssetRipper 2.0.0 writes WAVs with zero RIFF/data sizes | Unity 2022 read them anyway, Unity 6's FSBTool fails on all 3417 ("Failed decoding audio clip") | `fix_wav_headers.py` right after the export is copied |
| A platform layer: `SteamPlatform.Initialise` and lobbies call `SteamApps.CurrentBetaName` | SteamShim had none: an exception at startup and when creating a lobby | SteamShim: `SteamApps` (`null`, as Steam answers on the default branch), `SteamUserStats.IndicateAchievementProgress`, Steam's gamepad keyboard ("no keyboard", the game keeps its own) |
| No `MenuPageSavesRename` | The in-headset Steam login page was built from it | `MenuTextPage` is built from `MenuPagePopUpTextInput` (`MenuPageIndex.PopUpTextInput`) |
| `MetaManager.Start` no longer generates icons | — | `CosmeticsCloud.StartAfterSync` follows the new Start |
| Menus click through `InputKey.UIClick` instead of `Input.GetMouseButtonDown` | RepoXR's mouse patches in 5 menu methods match nothing: buttons would not click in VR | `KeyDown`/`KeyHold`/`KeyUp` answer UIClick with the VR pointer's trigger |
| The tumble-climb rotation moved from `GrabStateClimb` to `ClimbTargetUpdate` | The transpiler cut into the end of `GrabStateClimb`; IL2CPP refused it | The patch targets `ClimbTargetUpdate` and throws if it finds nothing |
| `PlayerLocalCamera.OnPhotonSerializeView` keeps `CameraAim.Instance` in a typed local | The patch that sends the VR camera instead of the aim stored `this` (a PlayerLocalCamera) into a CameraAim local; clang rejected IL2CPP's C++ | The local stays; only the two transform reads use the PlayerLocalCamera's transform |
| Unity 6 turned many engine externs into managed wrappers, `Camera.set_targetTexture` among them | The baker treated it as ordinary IL and baked RepoXR's patch ("Camera Main and Camera Overlay never get a target texture") into the game's copy of `UnityEngine.CoreModule`, which the Unity build replaces with its own. The game kept rendering into its 752×423 render texture: in the headset nothing cleared the eyes, the menu smeared and the world was black | `HarmonyBaker`: methods of `UnityEngine` and `UnityEngine.*Module` are hooked at their call sites like externs (13 in the game, 8 in RepoXR). `QuestBuilder.Cli check` fails when anything is baked into an engine module and warns for a package method that `patch_packages.py` does not carry |
| Gamepad support: menus switch to keyboard navigation on any navigate input and back to the pointer only when the mouse moves | No mouse in VR: once in navigation mode, pointing at a button would never select it | Patch 0010: `MenuManager.StateOpen` keeps the pointer mode while the VR rays exist |
| `SemiFunc.UIMouseHover` sizes the hover area as rect size × `lossyScale` (screen pixels) | On RepoXR's world-space menu canvas (scale 0.03) the hover area shrank to a speck in the button's corner: the pointer selected nothing | Patch 0011: the scale relative to the menu page |
| (Android, not 0.5.0) BepInEx's `UnityLogListener` writes through `UnityLogWriter` | None of RepoXR's own log lines reached logcat on the Quest | RepoXR.Standalone sends BepInEx log events to `Debug.Log` |
| The scene's EventSystem runs a `StandaloneInputModule` (0.4.4: `InputSystemUIInputModule`, which RepoXR disables) | XRI's rays find UI only through `XRUIInputModule` on the current EventSystem: triggers worked, every press found no UI (`ray on nothing`) | Patch 0012: one EventSystem, only `XRUIInputModule` enabled on it |
| XRI's UI raycast (`TryGetCurrentUIRaycastResult`) reports nothing on 0.5.0 / Unity 6, with the trigger, the rays and `XRUIInputModule` working | The pointer selected nothing | Patch 0014: the UI under the pointer found by hand (the ray against each world-space canvas with a `TrackedDeviceGraphicRaycaster`, the topmost raycast target); XRI's result wins when it has one |
| Menu pages are no longer at the canvas origin | RepoXR compared the pointer in canvas space with element positions in menu-page space: the hit landed on a button but nothing was selected | Patch 0015: the pointer in the element's menu page space |
| The first main menu blocks interaction and wraps its panels in input-less, raycast-less CanvasGroups until its intro animation brings them in (`MenuPageMain.IntroGroupUpdate`) | RepoXR skips the intro: the page stayed blocked, no button could be hovered or clicked, and XRI's UI raycast found nothing | Patch 0017: the groups removed and the page unblocked where RepoXR skips the intro |
| The settings page has six tabs (Gameplay, Graphics, Audio, Controls, Gamepad, Language) | RepoXR's VR Settings button at (126, 83) lay on top of *Language*: the port's settings could not be reached | Patch 0018: VR Settings below *Language*, *Back* below it |
| Unity 6's TextMeshPro (in uGUI 2.0) | The texts of RepoXR's asset bundle (built with Unity 2022) arrive without a usable font; TMP threw while the VR Settings button was created | Patch 0018: once the game's menu is up, the bundle's texts get the game's menu font |
| The main menu's left column moved under `LeftTransform/` | RepoXR.Standalone found no Settings button to copy: no Steam button | Both layouts; the button sits right of *Quit Game* |
| The toggle-grab release (`itemUnequipAutoHold`) moved out of `PhysGrabber.Update` into `GrabInputActiveGet` | RepoXR's `ForceHoldPatch` found no anchor and its `Advance(-2)` landed in `Update`'s `grabDisableTimer` countdown: the timer never reached 0 and **grabbing stayed disabled** (1.0.7-qc10/qc11 in the headset). Nothing failed: the transpiler does not check its match | Patch 0019: the patch targets `GrabInputActiveGet` and throws if it finds nothing. `HarmonyBaker` now records every CodeMatcher search that finds nothing, with its transpiler and target, and `QuestBuilder.Cli check` warns about them (on 0.5.0: this one, harmless loops of the mouse patches, and an optional debug text) |
| The end of object rotation moved into `PhysGrabber.ObjectTurningRelease`; `ForceGrabPhysObject` starts forced grabs from the camera | RepoXR rotates held objects relative to the hand: after rotating, an object jumped when the rotate button was let go | Patch 0020: both from the hand |
| Scene handoff: the next Main scene loads while the Reload scene is still the active scene, which is unloaded afterwards (`ReloadScene.Handoff*`) | The VR overlay canvas and RepoXR's other root objects, created on each scene load, landed in the Reload scene and went away with it. In the singleplayer lobby the VR HUD setup stopped: the game's HUD canvas stayed a giant flat screen around the player (the view looked mirrored), with no pause menu and no pointers | Patch 0024: the new root objects are moved into the loaded scene. Patch 0026: the Reload scene also has a camera tagged MainCamera, and `Camera.main` picked it; the head tracking went onto that camera while the new scene's camera kept RepoXR's counter-rotation, so the view turned opposite to the head. The setup now uses the loaded scene's own UI and camera, and the Reload camera is untagged. Patch 0028: RepoXR's trackers and UI controllers share their XR actions and each disables them when it goes away; the Reload camera's tracker went away after the new camera's had started and switched the head tracking off, so the view no longer followed the head. Disabled actions are enabled again before the next input update (confirmed on the headset with 1.0.7-qc21) |
| TextMeshPro fonts are dynamic: missing glyphs are rendered into the font's atlas at runtime | AssetRipper exports the atlases as PNG with default import settings; on Android Unity compressed them (ASTC), and glyphs written at runtime came out as stripes: the Steam name after logging in, the news text in the main menu | `scripts/fix_font_atlases.py` (project step): the atlases of every font asset with a population mode are imported uncompressed on Android, Alpha8 (color fonts RGBA32). Needs a full build |
| New `InputKey`s: `VehicleAccelerate`, `VehicleBrake`, `VehicleDriftLeft/Right`, `VehicleExit`, `VehicleGrab`, `PushPull`, `ExpressionWheel`, UI navigation | RepoXR's VR action map has none of them; looking one up threw an exception on every call (every frame while driving) and fell back to the keyboard binding | Patch 0019: looked up once; vehicle keys on the movement stick, `VehicleGrab` on Grab |
| `InputManager.VehicleInputAllowed` requires the game's own `Player` action map to be enabled | VR input comes from RepoXR's own `PlayerInput`; the snow bike and golf cart could ignore the stick | Patch 0019: in VR the other checks only (focus, text input, disabled input) |
| `InputKey.Confirm` → `UIClick` and other renames, new overloads | 16 RepoXR patch classes failed | `patches/repoxr/0009-repo-0.5.0.patch` |

## Performance

The game is CPU-bound on the Quest (about 18 ms CPU against 12 ms GPU per frame at 72 Hz on 0.4.4.3), so everything
here targets the CPU:

- **IL2CPP Master** (`QuestBuild.ConfigurePlayer`): fully optimized C++ with link-time optimization. The build takes a
  few minutes longer.
- **SUSTAINED_HIGH** (`unity-tools/Runtime/PerfXr.cs`): the OpenXR feature with `XR_EXT_performance_settings` is now
  added on every Android start and sets CPU and GPU to SUSTAINED_HIGH in `OnSessionBegin`. An empty file
  `perf-levels-off` in `/sdcard/Android/data/io.repoxr.quest/files/` turns it off. Logcat: `[RepoQuest] PerfXr: …`.
- **LevelCulling** (`unity-tools/Runtime/LevelCulling.cs`). R.E.P.O. builds its levels from modules at runtime, so
  nothing beyond the camera frustum is culled (no baked occlusion, no cull distances), and in the built-in pipeline
  every drawn renderer costs the render thread. Two seconds after `LevelGenerator.Generated`, the script collects the
  MeshRenderers and SkinnedMeshRenderers of the modules, the other children of `LevelParent` and `ItemParent`
  (never enemies or players), and checks up to 400 of them per frame by their current bounds:
  - small objects (diagonal under 1.5 m) beyond *Small Object Distance* (default 20 m) are hidden;
  - everything beyond *Room Distance* is hidden; 0 means the fog distance from `RenderSettings`, where the fog covers
    254/255 of the colour (lossless);
  - objects come back 1.5 m closer than they were hidden (hysteresis);
  - every fourth frame one root is rescanned (things spawn, break, get carried away).

  Only `Renderer.forceRenderingOff` is used: the GameObject stays active, so scripts, physics and Photon keep running
  and other players see no difference. The game sets that flag itself only on enemy parts; renderers it turned off are
  left alone, and only what the script hid is shown again. Any exception shows everything again and stops the script.
  Settings: *Settings → VR Settings → Rendering* (RepoXR config entries added by patch 0009, read once a second); an
  optional `culling.txt` (`small=`, `size=`, `far=`, `off`) overrides them for tests.

Kept from the original port: multiview with symmetric projection, no post-processing, per-pixel lamps in one pass,
graphics jobs (Legacy), incremental GC. Not applicable: Application SpaceWarp (URP only in Unity), foveated rendering
(GPU only). The single biggest gain without code is joining as a client of a PC host, which then simulates the AI
and physics.

## Checking the bake without Unity

IL2CPP reports bad IL only 40 minutes into a build, so the bake is checked beforehand with `tools/IlCheck`:
- `IlCheck stack <dll>...`: stack depth along every path of every method, which is what IL2CPP calls invalid IL;
- `IlCheck diff <original> <baked>`: what changed in each method. A transpiler target without changes is a patch that
  silently matched nothing; a change in the last few instructions after an `Advance(-N)` is suspicious;
- `IlCheck types <dll>... --search <dir>`: class-typed values stored into locals and fields and the `this` of calls,
  against their declared types. IL2CPP's C++ is typed, so clang rejects what the CLR would accept.

## Risks

- **OpenXR 1.14.3 and XRI 2.6.4** on Unity 6.3: RepoXR is built against these versions and cannot move without a
  RepoXR rebuild.
- **RepoXR's Android asset bundle** (`prebuilt/repoxr-android` in the kit) was built with Unity 2022.3. Unity 6 reads
  the data; if RepoXR's hands, pointers or menus show up invisible or pink, the bundle needs a Unity 6 rebuild
  (`scripts/build-repoxr-assets.sh` with RepoXR-Unity).
- The export has two Localization Settings assets (`Localization Settings.asset` and `_0`) that differ in
  PreloadBehavior and UseFallback; the first one is used, as in the original port.
