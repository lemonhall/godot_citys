# V2 Navigation E2E

## Goal

让大城市底盘具备可验证的跨 chunk 连续移动能力，用自动化 E2E 证明世界生成、streaming、渲染和导航没有断链。

## PRD Trace

- REQ-0001-005
- REQ-0001-006
- REQ-0001-007
- REQ-0001-008

## Scope

做什么：

- 建立 chunk-local 导航源数据或 navmesh 构造
- 建立 district / road graph 宏观路径接口
- 建立 headless E2E travel 测试，覆盖至少 `2048m` 路径
- 建立开发态高速巡检模式与可切换控制模式
- 输出稳定的运行时报告，供 trace matrix 和人工 review 引用

不做什么：

- 不做人群避障
- 不做车辆 lane graph
- 不做完整任务系统 E2E

## Acceptance

1. 自动化测试断言角色可跨越至少两个相邻 chunk，并保持导航连续。
2. headless E2E 自动 travel 距离至少 `2048m`，最终输出 `PASS`。
3. E2E 日志必须包含 chunk 迁移证据、最终位置和活跃 chunk 统计。
4. 自动化测试断言场景中不存在 `InspectionCar` 与 legacy `Ground`，可切换到高速巡检模式，且切换后 streaming 护栏仍成立。
5. 反作弊条款：不得使用整城单 navmesh 文件、只检查 instantiate、保留旧 `Ground` 混合承托，或“直接瞬移到终点就算通过”来宣称 travel 流程通过。

## Files

- Create: `city_game/world/navigation/CityMacroRouteGraph.gd`
- Create: `city_game/world/navigation/CityChunkNavBuilder.gd`
- Create: `city_game/world/navigation/CityChunkNavRuntime.gd`
- Create: `tests/world/test_city_nav_chunks.gd`
- Create: `tests/e2e/test_city_navigation_flow.gd`
- Create: `tests/e2e/test_city_large_world_e2e.gd`
- Create: `tests/e2e/test_city_fast_inspection_mode.gd`
- Modify: `city_game/world/streaming/CityChunkStreamer.gd`
- Modify: `city_game/scripts/PlayerController.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/scenes/CityPrototype.tscn`

## Steps

1. 写失败测试（红）
   - `test_city_nav_chunks.gd` 断言相邻 chunk 的导航边界可以连通。
   - `test_city_navigation_flow.gd` 断言宏观路径可拆解为 chunk 级移动目标。
   - `test_city_large_world_e2e.gd` 自动驱动玩家走完至少 `2048m` 路径，并输出运行时报告。
   - `test_city_fast_inspection_mode.gd` 断言高速巡检模式可接管 streaming。
2. 跑到红
   - 运行上述三个测试脚本，预期 FAIL，原因是 nav builder / macro route / e2e harness 尚不存在。
3. 实现（绿）
   - 构建 chunk nav source 和宏观路由接口。
   - 让 E2E harness 能自动推动玩家沿路线跨 chunk 行进，并持续读取 debug 输出。
   - 增加开发态高速巡检模式，并允许玩家切换速度档。
   - 增加稳定的 `build_runtime_report()` 输出。
4. 跑到绿
   - nav 测试、fast inspection mode 与 large world E2E 均输出 `PASS`。
5. 必要重构（仍绿）
   - 统一 E2E 输出格式，方便后续纳入 traceability matrix 证据。
6. E2E 测试
   - 以 `test_city_large_world_e2e.gd` 作为 v2 里程碑总验收。

## Risks

- 如果导航接口直接依赖视觉网格，后续 chunk 烘焙和线程化会变得很重。
- 如果 E2E harness 只验证 instantiate，不验证真实 travel，就会重新落回“假通过”。
- 如果没有开发态高速巡检模式，人工验证 streaming / ground / HUD 的效率会很差。
