# V38 Index

## 愿景

PRD 入口：[PRD-0025 Lake Leisure And Fishing Foundation](../prd/PRD-0025-lake-leisure-and-fishing-foundation.md)

设计入口：[2026-03-22-v38-lake-leisure-and-fishing-design.md](../plans/2026-03-22-v38-lake-leisure-and-fishing-design.md)

依赖入口：

- [PRD-0012 World Feature Ground Probe And Landmark Overrides](../prd/PRD-0012-world-feature-ground-probe-and-landmark-overrides.md)
- [PRD-0016 Soccer Minigame Venue Foundation](../prd/PRD-0016-soccer-minigame-venue-foundation.md)
- [PRD-0018 Tennis Singles Minigame](../prd/PRD-0018-tennis-singles-minigame.md)
- [PRD-0019 Missile Command Defense Minigame](../prd/PRD-0019-missile-command-defense-minigame.md)
- [v21-index.md](./v21-index.md)
- [v26-index.md](./v26-index.md)
- [v28-index.md](./v28-index.md)
- [v29-index.md](./v29-index.md)

`v38` 的目标，是把 `PRD-0012` 里一直停留在 future note 的 “lake / terrain_region_feature” 正式做成第一条真实 consumer，同时沿现有 `scene_minigame_venue` 主链，把湖岸上的休闲钓鱼规则包装成独立 runtime。用户已经把本版边界说得很清楚：湖不必很大，但应是不规则形状；湖水不必很深，常态约 `10m`、最深处约 `15m`；玩家未来要能跳进湖里看鱼；湖中未来会继续扩展水草和彩蛋；进入这片区域后，行人和 ambient 车辆可以冻结掉；而钓鱼规则则应该像足球/网球/导弹防空一样，继续走正式 minigame 包装。

但这次还多了一个同样关键的流程约束：`v38` 必须像 `v37` 直升机炮艇那样，走 **lab-first -> main-world port**。也就是先把 shared layer `1/2` 做成正式运行时能力，再在独立 `LakeFishingLab.tscn` 里用同样的 shoreline / bathymetry / habitat 真源挖出同样的湖，先把下水观察和 fish school 跑顺；接着再在同一个 lab 里把 fishing minigame 跑通；只有这三层在 lab 里验收无误后，才允许把同一套 `1/2/3` 层正式接回主世界 `chunk_147_181`。这样主世界阶段才是移植，不是第二轮重写。

当前状态：`M0-M5` 已完成，fresh verification 见 [v38-m5-verification-2026-03-22.md](./v38-m5-verification-2026-03-22.md)。

post-closeout bugfix evidence：

- [v38-post-closeout-lake-lab-bugfix-verification-2026-03-22.md](./v38-post-closeout-lake-lab-bugfix-verification-2026-03-22.md)

## 决策冻结

- `lake` 在 `v38` 不走 `scene_landmark`，必须走 `terrain_region_feature`。
- 正式 lake region 冻结为 `region:v38:fishing_lake:chunk_147_181`。
- 正式 fishing venue 冻结为 `venue:v38:lakeside_fishing:chunk_147_181`。
- 锚点冻结为：
  - `chunk_id = chunk_147_181`
  - `chunk_key = (147, 181)`
  - `world_position = (2844.59, 0.00, 11508.18)`
  - `chunk_local_position = (84.59, 0.00, 44.18)`
  - `surface_normal = (0.00, 1.00, 0.00)`
- lake 水位冻结为 `water_level_y_m = 0.0`。
- 深度口径冻结为：
  - 常态深度约 `10m`
  - 最深处约 `15m`
  - 浅岸过渡带约 `0m-3m`
- 湖岸必须是不规则轮廓；不得退回成规则圆坑或矩形坑。
- lake 必须对对应 terrain 做 downward carve override；不得只铺水面。
- fish 未来默认走 school/habitat 驱动的批量表现，不允许一条鱼一个重量级 runtime node 成为默认路线。
- `v38` 必须先交付独立 lab，再做主世界移植。
- lab 与主世界必须共享同一套 `terrain_region_feature / lake / fish / fishing` runtime；只允许 wrapper 和 anchor 不同。
- fishing 继续沿 `scene_minigame_venue` 包装，不把规则塞进 lake region runtime。
- 进入 lake leisure 区域后允许激活 `ambient_simulation_freeze`，但冻结对象仍只包括 `pedestrians + ambient vehicles`。
- `ambient_simulation_freeze` 在 lake leisure 语义下的 release buffer 冻结为 `32.0m`。
- full map pin `icon_id` 冻结为 `fishing`。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | `PRD-0025`、design、`v38-index`、`v38` plan、traceability | 4 份文档全部落地且 `REQ-0025-*` 可追溯 | `rg -n "REQ-0025" docs/prd/PRD-0025-lake-leisure-and-fishing-foundation.md docs/plan/v38-index.md docs/plan/v38-lake-leisure-and-fishing-foundation.md` | done |
| M1 shared layer 1/2 foundation | `terrain_region_feature` registry/runtime、lake manifest/profile、terrain downward carve、水面 page、fish school/runtime | shared lake layers `1/2` 在 engine/world 侧成立，lake basin、水位和 fish school 真源稳定可测 | `tests/world/test_city_terrain_region_feature_registry_runtime.gd`、`tests/world/test_city_lake_region_manifest_contract.gd`、`tests/world/test_city_lake_bathymetry_contract.gd`、`tests/world/test_city_lake_water_surface_contract.gd`、`tests/world/test_city_lake_fish_school_contract.gd` | done |
| M2 lab 湖区验收 | `LakeFishingLab.tscn`、同湖复现、下水观察、fish school 可视 | 独立 lab 场景里复用 shared layer `1/2` 挖出同样的湖；player 可进水并观察 fish school | `tests/world/test_city_lake_lab_scene_contract.gd`、`tests/world/test_city_lake_lab_observer_contract.gd` | done |
| M3 lab 钓鱼 minigame | lab shoreline seat/cast/bite/reset、HUD、freeze | lab 场景里可完成“进点位 -> 坐下 -> 抛竿 -> bite/miss -> reset”最小闭环，并保留 lake leisure freeze | `tests/e2e/test_city_lake_lab_fishing_flow.gd`、`tests/world/test_city_fishing_venue_cast_loop_contract.gd` | done |
| M4 主世界移植与流程验证 | `chunk_147_181` 的正式 lake region + fishing venue、pin、freeze | 主世界复用同一套 lake/fishing runtime，地图 pin、freeze 与完整钓鱼流程成立 | `tests/world/test_city_lake_main_world_port_contract.gd`、`tests/world/test_city_fishing_full_map_pin_contract.gd`、`tests/world/test_city_fishing_venue_ambient_freeze_contract.gd`、`tests/e2e/test_city_lake_fishing_flow.gd` | done |
| M5 regression + profiling | 受影响旧链回归；如触及 terrain/render/HUD/tick，profiling 三件套 | `ground_probe`、soccer、tennis、missile command 关键链继续通过；profiling 三件套 fresh rerun 过线 | [v38-m5-verification-2026-03-22.md](./v38-m5-verification-2026-03-22.md) | done |

## 计划索引

- [v38-lake-leisure-and-fishing-foundation.md](./v38-lake-leisure-and-fishing-foundation.md)
- [v38-m5-verification-2026-03-22.md](./v38-m5-verification-2026-03-22.md)
- [v38-post-closeout-lake-lab-bugfix-verification-2026-03-22.md](./v38-post-closeout-lake-lab-bugfix-verification-2026-03-22.md)

## 追溯矩阵

| Req ID | v38 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0025-001 | `v38-lake-leisure-and-fishing-foundation.md` | `tests/world/test_city_terrain_region_feature_registry_runtime.gd`、`tests/world/test_city_lake_region_manifest_contract.gd` | `--script res://tests/world/test_city_lake_region_manifest_contract.gd` | [v38-m5-verification-2026-03-22.md](./v38-m5-verification-2026-03-22.md) | done |
| REQ-0025-002 | `v38-lake-leisure-and-fishing-foundation.md` | `tests/world/test_city_lake_bathymetry_contract.gd`、`tests/world/test_city_lake_water_surface_contract.gd` | `--script res://tests/world/test_city_lake_water_surface_contract.gd` | [v38-m5-verification-2026-03-22.md](./v38-m5-verification-2026-03-22.md) | done |
| REQ-0025-003 | `v38-lake-leisure-and-fishing-foundation.md` | `tests/world/test_city_lake_fish_school_contract.gd`、`tests/world/test_city_lake_swim_observer_contract.gd` | `--script res://tests/world/test_city_lake_swim_observer_contract.gd` | [v38-m5-verification-2026-03-22.md](./v38-m5-verification-2026-03-22.md) | done |
| REQ-0025-004 | `v38-lake-leisure-and-fishing-foundation.md` | `tests/world/test_city_lake_lab_scene_contract.gd`、`tests/world/test_city_lake_lab_observer_contract.gd` | `tests/e2e/test_city_lake_lab_fishing_flow.gd` | [v38-m5-verification-2026-03-22.md](./v38-m5-verification-2026-03-22.md) | done |
| REQ-0025-005 | `v38-lake-leisure-and-fishing-foundation.md` | `tests/world/test_city_fishing_minigame_venue_manifest_contract.gd`、`tests/world/test_city_fishing_venue_cast_loop_contract.gd`、`tests/world/test_city_fishing_full_map_pin_contract.gd`、`tests/world/test_city_lake_main_world_port_contract.gd` | `tests/e2e/test_city_lake_lab_fishing_flow.gd`、`tests/e2e/test_city_lake_fishing_flow.gd` | [v38-m5-verification-2026-03-22.md](./v38-m5-verification-2026-03-22.md) | done |
| REQ-0025-006 | `v38-lake-leisure-and-fishing-foundation.md` | `tests/world/test_city_fishing_venue_ambient_freeze_contract.gd`、`tests/world/test_city_fishing_venue_reset_on_exit_contract.gd` | `--script res://tests/e2e/test_city_lake_fishing_flow.gd` | [v38-m5-verification-2026-03-22.md](./v38-m5-verification-2026-03-22.md) | done |
| REQ-0025-007 | `v38-lake-leisure-and-fishing-foundation.md` | 受影响 `ground_probe`、soccer、tennis、missile command、terrain LOD tests | profiling 三件套 + 受影响回归 | [v38-m5-verification-2026-03-22.md](./v38-m5-verification-2026-03-22.md) | done |

## ECN 索引

- 当前无

## 差异列表

- `v38` 不包含通用河流/海洋系统、船只、水下战斗或复杂流体模拟。
- `v38` 不包含完整鱼类图鉴、天气/昼夜/季节钓鱼系统。
- `v38` 不包含整片湖岸景观园区或完整建筑装饰。
- `v38` 只冻结一座 lake region 与一套 shoreline fishing venue foundation；多钓位、多建筑、多彩蛋内容进入后续版本。
- `v38` 明确要求先 lab 再主世界；不接受跳过 lab 直接 closeout 主世界。
