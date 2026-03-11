# City 3D Skeleton Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Godot 4.6 project skeleton for a city-themed 3D game with a runnable main scene, controllable player, generated placeholder city blocks, HUD, and a headless smoke test.

**Architecture:** Keep the first slice runtime-only and asset-free so the project boots on any machine with Godot 4.6. Use one main scene that composes a generated city root, a third-person player controller, and a lightweight HUD; verify with a SceneTree smoke test that checks the expected node contract.

**Tech Stack:** Godot 4.6, GDScript, text `.tscn` scenes, headless SceneTree smoke tests

---

### Task 1: Bootstrap the project contract

**Files:**
- Create: `project.godot`
- Create: `.gitignore`
- Create: `docs/plans/2026-03-11-city-skeleton.md`

**Step 1: Write the failing test**

Create a smoke test that expects `res://city_game/scenes/CityPrototype.tscn` and its core nodes to exist.

**Step 2: Run test to verify it fails**

Run: `& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path . --script res://tests/test_city_skeleton_smoke.gd`

Expected: FAIL because the main scene does not exist yet.

**Step 3: Write minimal implementation**

Add minimal project config and ignore rules so the project can host the scene and run headless.

**Step 4: Run test to verify it still targets the missing scene**

Run the same command and confirm failure still points at the missing scene contract, not at a broken project config.

### Task 2: Build the playable 3D slice

**Files:**
- Create: `city_game/scenes/CityPrototype.tscn`
- Create: `city_game/scripts/CityPrototype.gd`
- Create: `city_game/scripts/CityBlockGrid.gd`
- Create: `city_game/scripts/PlayerController.gd`
- Create: `city_game/ui/PrototypeHud.gd`

**Step 1: Write the failing test**

Extend the smoke test to require these node paths:
- `CityPrototype/GeneratedCity`
- `CityPrototype/Player`
- `CityPrototype/Player/CameraRig`
- `CityPrototype/Hud`

**Step 2: Run test to verify it fails**

Expected: FAIL on the first missing node.

**Step 3: Write minimal implementation**

Create one scene with:
- ground plane and light
- generated placeholder buildings and roads
- a third-person controllable player
- HUD text that explains controls and reports block counts

**Step 4: Run test to verify it passes**

Run the smoke test again and expect PASS.

### Task 3: Document and verify the slice

**Files:**
- Create: `README.md`
- Create: `docs/plan/v1-index.md`

**Step 1: Write the failing test**

No extra automated test; use the existing smoke test as the regression guard.

**Step 2: Run verification**

Re-run the smoke test from a clean shell command and inspect exit code and output.

**Step 3: Write minimal implementation**

Document:
- what the skeleton currently includes
- how to run it in the editor
- how to execute the headless smoke test
- what the next city-game milestone should add

**Step 4: Run test to verify it still passes**

Re-run the same smoke test and keep the output pristine.

