# V4 Index

## 愿景

PRD 入口：[PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)

v4 的目标不是继续给城市“加内容”，而是把已经落地的 v3 世界压回 `60 FPS = 16.67ms/frame` 这条红线附近。v4 必须把普通地面道路从“每个 chunk mount 时主线程现算一遍 surface mask”的原型式实现，升级成带缓存、带分层、带异步准备、并为长期分页表面体系预留架构的性能化管线。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 道路表面缓存 | chunk road surface mask 磁盘缓存，key 绑定签名/version | 已访问过的静态 chunk 不再重复 CPU 重建 road mask；存在 cache hit/miss 证据输出 | `test_city_road_surface_cache.gd`、`test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd` | done |
| M2 路面细节分层 | `far/mid/near` 路面细节分层，远中景禁用或降级 stripe | `mid/far` chunk 不再支付完整 stripe 成本；道路轮廓连续，近景仍保留细节 | `test_city_road_surface_lod.gd`、`test_city_ground_road_overlay_material.gd`、`test_city_runtime_performance_profile.gd` | done |
| M3 异步数据准备 | CPU byte mask 异步准备，主线程仅做资源提交 | road surface 的 byte mask/cache 读写进入后台线程；主线程只做纹理提交与材质绑定；具备 async dispatch/complete/commit profiling | `test_city_road_surface_async_pipeline.gd`、`test_city_runtime_performance_profile.gd` | done |
| M4 Shared Surface Page | 把 per-chunk mask 升级成多 chunk 共用 surface page | 同一 page 内相邻 chunk 共享一张 road/stripe texture，并用 UV 子区块采样；page contract 与 runtime sharing 都有自动化验证 | `test_city_surface_page_contract.gd`、`test_city_surface_page_runtime_sharing.gd` | done |

## 计划索引

- [v4-road-surface-cache.md](./v4-road-surface-cache.md)
- [v4-road-surface-lod.md](./v4-road-surface-lod.md)
- [v4-road-surface-async.md](./v4-road-surface-async.md)
- [v4-surface-page-architecture.md](./v4-surface-page-architecture.md)

## 追溯矩阵

| Req ID | v4 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0001-003 | `v4-road-surface-cache.md`、`v4-road-surface-async.md` | `tests/world/test_city_road_surface_cache.gd`、`tests/world/test_city_road_surface_async_pipeline.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | M3 已落地 async pending set、主线程 texture commit 与 profiling 字段；E2E 已通过 | done |
| REQ-0001-004 | `v4-road-surface-cache.md`、`v4-road-surface-lod.md`、`v4-surface-page-architecture.md` | `tests/world/test_city_ground_road_overlay_material.gd`、`tests/world/test_city_road_surface_lod.gd`、`tests/world/test_city_surface_page_contract.gd`、`tests/world/test_city_surface_page_runtime_sharing.gd` | `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd` | M4 已落地 shared page runtime；同 page 相邻 chunk 共享 road/stripe texture，按 UV 子区块采样 | done |
| REQ-0001-006 | `v4-road-surface-cache.md`、`v4-road-surface-lod.md`、`v4-road-surface-async.md`、`v4-surface-page-architecture.md` | `tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/world/test_city_road_mask_profile_breakdown.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | 结构性升级已落地，但当前 `wall_frame_avg_usec = 28915`，仍高于 `16.67ms` 红线；M5 负责继续处理 surface 覆盖质量与后续性能压缩 | in progress |
| REQ-0001-010 | 全部 v4 计划 | `tests/world/test_city_road_surface_cache.gd`、`tests/world/test_city_road_surface_lod.gd`、`tests/world/test_city_surface_page_contract.gd`、`tests/world/test_city_surface_page_runtime_sharing.gd`、`tests/world/test_city_road_surface_async_pipeline.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | ECN-0007 的 pipeline 侧要求已落地；项目级红线仍待后续性能专项继续兑现 | in progress |

## ECN 索引

- [ECN-0007-performance-redline-and-road-surface-pipeline.md](../ecn/ECN-0007-performance-redline-and-road-surface-pipeline.md)：把 `16.67ms/frame` 提升为项目级红线，并将 road surface pipeline 性能化纳入 v4。

## 差异列表

- `M3` 已把 road surface data prep 拆成 `async prepare -> main-thread commit` 两段，thread 不再直接触碰 scene tree / GPU 资源。
- `M4` 已把道路地表升级成 runtime shared surface page，同一 page 内 chunk 共用 road/stripe texture，并通过 `surface_uv_offset/surface_uv_scale` 采样子区块。
- 当前 E2E runtime profile 为 `wall_frame_avg_usec = 28915`、`streaming_mount_setup_avg_usec = 20928`、`streaming_prepare_profile_avg_usec = 9853`，仍明显高于 `16.67ms/frame` 红线。
- 下一优先级不再是补 M3/M4 的结构，而是 `M5`：继续处理 surface 覆盖连续性与 page 请求/首次访问成本。
