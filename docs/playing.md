# Playing R.E.P.O. in the headset

**English** · [Русский](playing.ru.md)

Everything after the APK is on the Quest: starting the game, controls, the VR settings, multiplayer, and what to
send when something goes wrong. Building and installing: [README](../README.md), [install.md](install.md).

> Everything below works on a Quest 3 (1.0.7-qc27). Defaults and setting names come from RepoXR's code and this
> fork's patches; what each 0.5.0 feature does in VR: [repo-0.5.0.md](repo-0.5.0.md#repo-050s-new-features-in-vr).

## Starting

In the headset: **Library → Unknown Sources → R.E.P.O.** The first start after an install takes longer (the game
unpacks RepoXR's files). Allow the microphone when asked, or voice chat stays silent.

The main menu floats in front of you. Point at it with either controller and press the **trigger** to click; the
hand you last clicked with keeps the long pointer.

## Controls

All buttons and hand gestures: **[controls.md](controls.md)**. The short version:

| | Left controller | Right controller |
|---|---|---|
| Stick | Move; click: chat; hold: expression wheel | Turn; up/down: push/pull a held object, scroll in menus; click: crouch |
| Trigger | Sprint | Grab beam |
| Grip | Rotate the held object (with the right stick) | Interact |
| Buttons | ≡ (menu button): menu · X: mute the microphone · Y: reset height | A: jump · B: tumble |

Vehicles: point the beam at the seat or handlebar and press the right trigger once to get on, drive with the left
stick, press the trigger again to get off ([controls.md](controls.md#vehicles)).

Map: hand to the belt (where the map hangs) or to the shoulder, hold grip. Flashlight on the head: other hand to the side of the head, grip. Inventory:
point a held item at a slot; take it out with the dominant hand in the slot and the trigger.

Bindings can be changed in the game: *Settings → Controls* lists RepoXR's VR actions.

## VR settings

*Settings → VR Settings*. RepoXR's own settings; they are saved on the headset and kept across new builds of the APK.

**Gameplay**

| Setting | Default | What it does |
|---|---|---|
| Head Bob | 0 % | Camera bob while walking, relative to the game's. The port turns it off by default (motion sickness) |
| Roomscale Crouch | on | Crouching in real life crouches in the game. Turn it off when playing seated |
| Dominant Hand | Right | The hand that grabs; Left swaps the controllers |
| Arms | Attached | Detached: your arms float freely instead of being attached to the body |
| Haptic Feedback | All | All / Reduced / Off |
| Reduced Aim Impact | off | Weaker forced looks (the ceiling eye and similar), helps with motion sickness |

**Input**

| Setting | Default | What it does |
|---|---|---|
| Turn Provider | Smooth | Smooth / Snap / Disabled; switches at once, no restart |
| Smooth Turn Speed Modifier, Analog Smooth Turn | 1×, on | Smooth turning speed, and whether it follows how far the stick is pushed |
| Snap Turn Size | 45° | Angle of a snap turn |
| Normalize Movement | off | Always full speed, however far the stick is pushed |
| Vehicle direction source | Hand | Whether vehicles go where your hand or your head points |

**UI**: HUD Height and HUD Secondary Height (when you look at it), Smooth Canvas Distance.

**Rendering** (the Quest-specific part of this port)

| Setting | Default | What it does |
|---|---|---|
| Camera Resolution | 100 % | Render scale. Lower is faster and blurrier |
| Pixel Lights | 1 | Lights per object at full quality. More is prettier and slower (the PC game uses 12) |
| Lamp Lighting | on | Lamps lit per pixel in one pass by the port's shaders: no seams, less work, but lamps cast no shadows |
| Other Flashlight Shadows | off | Other players' flashlights cast shadows: 7–10 ms of GPU per frame with a full lobby |
| Level Culling | on | Far parts of the level are not drawn: small objects beyond *Small Object Distance*, everything beyond *Room Distance*. Drawing only; objects keep working and multiplayer is unaffected |
| Small Object Distance | 20 m | Props, valuables and items under 1.5 m are not drawn beyond this |
| Room Distance | 0 m | Nothing is drawn beyond this; 0 = as far as the fog lets you see (no visible difference). Lower values hide far rooms for more speed |
| Post Processing | off | The game's color grading, vignette, grain. Off is brighter and saves about 5 ms of GPU |
| Render Mode | Single Pass | Both eyes in one pass. *Multipass* draws them one after the other: about 25 % slower, but the shop mirror shows. Restart the game after changing it |
| Shop Mirror | on | The mirror next to the cosmetic machine (hidden anyway with Single Pass) |
| FPS Counter | off | Frame rate low in the left of your view: FPS, average and slowest frame of the last half second (CPU and GPU times when the headset reports them). Green from 68 FPS, yellow from 50, red below |

The game's own settings pages still apply where they make sense. R.E.P.O. 0.5.0 added **Item Unequip Auto Hold**
(*Settings → Gameplay*, on by default): an item you take out of an inventory slot stays on the beam after you let go
of the trigger, until you press it again. Turn it off to have it fall as soon as you let go.

## The shop mirror

R.E.P.O. 0.5.0 has a mirror next to the cosmetic machine in the shop. On the Quest it is **hidden by default**, on
purpose. The Quest draws both eyes in one pass (*single-pass*), and the game's mirror has one reflection picture; a
mirror needs a different picture for each eye, so in single-pass it would look wrong in at least one eye. Drawing the
eyes one after the other (*multi-pass*) lets the port render a reflection for each eye, and then the mirror works, as
on PC, but the whole game then costs a lot more: the processor submits the scene once per eye, and the frame rate drops noticeably.

To try it anyway, set *VR Settings → Rendering → Render Mode* to **Multipass** and restart the game (or
`SinglePassRendering = false` in `RepoXR/config/io.daxcess.repoxr.cfg` on the headset); *Shop Mirror* in the same page
turns the mirror off again.

## Playing seated

Sit the way you will play and press **Y**: your current head height becomes standing height. Turn off **Roomscale
Crouch**, or looking down counts as crouching.

## Multiplayer

Singleplayer works offline. For online play, log in to Steam from the **Steam** button in the main menu, next to *Quit
Game*: your account name (not the profile name), the password, then Steam Guard (approve the sign-in in the Steam app,
or type its code or an emailed one). RepoXR's keyboard appears under the menu for typing. The game switches to the
account without a restart.

> 0.5.0 moved the main menu's buttons; the Steam button is there again since 1.0.7-qc4.

Once logged in, the headset uses Steam directly through [SteamKit2](https://github.com/SteamRE/SteamKit), an unofficial Steam client: Steam's
terms do not allow third-party clients, and the risk to the account is small but real.

The game is CPU-bound on the Quest. The best experience is as a **client of a PC host**: the host simulates the
enemies and physics.

## Files on the headset

`/sdcard/Android/data/io.repoxr.quest/files/` (reachable with `adb`; Android deletes it when the game is
uninstalled, see [install.md](install.md#reinstall-and-keep-the-data) to keep it):

| File | What it is |
|---|---|
| `RepoXR/config/io.daxcess.repoxr.cfg` | The VR settings above |
| `perf-levels-off` (empty) | Leave the CPU/GPU levels to the system instead of SUSTAINED_HIGH |
| `culling.txt` | Overrides Level Culling for tests: lines `small=20`, `size=1.5`, `far=0`, or `off` |

## Known issues

Everything works: tested on PC, and the Quest builds the same code. Good to know:

- One small issue: **the language page** (*Settings → Language*) shows only Text to Speech in VR, because the language buttons land outside the menu. The fix is ready and comes with the next build.

- The shop mirror is hidden by default, on purpose: see [The shop mirror](#the-shop-mirror).
- Whip: the fling works only once the whip has caught something. Sensitivity: VR Settings → Input → *Whip Sideways /
  Crack Sensitivity*.

## When something is wrong

Send these with your report (adb is in Unity's Android support, see [install.md](install.md#2-find-adb)):

1. **The game's log.** The headset's log buffer is small, so record it while the game starts:
   ```bash
   adb logcat -c && adb logcat -s Unity AndroidRuntime CRASH > logcat-unity.txt
   ```
   Start the game, reproduce the problem, then stop with Ctrl+C.
2. **A snapshot of the scene** (cameras, canvases, render textures), with the game running and the headset on:
   ```bash
   adb shell touch /sdcard/Android/data/io.repoxr.quest/files/diag-request
   ```
   ```bash
   adb pull /sdcard/Android/data/io.repoxr.quest/files/diag diag
   ```
3. **A video** recorded in the headset (Meta button → camera → Record):
   ```bash
   adb pull /sdcard/Oculus/VideoShots videos
   ```
