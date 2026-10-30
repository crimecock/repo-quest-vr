# R.E.P.O. VR controls on Quest 3

**English** · [Русский](controls.ru.md) · On PC: [RepoXR controls on PC](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/docs/controls.md) (the menu is on X there)

RepoXR's default bindings (action map `VRInputs`, Meta Quest profile). They can be changed in the game: *Settings →
Controls* (RepoXR lists its actions there). For left-handed play, RepoXR's settings have *Left Hand Dominant*, which
swaps the hands.

> Written from RepoXR 1.2.3's code (default action map) and this port's changes (since 1.0.7-qc12: the menu is on the
> left menu button, X mutes the microphone, vehicles follow the left stick). Confirmed on the headset with 1.0.7-qc21:
> looking around, the pointer, grabbing and the menu button, in the menus, the lobby and the levels; vehicles and
> weapons are still being checked.

## Buttons

| Controller | Action |
|---|---|
| **Left stick** | Move |
| **Left stick, click** | Chat (multiplayer only: R.E.P.O. 0.5.0 has no chat in singleplayer) |
| **Left stick, hold (0.3 s)** | Expression wheel |
| **Left trigger** | Sprint |
| **Left grip** | Rotate the held object (with the right stick) |
| **Left menu button (≡)** | Menu (pause) |
| **X** | Mute / unmute your microphone (multiplayer) |
| **Y** | Reset height |
| **Right stick left/right** | Turn (smooth by default; snap turns of 45° in RepoXR's settings) |
| **Right stick up/down** | Holding an object: push or pull it; in menus and lists: scroll |
| **Right stick, click** | Crouch |
| **Right trigger** | Grab (grab beam) |
| **Right grip** | Interact (doors, buttons, levers); horn on a scooter |
| **A** | Jump |
| **B** | Tumble |

## With your hands

- **Map**: bring either hand to your shoulder. When the controller buzzes, hold that hand's **grip**: the map is in
  your hand. Let go of the grip and it goes away. Not while sprinting.
- **Flashlight on the head**: bring the other (non-dominant) hand to the side of your head and press **grip**. Press
  again to take it back into your hand.
- **Inventory (3 slots)**:
  - *store*: hold an item with the beam; the slots grow and move in front of you. Point the beam with the item at a slot;
  - *take out*: put your dominant hand into a slot with an item and press the **right trigger**.
- **Expressions**: hold the left stick to open the wheel. Point a hand at an expression and press **that hand's
  trigger** to toggle it. Holding the stick again closes the wheel.
- **Menus and UI**: the pointer from your hand and the **trigger**. RepoXR's keyboard appears under the menu when text
  is needed (Steam login, lobby password).

## Grabbing

Point the hand and hold the **right trigger**: the beam holds the object while the trigger is held. Taking an item out
of an inventory slot: with the game's *Settings → Gameplay → Item Unequip Auto Hold* (new in R.E.P.O. 0.5.0, on by
default) the item stays on the beam after you let go of the trigger, until you press it again; off, it falls as soon
as you let go.

## Weapons

- **Guns** (pistol, shotgun, tranq gun, laser, revolver...): grab the gun with the beam and press the **right grip**
  to fire. Shots leave the muzzle, so aim by pointing the gun: R.E.P.O. 0.5.0 turns a held gun to point along your
  grab beam, from the hand you hold it with (since 1.0.7-qc13; before, it aimed from your head).
- **Melee weapons** (bat, sword, frying pan...): hold them with the beam and swing your hand.
- **Whip** (new in 0.5.0; from 1.0.7-qc22): hold it with the **right trigger** and use your hand like a real whip.
  *Crack:* snap the controller back and then forward, from the side or from over the shoulder; it hits where your hand
  points. *Fling:* once it has caught something, swing your hand. Don't hold the **left grip** (rotate) meanwhile.
  Too easy or too hard: VR Settings → Input → *Whip Sideways Sensitivity* (0.5) and *Whip Crack Sensitivity* (1).

## Vehicles

R.E.P.O. 0.5.0 has a scooter, the snow bike (Arctic) and the golf cart (Desert).

- **Get on**: point the beam at the vehicle's seat or handlebar and press the **right trigger** once: you are seated.
  Getting on is a toggle, as in the game (*Settings → Controls*, `VehicleGrab`): you do not need to keep the trigger
  held.
- **Drive**: **left stick** forward to accelerate, back to brake and reverse, left/right to steer. A scooter goes where
  your hand points (or your head: *VR Settings → Input → Vehicle direction source*); pushing the stick far to a side
  drifts.
- **Horn**: **right grip** on a scooter.
- **Get off**: press the **right trigger** again.

## When you are dead

- **Right trigger / left trigger**: next / previous player while spectating.

## Seated

Sit the way you will play and press **Y**: the game takes your current head height as standing height. Also turn off
**Roomscale Crouch** in RepoXR's settings (Gameplay), or looking down while seated counts as crouching.

## Voice

The microphone follows the game's own settings (*Settings → Audio*: voice activation or push-to-talk). **X** mutes and
unmutes it in multiplayer. Push-to-talk has no controller binding; assign the PushToTalk action to a free button in
the controls settings if you need it.
