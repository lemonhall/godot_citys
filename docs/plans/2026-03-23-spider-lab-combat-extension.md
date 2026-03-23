# Spider Lab Combat Extension Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend `SpiderCrawlerLab` so the player can use the existing weapon system against a multi-spawn spider swarm, with rifle time-to-kill landing around 10-14 shots.

**Architecture:** Reuse the existing `PlayerController -> lab scene -> combat node` pattern already used by other labs. Keep spider locomotion intact, but add a formal combat contract to `CitySpiderCrawler` through a delegated hurtbox, health state, and damage handling so rifle, grenade, laser, and missile consumers can all hit the same enemy interface.

**Tech Stack:** Godot 4.6, GDScript, existing `CityProjectile` / `CityGrenade` / `CityMissile` / `CityLaserDesignatorBeam`, headless scene tests.

---

### Task 1: Lock the combat contract

**Files:**
- Create: `docs/plans/2026-03-23-spider-lab-combat-extension.md`
- Create: `tests/world/test_spider_crawler_lab_combat_contract.gd`
- Create: `tests/e2e/test_spider_crawler_lab_combat_flow.gd`

**Step 1: Write the failing tests**

- Add a world contract test that requires:
  - `SpiderCrawlerLab` to expose formal combat roots and focused fire helpers.
  - The lab player to preserve formal `rifle / grenade / laser_designator / missile_launcher` request APIs.
  - The lab to boot with a swarm size of at least 12 live spiders.
  - Each formal weapon request to reduce at least one spider's health.
- Add an e2e flow test that requires:
  - A nearby spider survives 9 rifle hits.
  - The same spider dies by 14 rifle hits.
  - `reset_lab_state()` restores the defeated spider back into the live swarm.

**Step 2: Run tests to verify they fail**

Run:

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_lab_combat_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_spider_crawler_lab_combat_flow.gd'
```

Expected: FAIL because the lab does not yet expose combat roots, swarm introspection, or spider damage/health.

### Task 2: Wire the lab to the existing weapon system

**Files:**
- Modify: `city_game/scenes/labs/SpiderCrawlerLab.tscn`
- Modify: `city_game/scenes/labs/SpiderCrawlerLab.gd`

**Step 1: Implement the minimal lab combat surface**

- Author combat roots in the scene.
- Add authored swarm spawn markers near the player start zone.
- Connect player weapon request signals in the lab script.
- Reuse the existing projectile, grenade, laser beam, and missile resources for the four weapon modes.
- Add focused helper methods for deterministic aim/fire and swarm state introspection.

**Step 2: Run the world contract test**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_lab_combat_contract.gd'
```

Expected: still FAIL until spider enemies can take damage.

### Task 3: Give spiders a formal enemy health contract

**Files:**
- Modify: `city_game/world/creatures/arthropods/CitySpiderCrawler.tscn`
- Modify: `city_game/world/creatures/arthropods/CitySpiderCrawler.gd`
- Create: `city_game/world/creatures/arthropods/CitySpiderCrawlerHurtbox.gd`

**Step 1: Implement the minimal enemy contract**

- Add a delegated hurtbox physics body under the spider body.
- Add `get_health_state()`, `reset_health_state()`, and `apply_projectile_hit()` to the spider runtime.
- Freeze rifle time-to-kill around 10-14 shots by giving the spider a larger health pool and reduced heavy-hit scaling.
- Stop locomotion and disable the hurtbox after death, while keeping the corpse visible for horror/readability.

**Step 2: Run both combat tests**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_lab_combat_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_spider_crawler_lab_combat_flow.gd'
```

Expected: PASS.

### Task 4: Run regression coverage

**Files:**
- Modify: `city_game/scenes/labs/SpiderCrawlerLab.gd`
- Modify: `city_game/world/creatures/arthropods/CitySpiderCrawler.gd`

**Step 1: Verify focused spider regressions still pass**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_lab_scene_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_spider_crawler_lab_flow.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_gait_contract.gd'
```

Expected: PASS.

**Step 2: Save fresh evidence**

- Keep the final verification command list for the close-out response.
- If needed, add a short post-closeout note under `docs/plan/`.
