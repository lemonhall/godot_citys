# godot_citys

Godot 4.6 skeleton for a city-themed 3D game prototype.

## What is included

- One runnable main scene at `res://city_game/scenes/CityPrototype.tscn`
- A third-person placeholder controller with mouse-look camera
- A generated city block grid made from built-in meshes only
- A HUD overlay with controls and block summary
- A headless smoke test for the scene contract

## Run in the editor

1. Open this folder in Godot 4.6.
2. Press `F5` to run the project.
3. Use `WASD` or arrow keys to move.
4. Hold `Shift` to sprint.
5. Press `Space` to jump.
6. Move the mouse to rotate the camera.
7. Press `Esc` to release or recapture the cursor.

## Headless verification

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/test_city_skeleton_smoke.gd'
```

Expected result: `PASS`

## Layout

- `city_game/scenes/` main scenes
- `city_game/scripts/` gameplay scripts
- `city_game/ui/` HUD scripts
- `tests/` headless smoke tests
- `docs/plan/` milestone notes
- `docs/plans/` implementation plans

## FFmpeg Runtime Artifacts

The radio native backend keeps the FFmpeg runtime in this repository, but GitHub blocks regular Git blobs larger than `100 MB`. The only oversized runtime binary is `avfilter-11.dll`, so it is stored as split `7z` blob volumes instead of a raw tracked DLL:

- `city_game/native/radio_backend/thirdparty/ffmpeg/archives/avfilter-11.dll.7z.001`
- `city_game/native/radio_backend/thirdparty/ffmpeg/archives/avfilter-11.dll.7z.002`
- ...

Before running or rebuilding the native radio backend on a fresh clone, restore that DLL with:

```powershell
pwsh -File .\scripts\restore-radio-ffmpeg-avfilter.ps1
```

That script extracts the split archive and restores:

- `city_game/native/radio_backend/bin/win64/avfilter-11.dll`
- `city_game/native/radio_backend/thirdparty/ffmpeg/windows-x64-shared/ffmpeg-8.1-full_build-shared/bin/avfilter-11.dll`

If you already have local copies and want to overwrite them, add `-Force`:

```powershell
pwsh -File .\scripts\restore-radio-ffmpeg-avfilter.ps1 -Force
```

## Next milestone

- Replace box towers with modular building kits
- Add roads with intersections, sidewalks, and traffic placeholders
- Introduce interactable districts, mission hooks, and streaming chunks
- Add pedestrians, vehicles, and save-game state
