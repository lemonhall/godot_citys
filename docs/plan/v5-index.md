# V5 Index

## 愿景

PRD 入口：[PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)

research 入口：[2026-03-12-open-world-terrain-road-performance-patterns.md](../research/2026-03-12-open-world-terrain-road-performance-patterns.md)

v5 的目标不是继续修补 v4 的道路表面，而是把 v4 已经建立起来的 surface page / async 管线，向 terrain pipeline 扩展，正式处理当前 `ground_mesh` 第一热点。v5 必须把地形从“per-chunk 重复采样 + 热路径法线重建”的原型实现，升级为“共享规则网格模板 + terrain page cache + 异步准备 + terrain LOD/clipmap-lite 预留”的可持续底盘，并以 `60 FPS = 16.67ms/frame` 作为最终 DoD，而不是建议值。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 地形规则网格模板 | 共享 terrain grid template、唯一顶点采样、退出 triangle-by-triangle 热路径 | `duplication_ratio <= 1.2`；chunk ground 使用共享拓扑/数组契约；`ground_mesh_usec` 较当前基线显著下降 | `test_city_ground_mesh_profile_breakdown.gd`、`test_city_terrain_grid_template.gd`、`test_city_chunk_setup_profile_breakdown.gd` | todo |
| M2 Terrain Page Cache | page 级 height/normal cache、边界复用、cold/warm cache 证据 | 相邻 chunk 可共享 terrain page；revisit 有 cache hit；跨 chunk/page 边界高度/法线连续 | `test_city_terrain_page_contract.gd`、`test_city_terrain_page_runtime_sharing.gd`、`test_city_terrain_page_seam_continuity.gd`、`test_city_chunk_setup_profile_breakdown.gd` | todo |
| M3 Terrain Async Prepare | terrain prepare / commit 拆分，后台线程准备，主线程提交 | 线程不碰 scene tree/GPU；存在 `terrain_async_dispatch/complete/commit` profiling；不得同步伪装异步 | `test_city_terrain_async_pipeline.gd`、`test_city_streaming_profile_stats.gd`、`test_city_runtime_performance_profile.gd` | todo |
| M4 Terrain LOD / Clipmap-Lite | near/mid/far 地形分辨率与 shared page 协同，压低常驻成本 | terrain 至少两档不同分辨率；轮廓、道路覆盖与边界连续；warm traversal `wall_frame_avg_usec <= 16667` | `test_city_terrain_lod_contract.gd`、`test_city_terrain_road_overlay_continuity.gd`、`test_city_runtime_performance_profile.gd` | todo |
| M5 红线收口与回归护栏 | first-visit 与 warm profile 收口，防止 terrain 改造打回路面连续性 | first-visit 与 warm traversal 都守住 `16.67ms/frame`；道路覆盖、可行走地表和 terrain seam 不回退 | `test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd`、`test_city_surface_page_tile_seam_continuity.gd`、`test_city_terrain_road_overlay_continuity.gd` | todo |

## 计划索引

- [v5-terrain-grid-template.md](./v5-terrain-grid-template.md)
- [v5-terrain-page-cache.md](./v5-terrain-page-cache.md)
- [v5-terrain-async-prep.md](./v5-terrain-async-prep.md)
- [v5-terrain-lod.md](./v5-terrain-lod.md)
- [v5-terrain-redline-closeout.md](./v5-terrain-redline-closeout.md)

## 追溯矩阵

| Req ID | v5 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0001-003 | `v5-terrain-page-cache.md`、`v5-terrain-async-prep.md` | `tests/world/test_city_terrain_page_contract.gd`、`tests/world/test_city_terrain_async_pipeline.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | 目标证据：terrain page cache hit/miss、terrain async dispatch/commit 字段 | todo |
| REQ-0001-004 | `v5-terrain-grid-template.md`、`v5-terrain-page-cache.md`、`v5-terrain-lod.md`、`v5-terrain-redline-closeout.md` | `tests/world/test_city_terrain_grid_template.gd`、`tests/world/test_city_terrain_page_seam_continuity.gd`、`tests/world/test_city_terrain_lod_contract.gd`、`tests/world/test_city_terrain_road_overlay_continuity.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | 目标证据：规则网格模板、terrain seam 连续、LOD 连续、道路覆盖不回退 | todo |
| REQ-0001-006 | `v5-terrain-grid-template.md`、`v5-terrain-async-prep.md`、`v5-terrain-lod.md`、`v5-terrain-redline-closeout.md` | `tests/world/test_city_ground_mesh_profile_breakdown.gd`、`tests/world/test_city_streaming_profile_stats.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | 目标证据：`ground_mesh_usec`、`terrain_prepare_usec`、`terrain_commit_usec`、`duplication_ratio`、红线达标 | todo |
| REQ-0001-010 | `v5-terrain-redline-closeout.md` | `tests/world/test_city_terrain_road_overlay_continuity.gd`、`tests/world/test_city_surface_page_tile_seam_continuity.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | 目标证据：terrain 改造后 road surface 仍连续，不通过关闭道路来换性能 | todo |
| REQ-0001-011 | 全部 v5 计划 | `tests/world/test_city_terrain_grid_template.gd`、`tests/world/test_city_terrain_page_runtime_sharing.gd`、`tests/world/test_city_terrain_async_pipeline.gd`、`tests/world/test_city_terrain_lod_contract.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | 目标证据：terrain pipeline 结构化升级完成，并守住红线 | todo |

## ECN 索引

- [ECN-0007-performance-redline-and-road-surface-pipeline.md](../ecn/ECN-0007-performance-redline-and-road-surface-pipeline.md)：把 `16.67ms/frame` 提升为项目级红线，并将 road surface pipeline 性能化纳入 v4。
- [ECN-0008-terrain-streaming-performance-pipeline.md](../ecn/ECN-0008-terrain-streaming-performance-pipeline.md)：将热点从 road surface 扩展到 terrain mesh / page cache / terrain LOD，建立 v5 口径。

## 差异列表

- v4 已完成道路表面的缓存、分层、异步准备与 shared surface page，也已修复 tile seam 路面断裂。
- 当前最新 profiling 仍高于红线：`wall_frame_avg_usec = 28306 ~ 34641`，`streaming_mount_setup_avg_usec = 20051 ~ 25300`。
- 当前第一热点已经变成 `ground_mesh_usec = 17528 ~ 18251`，不再是 `road mask paint`。
- 地形网格诊断显示 `duplication_ratio = 3.408...`，说明 terrain 仍处于重复采样的原型路径。
- 根据 `2026-03-12` research，v5 的正确方向是“规则网格模板 -> page cache -> async -> terrain LOD -> 红线收口”，而不是回退到更重的道路几何。
