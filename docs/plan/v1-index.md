# V1 Index

## Goal

Ship a stable first playable slice of `godot_citys` that boots in Godot 4.6 and gives the project a concrete 3D city gameplay foundation.

## Current status

- Project bootstrap complete
- Main scene contract established
- Third-person placeholder controller in place
- Procedural placeholder city blocks in place
- Smoke test for scene loading in place

## Definition of done for this slice

- Godot 4.6 opens the project without missing-resource errors
- `res://city_game/scenes/CityPrototype.tscn` is the main scene
- The player can move around a generated city block layout
- A headless smoke test confirms the scene contract

## Next candidate slices

1. Replace generated towers with modular street kits and landmarks.
2. Add interactable city systems such as traffic lights, shops, or mission triggers.
3. Add a save model for district state, player spawn, and world progression.
