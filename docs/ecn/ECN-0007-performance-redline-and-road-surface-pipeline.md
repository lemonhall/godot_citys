# ECN-0007: Performance Redline and Road Surface Pipeline

## 基本信息

- **ECN 编号**：ECN-0007
- **关联 PRD**：PRD-0001
- **关联 Req ID**：REQ-0001-003、REQ-0001-004、REQ-0001-006、新增 REQ-0001-010
- **发现阶段**：v3 收尾后的 profiling / v4 立项
- **日期**：2026-03-12

## 变更原因

v3 已经完成参考式道路图、小地图与导航，但 fresh profiling 证明项目虽然已经从约 `72ms/frame` 压到约 `31ms/frame`，仍显著高于 `60 FPS = 16.67ms/frame` 的产品级红线。当前最大热点稳定落在 `chunk mount setup -> ground material -> road surface mask CPU paint`。

这说明此前 PRD 对性能与运行时观测的要求还不够具体：它约束了“要有 profiling 输出”，但没有把 `16.67ms/frame` 提升为项目级红线，也没有把“静态道路表面不得在每次 chunk mount 时主线程全量重建”写成明确约束。

## 变更内容

### 原设计

- PRD 只要求提供运行时观测与性能护栏。
- 道路表面可以通过当前 terrain overlay + per-chunk mask 方式实现，但没有规定缓存、分层和异步准备的硬约束。

### 新设计

- 将 `60 FPS = 16.67ms/frame` 明确提升为项目级性能红线。
- 新增道路表面性能专项要求：静态道路表面必须支持缓存、距离分层和异步数据准备，避免每次 chunk mount 在主线程全量重建。
- `v4` 作为独立专项版本，聚焦 road surface pipeline 的缓存、分层、异步和长期 surface page 架构预留。

## 影响范围

- 受影响的 Req ID：
  - REQ-0001-003
  - REQ-0001-004
  - REQ-0001-006
  - 新增 REQ-0001-010
- 受影响的 vN 计划：
  - `docs/plan/v4-index.md`
  - `docs/plan/v4-road-surface-cache.md`
  - `docs/plan/v4-road-surface-lod.md`
  - `docs/plan/v4-road-surface-async.md`
  - `docs/plan/v4-surface-page-architecture.md`
- 受影响的测试：
  - `tests/e2e/test_city_runtime_performance_profile.gd`
  - `tests/world/test_city_chunk_setup_profile_breakdown.gd`
  - `tests/world/test_city_road_mask_profile_breakdown.gd`
- 受影响的代码文件：
  - `city_game/world/rendering/CityRoadMaskBuilder.gd`
  - `city_game/world/rendering/CityChunkScene.gd`
  - `city_game/world/rendering/CityChunkRenderer.gd`
  - 后续 `road surface cache / async prep` 相关文件

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0007）
- [x] v4 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新
