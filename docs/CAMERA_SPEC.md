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

## Definition of Done

A camera feature is complete when it:

- feels invisible
- respects settings
- survives respawn
- respects menus
- preserves crosshair alignment
- performs consistently
- improves gameplay
