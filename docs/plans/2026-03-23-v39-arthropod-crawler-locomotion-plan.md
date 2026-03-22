# V39 Arthropod Crawler Locomotion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 建立一条可复用的 arthropod locomotion spine，并按“蜘蛛优先、龙虾复用同一主链”的顺序交付两座独立 lab 场景，同时冻结 future main-world port 契约。

**Architecture:** 共享层负责 `profile + per-leg state + foothold search + body solve + debug state`，species wrapper 只注入 gait 和视觉差异，lab scene 只负责 authoring 与 reset。`v39` 明确不接主世界，但要求 future wrapper 只能复用同一 runtime，不允许日后分叉。

**Tech Stack:** Godot 4.6、GDScript、独立 lab scenes、headless world tests、focused e2e、可选 IK 参考 `GodotIK` / `ISOK`

---

### Task 1: 冻结文档与文件骨架

**Files:**
- Create: `docs/prd/PRD-0026-arthropod-crawler-locomotion-labs.md`
- Create: `docs/plan/v39-index.md`
- Create: `docs/plan/v39-arthropod-crawler-locomotion-labs.md`
- Create: `docs/research/2026-03-23-spider-lobster-procedural-gait-research.md`

**Step 1: 写需求与边界**

- 冻结 `v39` 范围只包含：
  - shared locomotion spine
  - spider lab
  - lobster lab
  - future main-world portability hooks
- 明确首版不做：
  - wall/ceiling spider
  - 主世界正式接入
  - 失败态/任务链/生态系统

**Step 2: 写 traceability**

- 在 `v39-index.md` 中为 `REQ-0026-*` 建追溯矩阵。
- 每一条 requirement 对应至少一条 planned test。

**Step 3: 审查文件命名**

Run:

```powershell
rg -n "REQ-0026|v39" docs/prd/PRD-0026-arthropod-crawler-locomotion-labs.md docs/plan/v39-index.md docs/plan/v39-arthropod-crawler-locomotion-labs.md
```

Expected:

- 文档都存在
- `REQ-0026-*` 与 `v39` 关键字能被检出

### Task 2: 建 shared arthropod locomotion spine

**Files:**
- Create: `city_game/world/creatures/arthropods/CityArthropodLocomotionProfile.gd`
- Create: `city_game/world/creatures/arthropods/CityArthropodLegRuntime.gd`
- Create: `city_game/world/creatures/arthropods/CityArthropodFootholdResolver.gd`
- Create: `city_game/world/creatures/arthropods/CityArthropodBodySolver.gd`
- Create: `city_game/world/creatures/arthropods/CityArthropodCrawlerRuntime.gd`
- Test: `tests/world/test_arthropod_crawler_shared_spine_contract.gd`

**Step 1: 先写 shared spine contract test**

- 断言 profile 可驱动不同腿数量/phase table。
- 断言 runtime 暴露稳定 debug state。
- 断言 species wrapper 不必篡改 shared state schema。

**Step 2: 跑红灯**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_arthropod_crawler_shared_spine_contract.gd'
```

Expected:

- FAIL，提示 shared arthropod runtime 尚不存在

**Step 3: 只写最小共享实现**

- 先保证：
  - profile 结构稳定
  - per-leg state 可更新
  - debug state 可读
- 不在这一步偷做 spider / lobster 特化

**Step 4: 跑绿灯**

- 同一条 test 通过

### Task 3: 落 SpiderCrawlerLab 与蜘蛛 gait contract

**Files:**
- Create: `city_game/scenes/labs/SpiderCrawlerLab.tscn`
- Create: `city_game/scenes/labs/SpiderCrawlerLab.gd`
- Create: `city_game/world/creatures/arthropods/CitySpiderCrawler.tscn`
- Create: `city_game/world/creatures/arthropods/CitySpiderCrawler.gd`
- Test: `tests/world/test_spider_crawler_lab_scene_contract.gd`
- Test: `tests/world/test_spider_crawler_gait_contract.gd`
- Test: `tests/world/test_spider_crawler_terrain_follow_contract.gd`
- Test: `tests/e2e/test_spider_crawler_lab_flow.gd`

**Step 1: 先锁 Spider lab scene contract**

- 断言场景里有：
  - crawler root
  - terrain fixtures
  - HUD/debug root
  - reset path

**Step 2: 再锁 gait contract**

- 断言不是所有脚同步抬起
- 断言 stance 脚点会锁定
- 断言 terrain change 会触发局部 replanning

**Step 3: 跑红灯**

- scene contract 和 gait contract 都应先失败

**Step 4: 最小 green**

- 先让蜘蛛在平地成立
- 再补坡面和台阶
- 最后补 reset / HUD / debug 输出

**Step 5: focused verification**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_lab_scene_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_gait_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_terrain_follow_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_spider_crawler_lab_flow.gd'
```

Expected:

- 全部 PASS

### Task 4: 用同一 shared spine 落 LobsterCrawlerLab

**Files:**
- Create: `city_game/scenes/labs/LobsterCrawlerLab.tscn`
- Create: `city_game/scenes/labs/LobsterCrawlerLab.gd`
- Create: `city_game/world/creatures/arthropods/CityLobsterCrawler.tscn`
- Create: `city_game/world/creatures/arthropods/CityLobsterCrawler.gd`
- Test: `tests/world/test_lobster_crawler_lab_scene_contract.gd`
- Test: `tests/world/test_lobster_crawler_metachronal_gait_contract.gd`
- Test: `tests/world/test_lobster_crawler_shared_runtime_contract.gd`
- Test: `tests/e2e/test_lobster_crawler_lab_flow.gd`

**Step 1: 先写复用 contract**

- 断言龙虾 consumer 走 shared runtime
- 断言龙虾 gait ordering 不等于蜘蛛
- 断言龙虾 clearance / step height 更低

**Step 2: 跑红灯**

- shared runtime 已存在，但 lobster wrapper 和 scene 尚不存在

**Step 3: 最小 green**

- 优先复用 `lobster_02.glb`
- 先做 forward metachronal crawl
- 不在这一步引入水下物理或尾部爆发

**Step 4: focused verification**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_lobster_crawler_lab_scene_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_lobster_crawler_metachronal_gait_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_lobster_crawler_shared_runtime_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_lobster_crawler_lab_flow.gd'
```

Expected:

- 全部 PASS

### Task 5: 冻结 future main-world portability hooks 与验证口径

**Files:**
- Create: `tests/world/test_arthropod_crawler_portability_contract.gd`
- Modify: `docs/plan/v39-index.md`
- Modify: `docs/plan/v39-arthropod-crawler-locomotion-labs.md`

**Step 1: 写 portability contract**

- 断言 future wrapper 至少需要：
  - world anchor
  - ground resolver
  - activation gate
  - debug passthrough
- 断言 lab scene 不是 future world wrapper

**Step 2: 文档回填**

- 在 `v39-index` 追溯矩阵中补齐 tests
- 在 `v39` plan 中冻结“lab runtime == future main-world runtime”

**Step 3: 最小验证**

Run:

```powershell
rg -n "lab runtime == future main-world runtime|portability" docs/plan/v39-index.md docs/plan/v39-arthropod-crawler-locomotion-labs.md
```

Expected:

- 能检出 portability freeze 语句

## Notes

- 蜘蛛没有现成正式资产，优先允许 blockout/proxy rig；不要因为等美术而让 gait spine 停摆。
- 如果 IK 插件只适合 authoring/debug，就不要硬塞进每帧热路径。
- `v39` 不该把“看起来像生物”放在“脚点 contract 成立”之前。
