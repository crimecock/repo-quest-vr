# Porting to R.E.P.O. 0.5.0 (Unity 6000.3)

**English** · [Русский](repo-0.5.0.ru.md)

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

## What changed in 0.5.0, and what this fork does about it

| In R.E.P.O. 0.5.0 | Effect | Fix |
|---|---|---|
| Unity 6000.3.17f1 instead of 2022.3.62f3 | The project has to be built with Unity 6 | `kit.json`: Unity 6000.3.17f1 (cf0352b38e81). Unity 6's built-in shader source comes from Unity's CDN without a pinned hash; the hash is logged |
| AssetRipper exports into `export/REPO/ExportedProject` | "no project in the export folder" | `ExportStep` moves it up |
| AssetRipper cannot read the PlayerSettings ("Read 944 but expected 948 for asset type 129") | No `ProjectSettings.asset`; Unity makes default settings | The export counts as done with `ProjectVersion.txt` + `TagManager.asset`. `QuestBuild.RestoreGameSettings` restores what was read from `globalgamemanagers`: semiwork/REPO, **gamma** colour space, both input handlers (activeInputHandler 2), preloaded InputSystem_Actions, InputSystem.inputsettings and Localization Settings, .NET Framework API level |
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
  silently matched nothing; a change in the last few instructions after an `Advance(-N)` is suspicious.

## Risks

- **OpenXR 1.14.3 and XRI 2.6.4** on Unity 6.3: RepoXR is built against these versions and cannot move without a
  RepoXR rebuild.
- **RepoXR's Android asset bundle** (`prebuilt/repoxr-android` in the kit) was built with Unity 2022.3. Unity 6 reads
  the data; if RepoXR's hands, pointers or menus show up invisible or pink, the bundle needs a Unity 6 rebuild
  (`scripts/build-repoxr-assets.sh` with RepoXR-Unity).
- The export has two Localization Settings assets (`Localization Settings.asset` and `_0`) that differ in
  PreloadBehavior and UseFallback; the first one is used, as in the original port.
