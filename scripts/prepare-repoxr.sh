#!/usr/bin/env bash
# RepoXR as the Quest build uses it: external/RepoXR (v1.2.3, left untouched) plus patches/repoxr/*.patch, built in
# work/repoxr-src.
#   scripts/prepare-repoxr.sh   -> work/repoxr-src/bin/Release/netstandard2.1/RepoXR.dll
# Patches (in order):
#   0001-head-bob-setting  "Head Bob" slider in RepoXR's Gameplay settings (0-100%, default 0% = off; upstream is 25%)
#   0002-pixel-lights-setting  "Pixel Lights" slider in Rendering (per-object pixel light limit, default 1)
#   0003-multiview-by-default  single-pass instanced stereo on (Post Processing is fixed for it, patch_packages.py)
#   0004-post-processing-setting  "Post Processing" switch (off by default: brighter, ~5 ms GPU); the main camera's
#                                 volume-less post stack is always off
#   0005-other-flashlight-shadows  other players' flashlights cast no shadows unless switched on (7-10 ms GPU with six)
#   0006-lamp-lighting  lamps lit per pixel in one pass by the Quest shaders (RepoQuestLamps.cginc), no Unity light passes
#   0007-lamp-lighting-arms-and-previews  the VR arms use the game's Hurtable shader (the bundle's copy has no lamps);
#                                         the menus' deferred player previews render forward, where the lamps are
#   0009-repo-0.5.0  R.E.P.O. 0.5.0 (Unity 6.3) moved and renamed what RepoXR patches: new overloads
#                    (CameraShake.Shake, CameraAim.AimTargetSoftSet, InputToggleGet, UIMouseGetLocalPosition...), one text
#                    prompt page, the password field as a MenuTextInput, KeyType, vehicle/snow bike heading, glyph tags,
#                    climb rotation (ClimbTargetUpdate), menu clicks as InputKey.UIClick (VR ray trigger)
#   0008-focus-sphere-hidden-when-faded  the focus sphere's renderer is off while it is fully faded: its GrabPass copied
#                                        the whole frame every frame (Pico 4 Ultra: 85 -> 14 FPS in the levels)
#   0010-vr-menus-0.5.0  0.5.0's menus stay in pointer mode in VR (its gamepad support switched them to keyboard
#                        navigation for good, as no mouse ever moves); glyph texts refreshed before InputManager starts;
#                        one log line per trigger press in a menu ("[UI] trigger ...")
#   0011-menu-hover-scale-0.5.0  0.5.0 sizes a button's hover area by its lossyScale (screen pixels); on the world-space
#                                menu canvas (scale 0.03) that shrank it to a speck: the scale is taken relative to the
#                                menu page. Plus a report of the Input System's devices and the UI press bindings
#   0012-xr-ui-input-module  the rays see UI only through XRI's XRUIInputModule on the current EventSystem; 0.5.0's
#                            scene EventSystem runs a StandaloneInputModule: one EventSystem, only XRUIInputModule on
#   0013-ui-ray-probe  the rays reach 100 m (0.5.0's menu canvas is 20-25 m from the camera, XRI's default is 30); on each
#                      trigger press in a menu a probe logs the interactor's hits, the event systems, where the ray meets
#                      the menu canvas, the raycast targets there, masks and colliders ("[UI] probe ...")
#   0014-ui-pointer-hit  XRI's UI raycast reports nothing on 0.5.0/Unity 6 although trigger, rays and module work: the
#                        pointer is intersected with the world-space canvases by hand (topmost raycast target), used by
#                        the menus' hover and click; XRI's own result still wins when it has one
#   0015-pointer-in-menu-page-space  the pointer is given in the element's menu page space, like the element positions
#                                    (upstream used the canvas; 0.5.0's pages are not at its origin); hover report
#   0016-hover-check-report  on a press over a menu button: SemiFunc.UIMouseHover's answer, the page's interactability,
#                            state and priority against the highest open one, every page's state ("[UI] hover check")
#   0017-main-menu-interaction  0.5.0's first main menu blocks interaction and wraps its panels in CanvasGroups that take
#                               no input and block no raycasts until its intro slides them in; RepoXR skips the intro,
#                               so DisableMainMenuAnimation removes the groups and unblocks the page
#   0018-vr-settings-fonts-grab-report  the VR Settings button sat on 0.5.0's new Language tab: it goes below it, Back
#                                       below that; the bundle's texts (Unity 2022 TMP) get the game's menu font; a
#                                       report of the VR input the grabber sees ("[Grab] ...")
#   0019-grab-vehicles-menu-button-fps  ForceHoldPatch follows the toggle-grab release into 0.5.0's
#                                       PhysGrabber.GrabInputActiveGet (matched against Update it broke the grab cooldown
#                                       and grabbing stayed disabled); vehicle keys on the movement stick, VehicleGrab
#                                       on Grab (toggle by default, like the game), vehicle input without the game's own
#                                       action map; missing VR actions looked up once instead of throwing every call;
#                                       menu on the left menu button, X mutes; "FPS Counter" in Rendering
#   0020-guns-and-grab-release-from-hand  0.5.0's gun aim (ItemGun.AimTargetUpdate), the end of object rotation
#                                         (ObjectTurningRelease) and forced grabs (ForceGrabPhysObject) measure from the
#                                         hand like the rest of RepoXR's grab, not from the camera
#   0021-fps-counter-camera  the FPS counter follows RepoXR's VR camera (Camera.main can be another camera) and logs
#                            what it follows ("[FPS] ...")
#   0022-fps-counter-main-camera  ... namely CameraUtils.MainCamera, the camera RepoXR renders the headset with in the
#                                 levels and the main menu (Camera.main was null in the main menu)
#   0023-bundle-fonts-before-scene-setup  the bundle's texts get any working font (Unity 6's dynamic fonts have no atlas
#                                         until used, so 0018 never found one), before each scene's VR setup; a
#                                         failed HUD setup no longer throws every frame
#   0024-scene-handoff-roots  0.5.0 loads the next Main scene while the Reload scene is still active: the objects the
#                             per-scene setup creates at the root (VR overlay canvas, network system...) are moved into
#                             the loaded scene instead of going away with the Reload scene; "[Scene] ..." log lines
#   0025-bundle-fonts-menu-font  a stand-in font applied at a scene load (TMP's LiberationSans) is replaced by the game's
#                                menu font once the menu exists
#   0026-scene-handoff-camera  the per-scene VR setup uses the loaded scene's own UI and camera, and the Reload scene's
#                              camera stops being tagged MainCamera (it took the head tracking: the view turned
#                              opposite to the head in every level reached through a handoff)
#   0027-camera-report  diagnostics: head pose, the camera's parent chain, its components, all cameras and loaded scenes,
#                       every 2 s for the first 40 s of a scene ("[Camera] ...")
#   0028-handoff-shared-actions  RepoXR's trackers and UI controllers share their XR actions and each one disables them
#                                when it goes away; in 0.5.0's handoff the Reload scene's camera tracker went away after
#                                the new camera's had started and switched the head tracking off (the view stopped
#                                following the head in the lobby and the levels). Disabled actions are enabled again
#   0029-whip-result-screen-aim-news-popup  the PC fork's alpha 3 (same code): the whip's crack and fling read the
#                                hand's angular velocity (VR Settings -> Input -> Whip Sideways/Crack Sensitivity); the
#                                camera aim targets the game forces expire again (RepoXR skips CameraAim.Update; one left
#                                on for good kept the whip's gestures off); the old VR loading UI no longer clears the
#                                new one's instance (level -> shop hung on the result screen); the news popup's texts
#                                are built again once it has grown (solid bars); ChatConfirm, no gamepad grab cursor
#                                drift, PC defaults behind Plugin.IsQuest, translations optional
#   0030-settings-menus-controller-icons-text-tags  the PC fork's alpha 4 (same code): RepoXR's icon sprite asset (made
#                                with Unity 2022's TextMeshPro) gets its glyphs and a material back, so the controller
#                                icons show instead of '?'; text tags ([move], ...) come from 0.5.0's InputGlyphs;
#                                toggles compare their buttons in canvas space and take their labels from the buttons;
#                                the VR Settings button no longer lands on Back
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/work/repoxr-src"
dotnet="${DOTNET:-$HOME/.dotnet/dotnet}"

# Fresh sources on every run; bin/ and obj/ stay for incremental builds
mkdir -p "$src"
rsync -a --delete --exclude .git --exclude bin --exclude obj "$root/external/RepoXR/" "$src/"
for patch in "$root"/patches/repoxr/*.patch; do
    patch -p1 --forward --silent -d "$src" < "$patch" || { echo "patch failed: $(basename "$patch")" >&2; exit 1; }
    echo "applied $(basename "$patch")"
done

"$dotnet" build -c Release "$src/RepoXR.csproj" -v quiet -nologo >/dev/null
echo "RepoXR built: $src/bin/Release/netstandard2.1/RepoXR.dll"
