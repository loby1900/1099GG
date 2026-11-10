# Apex Drift

## Overview

Apex Drift is a 3D arcade drift-racing game built with the Godot Engine. It features arcade vehicle physics, a roster of cars, and a set of hand-built tracks, with full touch controls so it plays as well on a phone or tablet as it does on desktop.

## Features

- **10 Cars** - Porsche, Dodge Challenger, Toyota Supra, Mazda RX7, Mercedes 190 Evo2, Mitsubishi Lancer Evo, Acura NSX, an F1 car, and a BMW 330i xDrive and BMW M4 GT3 Evo, each with its own handling, collision size, gear ratios, and a distinct, individually-synthesized engine sound.
- **4 Tracks** - Forest Circuit, Desert Circuit, a sprawling Canyon Free Roam, and a lit Night Circuit.
- **Full Touch Controls** - an on-screen steering wheel (or classic left/right arrow buttons, switchable in Options > Controls), gas/brake pedals, gear shift buttons, a drag-to-orbit camera, and a pause button, alongside full keyboard/gamepad support on desktop.
- **Time Trials** - sector and lap timing with saved best times per track.
- **Arcade Vehicle Physics** - RigidBody3D cars with raycast wheel suspension, a gear/RPM model, and real braking.
- **Working Headlights & Brake Lights** - every car casts real forward headlight beams and lights up its brake lights under braking, most noticeable on the Night Circuit.
- **Procedural Tracks & Sky** - each map is generated at runtime from a short list of waypoints (smoothed road mesh, guardrails, scenery, lap checkpoints) under a procedural gradient sky with a real sun disk tied to each map's lighting, so new tracks can be added without hand-building geometry.

## Engine

Built and maintained for **Godot 4.7** (GDScript, Forward Mobile rendering, Jolt physics), targeting Desktop, Android, and iOS.

## Controls

**Desktop**
- `WASD` / Arrow Keys / left stick + bumpers: drive, steer, shift
- `Space`: gear up, `Ctrl`: gear down
- `Esc`: pause
- Middle mouse button (held): rotate camera

**Mobile / Touch**
- On-screen steering wheel (bottom-left)
- Gas / brake / shift-up / shift-down buttons (bottom-right)
- Drag anywhere on screen to orbit the camera
- Pause button (top-right)

## Project Structure

- `Scenes/` - menus, HUD, and the 4 race maps (each a thin `RaceWorld.gd` instance with map-specific waypoints and theme)
- `Scripts/` - gameplay, UI, and the procedural track/scenery generators (`TrackBuilder.gd`, `PropScatter.gd`)
- `Models/`, `Shaders/`, `SFX/`, `Images/` - art, audio, and shader assets

## License

All code and assets in this repository belong to the project owner. See the repository for usage terms.

## Credits

- **Owner**: [loby1900](https://github.com/loby1900)
- **BMW 330i xDrive (2025)** and **BMW M4 GT3 Evo (G82, 2025)** 3D models by **Ddiaz Design**, via Sketchfab, licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). Used here non-commercially with attribution, as the license requires; the models were adapted (rescaled/repositioned) to fit this project's shared vehicle physics.
