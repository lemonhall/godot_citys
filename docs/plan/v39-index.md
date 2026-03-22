# V39 Index

## 愿景

PRD 入口：[PRD-0026 Arthropod Crawler Locomotion Labs](../prd/PRD-0026-arthropod-crawler-locomotion-labs.md)

设计/实现计划入口：[2026-03-23-v39-arthropod-crawler-locomotion-plan.md](../plans/2026-03-23-v39-arthropod-crawler-locomotion-plan.md)

研究入口：[2026-03-23-spider-lobster-procedural-gait-research.md](../research/2026-03-23-spider-lobster-procedural-gait-research.md)

依赖入口：

- [PRD-0020 Scene Preview Harness](../prd/PRD-0020-scene-preview-harness.md)
- [PRD-0023 Building Collapse Destruction Lab](../prd/PRD-0023-building-collapse-destruction-lab.md)
- [PRD-0024 Helicopter Gunship Encounter](../prd/PRD-0024-helicopter-gunship-encounter.md)
- [PRD-0025 Lake Leisure And Fishing Foundation](../prd/PRD-0025-lake-leisure-and-fishing-foundation.md)
- [v33-index.md](./v33-index.md)
- [v37-index.md](./v37-index.md)
- [v38-index.md](./v38-index.md)

`v39` 的目标不是急着把一只多足生物接进主世界，而是正式建立一条“shared arthropod locomotion spine -> spider lab -> lobster lab -> future main-world portability hooks”的实验主链。首个正式 consumer 冻结为蜘蛛，第二个 consumer 冻结为龙虾；两者都必须以独立 lab 的形式先完成低干扰验收。当前版本明确不接主世界，不做任务、地图 pin、任务圈或生态接入，但要在文档和测试层提前冻结 future port 的契约，确保后续只做 wrapper 接线，不重写 locomotion runtime。

## 决策冻结

- `v39` 先做蜘蛛，再做龙虾。
- `v39` 的真正资产是 shared arthropod locomotion spine，不是单一 spider-only 脚本。
- `v39` 必须先交付独立 lab，再谈主世界移植。
- `v39` 中 lab runtime 与 future main-world runtime 必须保持同一条行为主链；只允许 wrapper 和 anchor 不同。
- 蜘蛛首版冻结为：
  - 地面/坡面/低障碍 crawling
  - 不做 wall/ceiling inversion
- 龙虾首版冻结为：
  - forward crawler
  - metachronal wave preference
  - 不做水下推进与复杂流体
- 蜘蛛首版允许 proxy/blockout rig；不得因缺正式模型而阻塞 gait spine。
- 龙虾视觉首版优先复用：
  - `res://city_game/assets/environment/source/creatures/lobster_02.glb`
- `v39` 首版不做：
  - 主世界正式接入
  - 任务链接入
  - 攻击/敌对 AI
  - 生态系统

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | `PRD-0026`、research、implementation plan、`v39-index`、`v39` plan | 文档链完整，`REQ-0026-*` 可追溯 | `rg -n "REQ-0026|v39" docs/prd/PRD-0026-arthropod-crawler-locomotion-labs.md docs/plan/v39-index.md docs/plan/v39-arthropod-crawler-locomotion-labs.md` | todo |
| M1 shared locomotion spine | profile、per-leg state、foothold resolver、body solver、debug state | shared runtime 可脱离 species scene 被测试消费 | `tests/world/test_arthropod_crawler_shared_spine_contract.gd` | todo |
| M2 spider lab | `SpiderCrawlerLab`、spider wrapper、gait/terrain-follow/reset | 蜘蛛在独立 lab 里走通 gait 与地形跟随闭环 | `tests/world/test_spider_crawler_lab_scene_contract.gd`、`tests/world/test_spider_crawler_gait_contract.gd`、`tests/world/test_spider_crawler_terrain_follow_contract.gd`、`tests/e2e/test_spider_crawler_lab_flow.gd` | todo |
| M3 lobster lab | `LobsterCrawlerLab`、lobster wrapper、metachronal profile | 龙虾作为 shared runtime 第二个 consumer 跑通，且 gait 明显不同于蜘蛛 | `tests/world/test_lobster_crawler_lab_scene_contract.gd`、`tests/world/test_lobster_crawler_metachronal_gait_contract.gd`、`tests/world/test_lobster_crawler_shared_runtime_contract.gd`、`tests/e2e/test_lobster_crawler_lab_flow.gd` | todo |
| M4 future port freeze | portability contract、wrapper 口径、debug passthrough | future main-world port 契约冻结，且不要求实际接入主世界 | `tests/world/test_arthropod_crawler_portability_contract.gd` | todo |

## 计划索引

- [v39-arthropod-crawler-locomotion-labs.md](./v39-arthropod-crawler-locomotion-labs.md)

## 追溯矩阵

| Req ID | V39 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0026-001 | `v39-arthropod-crawler-locomotion-labs.md` | `tests/world/test_arthropod_crawler_shared_spine_contract.gd` | `--script res://tests/world/test_arthropod_crawler_shared_spine_contract.gd` | — | todo |
| REQ-0026-002 | `v39-arthropod-crawler-locomotion-labs.md` | `tests/world/test_spider_crawler_lab_scene_contract.gd` | `tests/e2e/test_spider_crawler_lab_flow.gd` | — | todo |
| REQ-0026-003 | `v39-arthropod-crawler-locomotion-labs.md` | `tests/world/test_spider_crawler_gait_contract.gd`、`tests/world/test_spider_crawler_terrain_follow_contract.gd` | `--script res://tests/world/test_spider_crawler_terrain_follow_contract.gd` | — | todo |
| REQ-0026-004 | `v39-arthropod-crawler-locomotion-labs.md` | `tests/world/test_lobster_crawler_lab_scene_contract.gd`、`tests/world/test_lobster_crawler_metachronal_gait_contract.gd`、`tests/world/test_lobster_crawler_shared_runtime_contract.gd` | `tests/e2e/test_lobster_crawler_lab_flow.gd` | — | todo |
| REQ-0026-005 | `v39-arthropod-crawler-locomotion-labs.md` | `tests/world/test_arthropod_crawler_portability_contract.gd` | `rg -n "future main-world runtime" docs/plan/v39-index.md docs/plan/v39-arthropod-crawler-locomotion-labs.md` | — | todo |
| REQ-0026-006 | `v39-arthropod-crawler-locomotion-labs.md` | 所有 focused tests + future profiling entry | fresh verification 文档 | — | todo |

## Closeout 证据口径

- `v39` 不能只凭手感或录屏宣称“步态成立”。
- `v39` 必须先有 spider lab 和 lobster lab 的 focused evidence，才允许谈 future main-world port。
- `v39` 不接受 spider 和 lobster 各自写一套 locomotion runtime。
- `v39` closeout 后续必须把 fresh rerun 证据落到 `docs/plan/v39-mN-verification-YYYY-MM-DD.md`。

## ECN 索引

- 暂无

## 差异列表

- `v39` 不包含主世界接入。
- `v39` 不包含蜘蛛爬墙/倒挂。
- `v39` 不包含龙虾流体与水下推进。
- `v39` 不包含战斗、任务、任务圈、地图 pin 或生态行为。
