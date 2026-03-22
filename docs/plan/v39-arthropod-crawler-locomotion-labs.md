# V39 Arthropod Crawler Locomotion Labs

## Goal

先交付一条可复用的 arthropod locomotion spine，再在低干扰环境里按“蜘蛛优先、龙虾第二”的顺序落成两座独立 lab：`SpiderCrawlerLab` 先验证多腿 gait、落脚点搜索与地形跟随，`LobsterCrawlerLab` 再验证同一 shared runtime 真能承载另一种 gait profile。`v39` 当前不接主世界，但必须把 future main-world port 的 wrapper 契约提前冻结，确保后续只是移植，不是第二轮重写。

## PRD Trace

- Direct consumer: REQ-0026-001
- Direct consumer: REQ-0026-002
- Direct consumer: REQ-0026-003
- Direct consumer: REQ-0026-004
- Direct consumer: REQ-0026-005
- Direct consumer: REQ-0026-006

## Dependencies

- 依赖仓库既有 `lab-first` 工作流：
  - `v33` `BuildingCollapseLab`
  - `v37` `HelicopterGunshipLab`
  - `v38` `LakeFishingLab`
- 依赖 research 结论：
  - `docs/research/2026-03-23-spider-lobster-procedural-gait-research.md`
- 当前 creature 资产：
  - `res://city_game/assets/environment/source/creatures/lobster_02.glb`
- 当前蜘蛛视觉资产缺失，因此允许 proxy/blockout rig

## Contract Freeze

- shared runtime 是 `v39` 的正式交付物；蜘蛛和龙虾都只是它的 consumer。
- lab runtime 与 future main-world runtime 必须保持同一条行为主链。
- `v39` 先蜘蛛，后龙虾。
- 蜘蛛首版冻结为：
  - ground / slope / low-obstacle crawling
  - 不做 wall-walking / ceiling-walking
- 龙虾首版冻结为：
  - forward crawler
  - metachronal wave preference
  - 更低 body clearance
  - 不做水下推进
- debug state 最小 contract 至少包括：
  - `species_id`
  - `gait_profile_id`
  - `body_target_transform`
  - `phase_time`
  - `legs`
  - `failed_replan_count`
- `legs` 的最小 per-leg contract 至少包括：
  - `leg_id`
  - `phase`
  - `mode`
  - `locked_foothold`
  - `desired_foothold`
  - `is_grounded`
  - `replan_count`
- future main-world port 最小契约冻结为：
  - `world_anchor`
  - `ground_resolver`
  - `activation_gate`
  - `debug_passthrough`

## Scope

做什么：

- 新增 shared locomotion spine
- 新增蜘蛛 species wrapper + Spider lab
- 新增龙虾 species wrapper + Lobster lab
- 新增 focused tests
- 冻结 future port 契约

不做什么：

- 不做主世界接入
- 不做任务、地图、pin、ring、route 接入
- 不做 wall spider
- 不做龙虾水下推进与流体
- 不做敌对 AI 或战斗

## Acceptance

1. 自动化测试必须证明：shared locomotion spine 可在不依赖具体 species scene 的情况下被 profile 驱动，并输出稳定 debug state。
2. 自动化测试必须证明：`SpiderCrawlerLab.tscn` 可独立加载 crawler root、terrain fixtures、HUD/debug root 与 reset 主链。
3. 自动化测试必须证明：蜘蛛 gait 存在稳定的 per-leg state 与 stance 锁脚，而不是整体平移加循环摆腿。
4. 自动化测试必须证明：蜘蛛在坡面或低障碍上至少会触发局部 foothold replanning 和 body tilt 补偿。
5. 自动化测试必须证明：龙虾 consumer 仍走 shared runtime，而不是新起第二套 locomotion 逻辑。
6. 自动化测试必须证明：龙虾 gait ordering、步高和身体 clearance 与蜘蛛存在明确差异，且更接近低姿 forward crawl。
7. 自动化测试必须证明：future portability contract 已在文档和测试层冻结，lab scene 不会被当成 future world wrapper。
8. 反作弊条款：不得通过手工动画 clip、根节点滑行、lab-only 私有逻辑或 species-only 隐藏状态来假装通过。

## Files

- Create: `docs/prd/PRD-0026-arthropod-crawler-locomotion-labs.md`
- Create: `docs/plans/2026-03-23-v39-arthropod-crawler-locomotion-plan.md`
- Create: `docs/plan/v39-index.md`
- Create: `docs/plan/v39-arthropod-crawler-locomotion-labs.md`
- Create: `docs/research/2026-03-23-spider-lobster-procedural-gait-research.md`
- Create: `city_game/world/creatures/arthropods/CityArthropodLocomotionProfile.gd`
- Create: `city_game/world/creatures/arthropods/CityArthropodLegRuntime.gd`
- Create: `city_game/world/creatures/arthropods/CityArthropodFootholdResolver.gd`
- Create: `city_game/world/creatures/arthropods/CityArthropodBodySolver.gd`
- Create: `city_game/world/creatures/arthropods/CityArthropodCrawlerRuntime.gd`
- Create: `city_game/world/creatures/arthropods/CitySpiderCrawler.tscn`
- Create: `city_game/world/creatures/arthropods/CitySpiderCrawler.gd`
- Create: `city_game/world/creatures/arthropods/CityLobsterCrawler.tscn`
- Create: `city_game/world/creatures/arthropods/CityLobsterCrawler.gd`
- Create: `city_game/scenes/labs/SpiderCrawlerLab.tscn`
- Create: `city_game/scenes/labs/SpiderCrawlerLab.gd`
- Create: `city_game/scenes/labs/LobsterCrawlerLab.tscn`
- Create: `city_game/scenes/labs/LobsterCrawlerLab.gd`
- Create: `tests/world/test_arthropod_crawler_shared_spine_contract.gd`
- Create: `tests/world/test_spider_crawler_lab_scene_contract.gd`
- Create: `tests/world/test_spider_crawler_gait_contract.gd`
- Create: `tests/world/test_spider_crawler_terrain_follow_contract.gd`
- Create: `tests/world/test_lobster_crawler_lab_scene_contract.gd`
- Create: `tests/world/test_lobster_crawler_metachronal_gait_contract.gd`
- Create: `tests/world/test_lobster_crawler_shared_runtime_contract.gd`
- Create: `tests/world/test_arthropod_crawler_portability_contract.gd`
- Create: `tests/e2e/test_spider_crawler_lab_flow.gd`
- Create: `tests/e2e/test_lobster_crawler_lab_flow.gd`

## Steps

1. Analysis
   - 固定“shared spine 是资产，species wrapper 是 consumer”的总口径。
   - 固定“先蜘蛛、后龙虾、暂不接主世界”的版本边界。
2. Docs Freeze
   - 写 `PRD-0026`
   - 写 research
   - 写 `v39-index`
   - 写本计划文档
3. TDD Red: Shared Spine
   - 先写 shared runtime contract test，锁定 profile/debug schema。
4. TDD Green: Shared Spine
   - 落 `profile + per-leg state + foothold resolver + body solver + debug state`
5. TDD Red: Spider Lab Scene
   - 写 Spider lab scene contract test。
6. TDD Green: Spider Lab Scene
   - 落 `SpiderCrawlerLab.tscn`
   - author 地面、坡面、低台阶、窄梁
   - 接 crawler root 与 HUD/debug root
7. TDD Red: Spider Gait
   - 写 gait contract 与 terrain follow contract。
8. TDD Green: Spider Gait
   - 实现 tetrapod-ish gait、stance 锁脚、局部 replanning、body tilt。
9. TDD Red: Lobster Consumer
   - 写 lobster shared-runtime contract 与 metachronal gait contract。
10. TDD Green: Lobster Consumer
   - 复用 shared spine，落 `LobsterCrawlerLab`
   - 复用 `lobster_02.glb`
11. Portability Freeze
   - 写 future main-world portability contract test。
   - 冻结 wrapper / anchor / resolver 口径，但不接主世界。
12. Focused Verification
   - 跑 shared spine、spider、lobster、portability focused tests。
13. Review
   - 更新 `v39-index` 追溯矩阵。
   - 预留 future verification artifact 入口。

## Risks

- 如果 shared runtime 一开始就写成 spider-only 常量，龙虾阶段一定会逼出第二套系统。
- 如果蜘蛛优先追求 wall-walking，会在尚未稳定脚点 contract 时把复杂度抬太高。
- 如果龙虾只是把蜘蛛 gait 的腿数量和模型换皮，视觉上会立刻失真。
- 如果没有只读 debug state，测试会退回黑盒猜测，很难锁定真正的 gait 回归。
- 如果 future port 契约不先冻结，主世界阶段极易把 lab runtime 和 world runtime 分叉。
