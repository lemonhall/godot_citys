# ECN-0008: Terrain Streaming Performance Pipeline

## 基本信息

- **ECN 编号**：ECN-0008
- **关联 PRD**：PRD-0001
- **关联 Req ID**：REQ-0001-003、REQ-0001-004、REQ-0001-006、新增 REQ-0001-011
- **发现阶段**：v4 收尾后的 profiling / v5 立项
- **日期**：2026-03-12

## 变更原因

v4 已把普通地面道路表面从 per-chunk 主线程重建，推进到了缓存、分层、异步准备和 shared surface page 的路径上，路面断裂问题也已修复。但 fresh profiling 证明项目仍显著高于 `60 FPS = 16.67ms/frame` 红线，主热点已经从 `road mask` 转移到了 `ground_mesh`：

- `wall_frame_avg_usec = 28306 ~ 34641`
- `streaming_mount_setup_avg_usec = 20051 ~ 25300`
- `ground_mesh_usec = 17528 ~ 18251`
- `ground mesh duplication_ratio = 3.408...`

这说明 PRD 当前“道路表面性能专项”的口径已经不够覆盖真实瓶颈。继续把 v5 写成“road surface 后续修补”会直接偏离 profiling 结论，也会让设计图、计划和实现再次脱节。

## 变更内容

### 原设计

- PRD 已将 `16.67ms/frame` 设为项目级红线。
- v4 聚焦普通地面道路表面的缓存、分层、异步和 surface page。
- PRD 尚未把“terrain mesh 必须采用共享规则网格、唯一顶点采样、page 级高度/法线缓存与异步准备”写成明确约束。

### 新设计

- 新增 terrain streaming / ground mesh 性能专项，作为 `v5` 的核心范围。
- 地形几何必须从“per-chunk triangle-by-triangle 重建”升级为“共享规则网格模板 + 唯一顶点采样 + page 级 height/normal cache + main-thread commit”路径。
- terrain 也必须具备 near/mid/far 或等价 clipmap-lite 分层，避免把高分辨率地面几何长时间维持到远景。
- v5 作为独立专项版本，聚焦 terrain pipeline 的模板化、缓存化、异步化、LOD 化和最终红线收口。

## 影响范围

- 受影响的 Req ID：
  - REQ-0001-003
  - REQ-0001-004
  - REQ-0001-006
  - 新增 REQ-0001-011
- 受影响的 vN 计划：
  - `docs/plan/v5-index.md`
  - `docs/plan/v5-terrain-grid-template.md`
  - `docs/plan/v5-terrain-page-cache.md`
  - `docs/plan/v5-terrain-async-prep.md`
  - `docs/plan/v5-terrain-lod.md`
  - `docs/plan/v5-terrain-redline-closeout.md`
- 受影响的测试：
  - `tests/world/test_city_ground_mesh_profile_breakdown.gd`
  - `tests/world/test_city_chunk_setup_profile_breakdown.gd`
  - `tests/e2e/test_city_runtime_performance_profile.gd`
  - 后续 `terrain page / terrain async / terrain LOD` 相关测试
- 受影响的代码文件：
  - `city_game/world/rendering/CityChunkScene.gd`
  - `city_game/world/rendering/CityChunkGroundSampler.gd`
  - 后续 `terrain grid template / terrain page provider / terrain mesh builder` 相关文件

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0008）
- [x] v5 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新
