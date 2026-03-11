# V2 Index

## 愿景

PRD 入口：[PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)

v2 的目标不是“把地图表面积做大”，而是把 `godot_citys` 升级为一个真正可扩展的 `70km x 70km` 大城市底盘：世界数据、chunk streaming、渲染降级、连续可 traversable 的 chunk 地表、导航边界、运行时证据和开发态巡检入口都必须先成立，后续玩法系统才允许叠加。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 世界数据骨架 | 确定性世界配置、district/road/queryable block/parcel 数据模型 | 固定 seed 下 `70000m x 70000m` 世界与 `256m x 256m` chunk 配置稳定生成；禁止整城节点树常驻；禁止 eager 展开整城 block/parcel | `test_city_world_model.gd`、`test_city_world_generator.gd` | done |
| M2 Chunk Streaming | 玩家/巡检车驱动的 `5x5` 活跃窗口、后台准备、主线程挂载 | 自动 travel / drive 过程中活跃 chunk 数始终 `<= 25`，chunk 生命周期无重复/漏卸载 | `test_city_chunk_streamer.gd`、`test_city_travel_streaming_flow.gd`、`test_city_vehicle_inspection_mode.gd` | done |
| M3 渲染降级与地表承托 | chunk-local MultiMesh、HLOD、occluder、GroundBody | 至少一种重复资产走 `MultiMeshInstance3D`；近中远三档表现存在；离开中心起始区后仍能落在 streamed chunk 地表上 | `test_city_chunk_renderer.gd`、`test_city_hlod_contract.gd`、`test_city_chunk_ground_contract.gd`、`test_city_ground_continuity.gd` | done |
| M4 导航、证据与巡检 | chunk nav source、宏观路由、运行时报告、开发态巡检车 | Headless E2E 跨越至少 `2048m` 并输出 `transition_count` / `final_position`；不存在整城单 navmesh 验收路径；巡检车可接管 streaming | `test_city_navigation_flow.gd`、`test_city_large_world_e2e.gd`、`test_city_vehicle_inspection_mode.gd` | done |

## 计划索引

- [v2-world-data-model.md](./v2-world-data-model.md)
- [v2-chunk-streaming.md](./v2-chunk-streaming.md)
- [v2-rendering-lod.md](./v2-rendering-lod.md)
- [v2-navigation-e2e.md](./v2-navigation-e2e.md)

## 追溯矩阵

| Req ID | v2 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0001-001 | `v2-world-data-model.md` | `tests/world/test_city_world_model.gd` | `--script res://tests/world/test_city_world_model.gd` | 2026-03-11 本地 headless `PASS`，已验证 `70000m x 70000m` 与 `274 x 274` chunk 网格 | done |
| REQ-0001-002 | `v2-world-data-model.md` | `tests/world/test_city_world_generator.gd` | `--script res://tests/world/test_city_world_generator.gd` | 2026-03-11 本地 headless `PASS`，已验证 lazy `get_blocks_for_chunk()` 契约与完整 block / parcel 统计 | done |
| REQ-0001-003 | `v2-chunk-streaming.md` | `tests/world/test_city_chunk_streamer.gd` | `--script res://tests/e2e/test_city_travel_streaming_flow.gd` | 2026-03-11 本地 headless `PASS` | done |
| REQ-0001-004 | `v2-rendering-lod.md` | `tests/world/test_city_chunk_renderer.gd`、`tests/world/test_city_chunk_ground_contract.gd` | `--script res://tests/world/test_city_hlod_contract.gd`、`--script res://tests/e2e/test_city_ground_continuity.gd` | 2026-03-11 本地 headless `PASS`，已验证 chunk 地表与碰撞承托 | done |
| REQ-0001-005 | `v2-navigation-e2e.md` | `tests/world/test_city_nav_chunks.gd` | `--script res://tests/e2e/test_city_navigation_flow.gd` | 2026-03-11 本地 headless `PASS` | done |
| REQ-0001-006 | `v2-chunk-streaming.md`, `v2-rendering-lod.md`, `v2-navigation-e2e.md` | `tests/world/test_city_debug_overlay.gd` | `--script res://tests/e2e/test_city_large_world_e2e.gd` | 2026-03-11 已输出 `CITY_E2E_REPORT`，包含 `current_chunk_id`、`active_chunk_count`、`transition_count`、`final_position`、LOD 统计 | done |
| REQ-0001-007 | `v2-navigation-e2e.md` | `tests/e2e/test_city_large_world_e2e.gd` | `--script res://tests/e2e/test_city_large_world_e2e.gd` | 2026-03-11 本地 headless `PASS`，自动 travel `>= 2048m` | done |
| REQ-0001-008 | `v2-navigation-e2e.md` | `tests/e2e/test_city_vehicle_inspection_mode.gd` | 手动运行主场景后按 `C` 切换巡检车，使用 `W/S/A/D` + `Shift` 巡检 | 2026-03-11 本地 headless `PASS`，巡检车模式保持 `active_chunk_count <= 25` | done |

验证命令默认使用：

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://<test-path>.gd'
```

## ECN 索引

- [ECN-0001-large-city-scale-and-inspection.md](../ecn/ECN-0001-large-city-scale-and-inspection.md)：将世界尺度从 `7km` 修正为 `70km`，补充 lazy block layout、连续地表与开发态巡检车。

## 差异列表

- v2 已完成 `70km x 70km` 大城市底盘所需的世界数据、streaming、占位地表/渲染、导航验证、运行时证据和开发态巡检车，但 renderer 仍使用占位几何和固定阈值。
- 巡检车仅用于开发态人工验收，不代表交通仿真系统已经实现。
- 后续继续留在 v2 的收尾应聚焦真实道路/地表资产、导航烘焙细化和更复杂的视距策略；车辆/行人系统仍未开始。
