# V4 Index

## 愿景

PRD 入口：[PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)

v4 的目标不是继续给城市“加内容”，而是把已经落地的 v3 世界压回 `60 FPS = 16.67ms/frame` 这条红线附近。v4 必须把普通地面道路从“每个 chunk mount 时主线程现算一遍 surface mask”的原型式实现，升级成带缓存、带分层、带异步准备、并为长期分页表面体系预留架构的性能化管线。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 道路表面缓存 | chunk road surface mask 磁盘缓存，key 绑定签名/version | 已访问过的静态 chunk 不再重复 CPU 重建 road mask；存在 cache hit/miss 证据输出 | `test_city_road_surface_cache.gd`、`test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd` | done |
| M2 路面细节分层 | `far/mid/near` 路面细节分层，远中景禁用或降级 stripe | `mid/far` chunk 不再支付完整 stripe 成本；道路轮廓连续，近景仍保留细节 | `test_city_road_surface_lod.gd`、`test_city_ground_road_overlay_material.gd`、`test_city_runtime_performance_profile.gd` | done |
| M3 异步数据准备 | CPU byte mask 异步准备，主线程仅做资源提交 | streaming 尖峰继续下降；不在 scene tree 线程外直接提交 GPU 资源 | `test_city_road_surface_async_pipeline.gd`、`test_city_runtime_performance_profile.gd` | todo |
| M4 Surface Page 预留 | 把 per-chunk mask 结构预留为多 chunk 共用 surface page 的架构接口 | surface page contract 存在，后续可升级到 RVT-lite/clipmap 风格分页表面 | `test_city_surface_page_contract.gd` | done |

## 计划索引

- [v4-road-surface-cache.md](./v4-road-surface-cache.md)
- [v4-road-surface-lod.md](./v4-road-surface-lod.md)
- [v4-road-surface-async.md](./v4-road-surface-async.md)
- [v4-surface-page-architecture.md](./v4-surface-page-architecture.md)

## 追溯矩阵

| Req ID | v4 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0001-003 | `v4-road-surface-cache.md`、`v4-road-surface-async.md` | `tests/world/test_city_road_surface_cache.gd`、`tests/world/test_city_road_surface_async_pipeline.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | `M1` 已落地缓存；`warm steady-state` 下 `streaming_mount_setup_avg_usec = 12249` | in progress |
| REQ-0001-004 | `v4-road-surface-cache.md`、`v4-road-surface-lod.md`、`v4-surface-page-architecture.md` | `tests/world/test_city_ground_road_overlay_material.gd`、`tests/world/test_city_road_surface_lod.gd`、`tests/world/test_city_surface_page_contract.gd` | `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd` | `M2/M4` 已落地；`mid/far` 路面细节已降级，surface page contract 已建立 | in progress |
| REQ-0001-006 | `v4-road-surface-cache.md`、`v4-road-surface-lod.md`、`v4-road-surface-async.md` | `tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/world/test_city_road_mask_profile_breakdown.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | `warm steady-state` 已降至 `wall_frame_avg_usec = 15785`，`M3` 继续负责压冷缓存与尖峰 | in progress |
| REQ-0001-010 | 全部 v4 计划 | `tests/world/test_city_road_surface_cache.gd`、`tests/world/test_city_road_surface_lod.gd`、`tests/world/test_city_surface_page_contract.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | 由 ECN-0007 新增；M1/M2/M4 已有证据，M3 待完成 | in progress |

## ECN 索引

- [ECN-0007-performance-redline-and-road-surface-pipeline.md](../ecn/ECN-0007-performance-redline-and-road-surface-pipeline.md)：把 `16.67ms/frame` 提升为项目级红线，并将 road surface pipeline 性能化纳入 v4。

## 差异列表

- `warm steady-state` 已压到 `15.79ms/frame`，但冷缓存首轮仍明显高于红线。
- `prepare` 已不是主瓶颈；当前剩余第一优先级是 `M3` 异步数据准备，用于继续压冷缓存首轮和 streaming 尖峰。
- 长期仍需要更大跨度的 surface page / RVT-lite 方案，但当前 contract 预留已经完成。
