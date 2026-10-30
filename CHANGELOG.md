# Changelog

**English** · [Русский](CHANGELOG.ru.md)

Releases of this fork. Each release is a kit (`kit` branch) plus the matching code on `repo-0.5.0`; the build scripts
download the kit of their version. The original project's history is in
[Dobutsu/repo-quest-vr](https://github.com/Dobutsu/repo-quest-vr/releases).

## Unreleased

Kits 1.0.7-qc3 to qc24 are built and being tested on the headset; they are not on the `kit` branch yet.

- **1.0.7-qc24: the shop mirror, toggles** (RepoXR patch 0031, the same code as the PC fork's alpha 5, tested there).
  The shop mirror's reflection camera rendered as a stereo camera and the eye matrices replaced its reflected view: it
  now renders mono, once for each eye. On the Quest the mirror is hidden by default: with single-pass rendering both
  eyes would share one reflection (it works with `SinglePassRendering = false`, at a frame rate cost);
  *VR Settings → Rendering → Shop Mirror* turns it off. RepoXR's own toggles show the selected option again. A
  code-only build is enough over qc23.

- **1.0.7-qc23: settings menus and controller icons** (RepoXR patch 0030, the same code as the PC fork's alpha 4,
  tested there). RepoXR's controller icon sprite asset was made with Unity 2022's TextMeshPro; Unity 6's reads it
  without glyphs and material, so every icon was a `?` or nothing: they are rebuilt when the bundle loads. 0.5.0 moved
  the text tags (`[move]`, `[grab]` …) to `InputGlyphs`, and the tutorial showed `[move]`: they are read from there.
  The toggles' selection box compared world positions (flipped on a menu in 3D) and RepoXR's toggles kept placeholder
  labels; the *VR Settings* button no longer lands on *Back*. A code-only build is enough over qc22.

- **1.0.7-qc22: the whip, level → shop, the news popup** (RepoXR patch 0029, the same code as the PC fork's alpha 3,
  tested there). The whip's crack and fling are mouse gestures in 0.5.0: while you hold it they now read how fast your
  hand turns, and the camera aim targets the game forces expire again (RepoXR skipped their timer, and one left on for
  good switched the whip's gestures off). In the scene handoff the old VR loading screen cleared the new one's
  reference, and level → shop hung on the result screen. The main menu's news popup grows from nothing; its texts are
  built again once it has grown (its words were solid bars). Also from the PC fork: `ChatConfirm` sends chat messages
  again, no gamepad grab cursor drift in VR, VR Settings → Input → *Whip Sideways/Crack Sensitivity*. Multiplayer works
  on the Quest (reported by the tester). A code-only build is enough over qc21.

- **The first build on the headset showed a black, smearing world and a menu that did not click.** Unity 6 made
  `Camera.set_targetTexture` a managed wrapper, so the baker put RepoXR's patch into the game's copy of
  `UnityEngine.CoreModule`, which the Unity build replaces: the main camera kept rendering into the game's render
  texture and nothing reached the eyes. The baker now hooks every `UnityEngine.*Module` method at its call sites;
  `QuestBuilder.Cli check` fails on IL baked into an engine module. Details: [`docs/repo-0.5.0.md`](docs/repo-0.5.0.md).
- RepoXR patch 0010: menus stay in pointer mode in VR (0.5.0's gamepad support otherwise switches them to keyboard
  navigation for good); glyph texts no longer throw before `InputManager` starts; one log line per trigger press in a
  menu (`[UI] trigger ...`) to diagnose clicks.
- **Menus did not respond to the pointer** (first headset test of 1.0.7-qc3; the world now renders). Two causes:
  0.5.0 sizes a button's hover area as rect size × `lossyScale`, which on RepoXR's world-space menu canvas (scale 0.03)
  shrank it to a speck in the button's corner: RepoXR patch 0011 takes the scale relative to the menu page. And none of
  RepoXR's own log lines ever reached logcat on Android (BepInEx's `UnityLogListener` writes through `UnityLogWriter`),
  which hid the click diagnostics: RepoXR.Standalone now logs them with `Debug.Log`. Patch 0011 also reports the Input
  System's devices and the UI press bindings for a few seconds after the menu opens (`[UI] input devices: ...`).
- **The pointer still hit nothing in 1.0.7-qc4** — the log now shows it: triggers and controllers work (`UI click
  True`), but every press says `ray on nothing`. The rays find UI only through XRI's `XRUIInputModule`, which must be
  the running module of the current EventSystem; 0.5.0's scene EventSystem carries a `StandaloneInputModule`. Patch
  0012 keeps one EventSystem with only the `XRUIInputModule` enabled, and logs what it changed (`[UI] input module:
  ...`).
- 1.0.7-qc5 changed nothing in the headset: the current module was already `XRUIInputModule`, and presses still find
  no UI. Patch 0013 extends the rays' reach to 100 m (0.5.0 puts the menu canvas 20–25 m from the camera; XRI's default
  is 30 m) and logs a probe on each press: the interactor's own 3D/UI hits, all event systems and UI modules, where the
  ray meets the menu canvas, the raycast targets at that point, masks, and colliders on the ray.
- **1.0.7-qc6**: still `ray on nothing`; the probe itself threw (so its lines are missing), but the log shows that
  before 0012 the scene's `StandaloneInputModule` was indeed running. As XRI's UI raycast keeps reporting nothing while
  the trigger, the rays and the module work, patch 0014 finds the UI under the pointer by hand: the ray against every
  world-space canvas with a `TrackedDeviceGraphicRaycaster`, the topmost raycast target under the point. The menus'
  hover and click use it when XRI has no result; the trigger log says which one hit (`(xri)` / `(manual)`).
- **1.0.7-qc7**: the pointer finds the buttons now (`ray on ButtonText (manual)`), but the menu still selects nothing
  (`menu target` empty). RepoXR hands the game element positions in the menu page's space and the pointer in the
  canvas's space; that matched while 0.4.4's pages sat at the canvas origin. Patch 0015 gives the pointer in the
  element's menu page space too, and logs the hover geometry on each press (`[UI] hover ...`).
- **1.0.7-qc8**: the log shows the pointer inside the button's rectangle in the same space (e.g. *Quit game* at
  (50, 22) size 90×36, pointer (78, 51)) and the menu page at the canvas origin, yet nothing is selected: the geometry
  is right, so something before it in the game's hover code says no. Patch 0016 logs `SemiFunc.UIMouseHover`'s answer
  and the page's interactability, state and priority, and every page's state, on each press over a button.
- **The menu cause, found with 1.0.7-qc9**: every press over a button logged `page interactable False, blocked True,
  selectable False`. 0.5.0's first main menu blocks interaction (`MenuPage.interactionBlocked`) and wraps its left and
  right panels in CanvasGroups with `interactable` and `blocksRaycasts` off, and lifts both only when its intro
  animation has slid each panel within 300 units of its place (`MenuPageMain.IntroGroupUpdate`). RepoXR skips that
  intro, so the page stayed blocked, and the CanvasGroups also kept XRI's UI raycast from finding anything. Patch 0017
  removes the groups and unblocks the page where RepoXR skips the intro.
- **1.0.7-qc10 in the headset: the menus work** (main menu, pause menu, settings; XRI's own UI raycast finds the
  buttons now). Still to fix: the VR Settings with this port's options were missing, and grabbing does not work.
  0.5.0's settings page has six tabs, and RepoXR put its VR Settings button at (126, 83), right on the new *Language*
  tab; patch 0018 puts it below *Language* and *Back* below it. RepoXR's own UI comes from an asset bundle built with
  Unity 2022's TextMeshPro, whose texts arrive without a usable font in Unity 6 (TMP threw while the VR Settings
  button was created): they get the game's menu font. And a report of the VR input the grabber sees (`[Grab] ...`).
- **PC (RepoXR fork, same patches): grabbing and the tumble climb checked.** On Windows with SteamVR the grab beam,
  forced grabs, the release after rotating and the reworked tumble climb (`0009`, pulled where the hand points) work.
  How grabbing was fixed for 0.5.0 is now described on the front page and in the fork's
  [grabbing table](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/docs/repo-0.5.0.md#grabbing-what-broke-and-how-it-was-fixed).
  The news popup's text boxes show on PC too; a first fix (keeping the popup's scale z at 1) did not help, still open.
- **1.0.7-qc21: the head tracking switched off after a scene handoff.** RepoXR's camera and hand trackers
  (`TrackedPoseDriver`) and its UI controllers (XRI) share the same XR actions, and each of them disables those actions
  when it is disabled or destroyed. Without a handoff (the tutorial) the old scene goes away before the new one starts,
  and the new trackers enable the actions again. In 0.5.0's handoff the new Main scene starts first and the Reload
  scene goes away after it: the tracker on the Reload scene's camera switched the head actions off under the new
  camera, so in the lobby and every level after it the view stopped following the head. Patch 0028 enables any of
  RepoXR's XR actions again before the next input update when something disables them (`[Input] ... was disabled;
  enabling it again`). Confirmed on the headset: the lobby and the levels follow the head again, and the pointer
  works. The Steam name now shows correctly after qc18's font atlas fix; the news panel at the bottom right of the
  main menu still shows boxes (open).
- **1.0.7-qc20: diagnostics for the reversed view.** In qc19 the scene setup picks the right camera (`[Scene] Main:
  VR camera Camera Main (Main)`), the HUD and the pause menu set up without errors, and the view still turns opposite
  to the head in the lobby and the levels after it. Patch 0027 logs what the camera is doing (`[Camera] ...`): the
  head pose, the rotations along the camera's parents, its components, every camera and every loaded scene.
- **1.0.7-qc19: the view turned the wrong way in levels.** With qc17 the lobby and the levels after it still turned
  the view opposite to the head (look down, the camera goes up; look left, it goes right). The tutorial was fine. The
  Reload scene, which 0.5.0 keeps loaded while the next level's Main scene starts, has its own camera tagged
  MainCamera, and RepoXR's per-scene setup took `Camera.main`. That camera got the head tracking, while the new scene's
  camera kept only RepoXR's counter-rotation. Patch 0026 sets up the loaded scene's own UI and camera, and untags the
  Reload camera so that RepoXR's other `Camera.main` users (camera position, loading UI, pause menu, crosshair) find the
  right camera too.
- **1.0.7-qc18: text drawn at runtime (needs a full build, not `CODE_ONLY`).** After logging in to Steam, the account
  name came out as stripes, like the news text in the main menu. R.E.P.O.'s TextMeshPro fonts are dynamic: they draw
  missing glyphs into their atlas while the game runs. The exported atlases were compressed on Android (ASTC), and
  glyphs drawn into a compressed atlas break. `scripts/fix_font_atlases.py` imports the atlases of every font asset with
  a population mode uncompressed on Android: Alpha8, or RGBA32 for color fonts. RepoXR's own texts no longer keep
  TMP's stand-in font once the game's menu font is there (patch 0025).
- **1.0.7-qc17: the singleplayer lobby, the real cause.** qc16 fixed the fonts (`[Fonts] 129 texts ...`), but the
  lobby looked the same. The log now shows `GameHud.SetupOverlayCanvas` failing because there was no "VR Overlay
  Canvas". 0.5.0 hands scenes over: the next Main scene loads while the Reload scene is still the active scene. RepoXR
  created its per-scene root objects in that Reload scene, and they were unloaded with it. Without the overlay canvas
  the VR HUD setup stopped, and the game's HUD canvas stayed a giant flat screen around the player: that is the
  "mirrored" view, with no pause menu and no pointers. Patch 0024 moves those objects into the loaded scene and logs
  every scene load (`[Scene] ...`).
- **1.0.7-qc16: the singleplayer lobby in VR.** In the lobby the view was mirrored on every axis, there were no
  pointers, the trigger did nothing, the chat sat at the bottom of the view, and the crosshair wandered across the
  screen. The log shows TextMeshPro throwing while RepoXR instantiated its prefabs (the VR tumble UI, the rig). The
  VR HUD setup stopped halfway and then failed again on every frame. The cause is patch 0018's font fix for the
  bundle's texts, which never ran: it only accepted fonts with an atlas texture, and Unity 6's dynamic fonts have none
  until they draw a glyph (`[Fonts] no game menu font found yet` in every log since 1.0.7-qc11). Patch 0023 accepts
  any font with a working material (the menu's, TMP's default, or any loaded one). It applies the font before each
  scene's VR setup, and a failed HUD setup no longer throws on every frame.
- **1.0.7-qc15: the Steam login reaches its text page.** The qc14 log showed the cause: `Steam login: popup answer
  2` came in the same frame as the press on the Steam button. In 0.5.0 a popup opens on top of the current page without
  becoming the current page. RepoXR.Standalone attached its popup tracking to the current page, which was the main
  menu, so the popup counted as already gone and the login ended before LOG IN was pressed. The popups are now found
  through the instance the game's popup sets when it opens (`MenuPageTwoOptions.instance`, `MenuPagePopUp.instance`).
- **1.0.7-qc14: the Steam login opens its text page; the FPS counter shows.** In qc12 the login popup's LOG IN led
  back to the main menu: the account page never showed. It was opened as a page of its own (`PageOpenOnTop`). It now
  opens the way the game opens its text prompts (`MenuManager.PagePopUpTextInput`), and the login logs each step
  (`[RepoXR.Standalone] Steam login ...`, `text page ...`). The text page also took any trigger press as "confirm",
  including presses on the keyboard's keys, which sent the field after its first letter. Now only its buttons and
  the keyboard's Enter confirm. The FPS counter counted in qc12, but its panel stayed hidden: `Camera.main` was null in
  the main menu. It now follows the camera RepoXR renders with (`CameraUtils.MainCamera`, patch 0022).
- **1.0.7-qc13: guns aim from the hand** (patch 0020). 0.5.0 turns a held gun to point along the line from the
  camera through the grab point, and RepoXR holds objects relative to the hand. As a result the gun pointed off to the
  side whenever your head and hand did. The aim, the end of object rotation (`ObjectTurningRelease`) and forced grabs
  (`ForceGrabPhysObject`) are now measured from the hand. Before, a rotated object jumped when the rotate button was
  let go. [Weapons](docs/controls.md#weapons): fire with the right grip. The whip's crack and fling gestures are not
  adapted to VR yet.
  The FPS counter (off by default, *VR Settings → Rendering → FPS Counter*) now follows RepoXR's VR camera rather than
  whatever `Camera.main` is. It also logs what it follows (`[FPS] ...`), because in qc12 it did not show up (patch 0021).
- **1.0.7-qc12: grabbing, vehicles, menu button, FPS counter** (patch 0019). Confirmed on the headset: grabbing and
  the menu on the ≡ button work. On qc10 walking and the buttons worked
  but nothing could be grabbed. 0.5.0 moved the toggle-grab release out of `PhysGrabber.Update` into
  `GrabInputActiveGet`; RepoXR's `ForceHoldPatch` kept looking in `Update`, found nothing, and its `Advance(-2)` put
  its call into the grab cooldown countdown instead, which then never reached 0. The patch now targets
  `GrabInputActiveGet` and fails loudly if it finds nothing.
  - Vehicles (scooter, snow bike, golf cart): 0.5.0's new vehicle keys have no VR actions. Accelerate, brake and drift
    now follow the left stick (the snow bike's throttle and steering are analog). Holding on to a vehicle uses the grab
    trigger as a toggle, like the game's default: one press to get on, one to get off. Vehicles also no longer depend on
    the game's own action map, which VR input does not use. [How to drive](docs/controls.md#vehicles).
  - Game keys without a VR action used to throw an exception on every call, every frame while driving. They are now
    looked up once.
  - The pause menu is on the left controller's menu button (≡). X, which it frees, mutes the microphone (`ToggleMute`).
    Bindings changed in *Settings → Controls* still win.
  - *VR Settings → Rendering → FPS Counter*: FPS, the average and the slowest frame, low in the left of the view.
  - `HarmonyBaker` records every transpiler search that finds nothing, with the transpiler and the method it patches.
    `QuestBuilder.Cli check` warns about each one. That is how the grab bug shows up without a headset.
- **Code-only builds** (`CODE_ONLY=1` / `-CodeOnly`, `QuestBuilder.Cli build --scripts-only`): when only the code
  changed, Unity rebuilds the scripts, IL2CPP and Gradle into the last APK and reuses its packed game data and
  Addressables bundles. In the last full build, packing the data took 23 of 34 minutes (shaders all came from the
  cache: 0 variants compiled); IL2CPP and Gradle took about 8. Without an earlier build Unity falls back to a full
  one.
  It worked on the first real build (qc4): Unity skipped the data packing and went straight to IL2CPP and Gradle.
- **Playing in the headset**: [`docs/playing.md`](docs/playing.md) — starting, controls in short, every VR setting
  with its default, playing seated, multiplayer and the Steam login, files on the headset, and what to send when
  something is wrong (log, scene snapshot, video).
- **The Steam button is back in the main menu**: 0.5.0 moved the menu's buttons under `LeftTransform/`, and
  RepoXR.Standalone did not find the Settings button it copies; now it finds both layouts and sits right of *Quit Game*.
- **What each 0.5.0 feature does in VR**: a table with statuses (adapted / as is / to check) in
  [`docs/repo-0.5.0.md`](docs/repo-0.5.0.md#repo-050s-new-features-in-vr).
- **Installing the APK by hand**: [`docs/install.md`](docs/install.md) / [`docs/install.ru.md`](docs/install.ru.md) —
  connecting the headset, finding adb, every common `adb install` error, reinstalling without losing saves. The build
  scripts point to it when the install fails, and wake the headset before installing (a sleeping Quest holds the
  install until it wakes).
- Removed 17 pip wheels committed by mistake to the repository root; `*.whl` is ignored.
- `release-fork.sh` prints the tested-game step only with `--game`.
- The changelog is in Russian too ([CHANGELOG.ru.md](CHANGELOG.ru.md)); `release-fork.sh` requires the version's
  section in both files and puts both texts into the release notes.

## 1.0.7-qc2

Tooling for game updates; the APK is built exactly as with 1.0.7-qc1.

- **`QuestBuilder.Cli check`**: what a game update broke, in minutes and without Unity. It bakes RepoXR's patches
  into the new game code and reports failed patch classes, invalid IL, class-type mismatches (what clang rejects),
  patched methods that did not change or changed only at their end, references between the game, RepoXR,
  RepoXR.Standalone and SteamShim that no longer resolve, and changes in the Unity version, Addressables, package DLLs
  and the set of DLLs (`scripts/check_game.py` against `scripts/game_fingerprints.json`).
- `scripts/build-mac.sh` and `scripts/build-windows.ps1` run the check by themselves when the game version is not
  among the kit's tested ones, and stop on failures (`FORCE=1` / `-Force` builds anyway).
- `scripts/repoxr-patch.sh`: a new RepoXR patch for a game version (`start`, `save`).
- `scripts/release-fork.sh`: a release in one command (kit, versions in the build scripts, tag, kit branch, GitHub
  release).
- `tools/IlCheck refs`: unresolved references; IlCheck runs inside the builder as the `il-check` tool.
- Docs: [`docs/updating.md`](docs/updating.md) — what to do when R.E.P.O. updates.

## 1.0.7-qc1

First port to **R.E.P.O. 0.5.0** (Unity 6000.3.17f1), on top of repo-quest-vr 1.0.7. Testing build: the pipeline
builds the APK; testing on a Quest 3 is in progress.

- RepoXR patch 0009 for 0.5.0's code: renamed and moved members, new overloads, the text prompt page, climbing,
  menu clicks through `InputKey.UIClick`, the camera sent over the network.
- Builder: Unity 6000.3.17f1, the export without PlayerSettings, the Addressables 2.x binary catalog, WAV headers.
- Unity packages matched to 0.5.0 (Input System 1.19.0, uGUI 2.0.0 with TextMeshPro, Localization 1.5.12,
  Addressables 2.9.1, PostProcessing 3.5.4 and others).
- SteamShim: the Steam APIs 0.5.0 calls; the in-headset Steam login on 0.5.0's text prompt page.
- Performance: level culling (settings in *VR Settings → Rendering*), IL2CPP Master, CPU/GPU at SUSTAINED_HIGH.
- Build scripts for macOS and Windows; docs in English and Russian.
