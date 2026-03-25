# M777 Anchor Semantics Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restore single-responsibility, authored-anchor-driven semantics for the M777 howitzer so `MuzzleFxAnchor`, lanyard, audio, and ballistic origin no longer overwrite each other at runtime.

**Architecture:** Keep the current ballistic solver and operation flow, but split authored anchor responsibilities into explicit channels. `MuzzleFxAnchor` drives only visual muzzle FX, a new `MuzzleBallisticsAnchor` drives only ballistic origin/direction through a dedicated runtime probe, `LanyardAnchor` drives only rope visuals, and a new `FireAudioAnchor` drives only shot audio placement. Remove the runtime code that snaps visual FX to the corrected gun tip.

**Tech Stack:** Godot 4.6, GDScript, headless world/e2e contracts.

---

### Task 1: Lock the new anchor semantics in tests

**Files:**
- Modify: `tests/world/test_city_m777_howitzer_scene_contract.gd`
- Modify: `tests/world/test_city_m777_howitzer_fire_contract.gd`
- Create: `tests/world/test_city_m777_howitzer_anchor_responsibility_contract.gd`

**Step 1: Write the failing test expectations**

- Require new authored nodes:
  - `Anchors/MuzzleBallisticsAnchor`
  - `Anchors/FireAudioAnchor`
  - `ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleBallisticsProbe`
- Restore strict `MuzzleFxAnchor -> MuzzleFlash/MuzzleSmoke` transform equality.
- Require `FireAudioAnchor -> FireAudio` transform equality.
- Require `MuzzleFxAnchor` changes to leave the ballistic probe/origin unchanged.
- Require `MuzzleBallisticsAnchor` changes to move only the ballistic probe/origin and not the muzzle flash.

**Step 2: Run the focused tests to verify they fail**

Run:

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_m777_howitzer_scene_contract.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_m777_howitzer_fire_contract.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_m777_howitzer_anchor_responsibility_contract.gd'
```

Expected: FAIL because the new anchors/probe do not exist and current runtime still couples visual FX to ballistic state.

### Task 2: Author explicit anchor/probe nodes in the scene

**Files:**
- Modify: `city_game/combat/artillery/CityM777Howitzer.tscn`

**Step 1: Add authored single-responsibility anchors**

- Create `Anchors/MuzzleBallisticsAnchor` using the current muzzle baseline transform.
- Create `Anchors/FireAudioAnchor` using the current breech/audio baseline transform.

**Step 2: Add runtime ballistic probe node**

- Create `ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleBallisticsProbe` as a non-visual `Marker3D`.

**Step 3: Re-run scene contract**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_m777_howitzer_scene_contract.gd'
```

Expected: still FAIL because runtime wiring has not been updated yet.

### Task 3: Refactor runtime anchor wiring

**Files:**
- Modify: `city_game/combat/artillery/CityM777Howitzer.gd`

**Step 1: Wire explicit anchors and probe**

- Add `_muzzle_ballistics_anchor`, `_fire_audio_anchor`, `_muzzle_ballistics_probe`.
- Update `get_anchor_state()` to expose the new authored anchors/probe.

**Step 2: Remove runtime anchor semantic pollution**

- Delete the visual-tip snapping helpers and their call sites.
- Restore `_sync_fire_presentation_from_anchors()` to be a pure “copy authored anchor transform to runtime attachment” function:
  - `MuzzleFxAnchor -> MuzzleFlash`
  - `MuzzleFxAnchor -> MuzzleSmoke`
  - `MuzzleBallisticsAnchor -> MuzzleBallisticsProbe`
  - `LanyardAnchor -> Lanyard`
  - `FireAudioAnchor -> FireAudio`

**Step 3: Route ballistic state through the dedicated probe**

- `_resolve_muzzle_origin_world_position()` should use `MuzzleBallisticsProbe`.
- `_resolve_muzzle_world_direction()` should use `MuzzleBallisticsProbe` before any visual FX node.

**Step 4: Keep gun-assembly visual correction isolated**

- Leave the gun mesh correction code limited to `m777_gun_assembly`.
- Do not let that code move flash, smoke, rope, or audio nodes.

**Step 5: Re-run focused tests**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_m777_howitzer_fire_contract.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_m777_howitzer_anchor_responsibility_contract.gd'
```

Expected: PASS.

### Task 4: Re-tune authored baseline if needed

**Files:**
- Modify: `city_game/combat/artillery/CityM777Howitzer.tscn`
- Verify with: `tests/world/test_city_m777_howitzer_fire_visual_contract.gd`
- Verify with: `tests/world/test_city_m777_howitzer_fire_origin_contract.gd`

**Step 1: Tune authored anchor transforms**

- If the restored `MuzzleFxAnchor` baseline no longer lands close enough to the visible muzzle, adjust:
  - `Anchors/MuzzleFxAnchor`
  - `Anchors/MuzzleBallisticsAnchor`
  - `Anchors/LanyardAnchor`
  - `Anchors/FireAudioAnchor`

**Step 2: Re-run visual contracts**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_m777_howitzer_fire_visual_contract.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_m777_howitzer_fire_origin_contract.gd'
```

Expected: PASS with authored anchors, without runtime snapping.

### Task 5: Full regression on howitzer + tennis-court hit flow

**Files:**
- Verify only:
  - `tests/world/test_city_m777_howitzer_scene_contract.gd`
  - `tests/world/test_city_m777_howitzer_fire_contract.gd`
  - `tests/world/test_city_world_howitzer_spawn_contract.gd`
  - `tests/world/test_city_m777_howitzer_operation_display_contract.gd`
  - `tests/world/test_city_m777_howitzer_operation_display_physics_contract.gd`
  - `tests/world/test_city_m777_howitzer_visual_yaw_contract.gd`
  - `tests/world/test_city_m777_howitzer_visual_pitch_contract.gd`
  - `tests/world/test_city_m777_howitzer_fire_visual_contract.gd`
  - `tests/world/test_city_m777_howitzer_fire_origin_contract.gd`
  - `tests/world/test_city_m777_howitzer_anchor_responsibility_contract.gd`
  - `tests/e2e/test_city_artillery_tennis_court_hit_flow.gd`

**Step 1: Run the full affected suite**

Run:

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_m777_howitzer_scene_contract.gd',
  'res://tests/world/test_city_m777_howitzer_fire_contract.gd',
  'res://tests/world/test_city_world_howitzer_spawn_contract.gd',
  'res://tests/world/test_city_m777_howitzer_operation_display_contract.gd',
  'res://tests/world/test_city_m777_howitzer_operation_display_physics_contract.gd',
  'res://tests/world/test_city_m777_howitzer_visual_yaw_contract.gd',
  'res://tests/world/test_city_m777_howitzer_visual_pitch_contract.gd',
  'res://tests/world/test_city_m777_howitzer_fire_visual_contract.gd',
  'res://tests/world/test_city_m777_howitzer_fire_origin_contract.gd',
  'res://tests/world/test_city_m777_howitzer_anchor_responsibility_contract.gd',
  'res://tests/e2e/test_city_artillery_tennis_court_hit_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

Expected: PASS.
