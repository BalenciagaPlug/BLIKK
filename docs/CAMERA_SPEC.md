# BLIKK Camera Specification

# Purpose

This document defines every camera rule used throughout BLIKK.

The camera exists to maximise gameplay clarity, movement precision and player control.

The camera should never fight the player.

Gameplay always has priority over cinematic presentation.

---

# Camera Philosophy

The camera should feel:

- Responsive
- Predictable
- Stable
- Competitive
- Readable

The player should forget the camera exists.

Good camera behaviour is invisible.

---

# Core Principles

## 1. Crosshair First

The crosshair is the centre of gameplay.

It is always mathematically centred.

It never moves because of recoil, dash, animations or effects.

An equipped local firearm automatically follows the existing centered crosshair ray. There is no aim
button or aim-down-sights camera mode. Arm IK consumes the camera result for presentation only and
does not write camera position, rotation, sensitivity, field of view, or crosshair placement.
Developer free-look supplies no new firearm aim samples; the last valid gun pose remains frozen while
the inspection camera orbits and resumes centered-crosshair tracking as soon as free-look ends.

Only future optional accessibility settings may modify appearance.

---

## 2. Character Framing

The player character should:

- sit slightly left of centre
- occupy the lower portion of the screen
- never cover the crosshair
- remain readable during movement

Camera framing exists to maximise battlefield visibility.

---

## 3. Camera Behaviour

The camera must:

- rotate instantly
- never lag behind input
- never interpolate unnecessarily
- never overshoot
- never wobble

Mouse movement equals camera movement.

---

## 4. Camera Movement

Current implementation:

- Third person
- Camera-relative movement
- Camera-relative dash
- Character rotates toward camera yaw

Future systems must preserve this behaviour.

---

## 5. Camera Feedback

Feedback should be subtle.

Examples:

- recoil kick
- landing compression
- heavy impacts

Camera feedback must never interfere with aiming.
Dash presentation does not own or offset FOV; the configured player FOV remains unchanged through a dash.

---

## 6. Settings

Players may configure:

- FOV
- Distance
- Height
- Shoulder Offset
- Sensitivity
- Invert Y

Future settings:

- Camera Shake
- Dynamic FOV
- Weapon Bob
- Landing Bob
- Head Bob
- Motion Blur
- Screen Effects

All gameplay remains identical regardless of settings.

---

## 7. Competitive Rules

No camera option should provide unfair information.

Players should only customise comfort.

Never gameplay advantage.

---

## 8. Performance

Camera code should:

- allocate nothing every frame
- avoid duplicate listeners
- recover after respawn
- recover after menus
- survive resetting

---

## 9. Future Camera Modes

Movement Lab

- Current gameplay camera

Spectator

- Free camera
- Chase camera
- Player cycling

Replay

- Timeline camera
- Cinematic camera

Character Creation

- Orbit camera

Main Menu

- Animated showcase camera

---

## 10. Death Camera

An authoritative fighter death replaces the respawn loading screen with a live third-person orbit
around that fighter's body. The local player may rotate the view with normal mouse sensitivity and
zoom within the configured range. World obstruction still moves the camera inward, and other live
players remain visible through normal replication; the camera never fades or reveals character
models through map geometry.

The death camera owns named input and gameplay-camera blockers while active. It preserves the last
valid body position if Roblox removes the old character during `LoadCharacterAsync`, and it releases
ownership only when a strictly newer spawn generation has `BLIKK_GameplayReleased = true`. True room
spectators retain the separate target-cycling camera.

---

## Definition of Done

A camera feature is complete when it:

- feels invisible
- respects settings
- survives respawn
- respects menus
- preserves crosshair alignment
- performs consistently
- improves gameplay
