# V2 Index

## 愿景

PRD 入口：[PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)

v2 的目标不是“把地图表面积做大”，而是把 `godot_citys` 升级为一个真正可扩展的 `70km x 70km` 大城市底盘：世界数据、chunk streaming、渲染降级、连续可 traversable 的 chunk 地表、导航边界、运行时证据和开发态高速巡检入口都必须先成立，后续玩法系统才允许叠加。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 世界数据骨架 | 确定性世界配置、district/road/queryable block/parcel 数据模型 | 固定 seed 下 `70000m x 70000m` 世界与 `256m x 256m` chunk 配置稳定生成；禁止整城节点树常驻；禁止 eager 展开整城 block/parcel | `test_city_world_model.gd`、`test_city_world_generator.gd` | done |
| M2 Chunk Streaming | 玩家驱动的 `5x5` 活跃窗口、后台准备、主线程挂载 | 自动 travel 过程中活跃 chunk 数始终 `<= 25`，chunk 生命周期无重复/漏卸载 | `test_city_chunk_streamer.gd`、`test_city_travel_streaming_flow.gd`、`test_city_fast_inspection_mode.gd` | done |
| M3 渲染降级与地表承托 | chunk-local MultiMesh、profile-driven HLOD、occluder、GroundBody、sky/fog、road skeleton、terrain relief | 至少一种重复资产走 `MultiMeshInstance3D`；近中远三档表现存在且轮廓连续；不同 chunk 存在确定性变体；道路跨 chunk 连续；近景建筑具备碰撞壳；chunk 地表具备轻量高差；离开中心起始区后仍能落在 streamed chunk 地表上；legacy `Ground` 已移除 | `test_city_chunk_renderer.gd`、`test_city_hlod_contract.gd`、`test_city_chunk_variation.gd`、`test_city_visual_environment.gd`、`test_city_road_network_continuity.gd`、`test_city_building_collision.gd`、`test_city_terrain_sampler.gd`、`test_city_chunk_ground_contract.gd`、`test_city_ground_continuity.gd`、`test_city_skeleton_smoke.gd` | done |
| M4 导航、证据与巡检 | chunk nav source、宏观路由、运行时报告、开发态高速巡检模式 | Headless E2E 跨越至少 `2048m` 并输出 `transition_count` / `final_position`；不存在整城单 navmesh 验收路径；`inspection` 模式可接管 streaming | `test_city_navigation_flow.gd`、`test_city_large_world_e2e.gd`、`test_city_fast_inspection_mode.gd` | done |

## 计划索引

- [v2-world-data-model.md](./v2-world-data-model.md)
- [v2-chunk-streaming.md](./v2-chunk-streaming.md)
- [v2-rendering-lod.md](./v2-rendering-lod.md)
- [v2-navigation-e2e.md](./v2-navigation-e2e.md)

## 追溯矩阵

| Req ID | v2 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0001-001 | `v2-world-data-model.md` | `tests/world/test_city_world_model.gd` | `--script res://tests/world/test_city_world_model.gd` | 2026-03-11 本地 headless `PASS`，已验证 `70000m x 70000m` 与 `274 x 274` chunk 网格 | done |
| REQ-0001-002 | `v2-world-data-model.md` | `tests/world/test_city_world_generator.gd` | `--script res://tests/world/test_city_world_generator.gd` | 2026-03-11 本地 headless `PASS`，已验证 `road_graph` world-space 连续道路查询与曲线化 polyline 契约 | done |
| REQ-0001-003 | `v2-chunk-streaming.md` | `tests/world/test_city_chunk_streamer.gd` | `--script res://tests/e2e/test_city_travel_streaming_flow.gd` | 2026-03-11 本地 headless `PASS` | done |
| REQ-0001-004 | `v2-rendering-lod.md` | `tests/world/test_city_chunk_renderer.gd`、`tests/world/test_city_chunk_variation.gd`、`tests/world/test_city_road_network_continuity.gd`、`tests/world/test_city_building_collision.gd`、`tests/world/test_city_terrain_sampler.gd`、`tests/world/test_city_chunk_ground_contract.gd` | `--script res://tests/world/test_city_hlod_contract.gd`、`--script res://tests/e2e/test_city_ground_continuity.gd` | 2026-03-11 本地 headless `PASS`，已验证连续道路骨架、近景建筑碰撞、轻量地形高差与扩大 LOD 半径 | done |
| REQ-0001-005 | `v2-navigation-e2e.md` | `tests/world/test_city_nav_chunks.gd` | `--script res://tests/e2e/test_city_navigation_flow.gd` | 2026-03-11 本地 headless `PASS` | done |
| REQ-0001-006 | `v2-chunk-streaming.md`, `v2-rendering-lod.md`, `v2-navigation-e2e.md` | `tests/world/test_city_debug_overlay.gd`、`tests/world/test_city_visual_environment.gd` | `--script res://tests/e2e/test_city_large_world_e2e.gd` | 2026-03-11 已输出 `CITY_E2E_REPORT`，包含 `current_chunk_id`、`active_chunk_count`、`transition_count`、`final_position`、LOD 统计；WorldEnvironment 已提供 sky/fog | done |
| REQ-0001-007 | `v2-navigation-e2e.md` | `tests/e2e/test_city_large_world_e2e.gd` | `--script res://tests/e2e/test_city_large_world_e2e.gd` | 2026-03-11 本地 headless `PASS`，自动 travel `>= 2048m` | done |
| REQ-0001-008 | `v2-navigation-e2e.md` | `tests/e2e/test_city_fast_inspection_mode.gd` | 手动运行主场景后按 `C` 切换高速巡检模式，使用 `W/S/A/D` + `Shift` 快速预览 | 2026-03-11 本地 headless `PASS`，`inspection` 模式保持 `active_chunk_count <= 25` | done |

验证命令默认使用：

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://<test-path>.gd'
```

## ECN 索引

- [ECN-0001-large-city-scale-and-inspection.md](../ecn/ECN-0001-large-city-scale-and-inspection.md)：将世界尺度从 `7km` 修正为 `70km`，补充 lazy block layout 与连续地表承托；其“巡检车”部分已由 ECN-0002 覆盖。
- [ECN-0002-fast-inspection-mode.md](../ecn/ECN-0002-fast-inspection-mode.md)：删除巡检车与 legacy `Ground`，改为玩家高速巡检模式。
- [ECN-0003-visual-continuity-and-atmosphere.md](../ecn/ECN-0003-visual-continuity-and-atmosphere.md)：补充低成本 sky/fog、同轮廓 HLOD 和按 chunk seed 的视觉变体。
- [ECN-0004-road-network-terrain-and-collision.md](../ecn/ECN-0004-road-network-terrain-and-collision.md)：补充连续道路骨架、轻量地形高差、建筑碰撞与更宽的近景 LOD 半径。

## 差异列表

- v2 已完成 `70km x 70km` 大城市底盘所需的世界数据、streaming、占位地表/渲染、导航验证、运行时证据和开发态高速巡检模式；当前 renderer 已具备连续道路、建筑碰撞、轻量地形和更宽的近景半径，但仍使用占位几何。
- v2 的占位渲染已补到“低成本但连续”：远景天空、HLOD 轮廓和 chunk 变体都已统一，但仍未接入真实美术资产与材质细节。
- 高速巡检模式仅用于开发态人工验收，不代表交通仿真系统已经实现。
- 后续继续留在 v2 的收尾应聚焦真实道路/地表资产、导航烘焙细化和更复杂的视距策略；车辆/行人系统仍未开始。
