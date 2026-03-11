# V4 Road Surface Cache

## Goal

把普通地面道路 surface mask 从“每个 chunk mount 时现算”改成“按签名惰性生成并可复用的缓存资产”，直接切掉静态 chunk 的重复 CPU 重建成本。

## PRD Trace

- REQ-0001-003
- REQ-0001-004
- REQ-0001-006
- REQ-0001-010

## Scope

做什么：

- 为 `road_fill_mask` / `stripe_mask` 建立缓存 key 与 schema version
- 首次生成时落盘缓存，后续优先命中缓存
- 在 profiling 中显式输出 cache hit/miss

不做什么：

- 不在本计划里完成 surface page 共用纹理
- 不在本计划里引入 GPU 计算着色器

## Acceptance

- 同一静态 chunk 第二次 mount 时，不得重复 CPU 全量重建相同 `road mask`。
- 自动化测试至少断言 cache key 稳定、存在 cache hit / miss 证据。
- `test_city_runtime_performance_profile.gd` 中 `streaming_mount_setup_avg_usec` 必须低于本轮基线 `32057`。
- 反作弊条款：不得只缓存 profile 字典而仍在 mount 时重新生成整张 mask。

## Files

- `city_game/world/rendering/CityRoadMaskBuilder.gd`
- `city_game/world/rendering/CityChunkScene.gd`
- `city_game/world/rendering/*RoadSurfaceCache*.gd`
- `tests/world/test_city_road_surface_cache.gd`
- `tests/world/test_city_chunk_setup_profile_breakdown.gd`
- `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 写失败测试（红）
2. 运行到红：`test_city_road_surface_cache.gd`
3. 实现缓存 key / 落盘 / 读取（绿）
4. 运行到绿：`test_city_road_surface_cache.gd` + 相关 breakdown 测试
5. 必要重构：缓存接口与 `CityChunkScene` 解耦
6. E2E：跑 runtime performance profile，复测 mount 平均耗时

## Risks

- 如果 cache key 不包含版本或签名，后续资源演进会读脏缓存。
- 如果缓存落点设计在 scene 节点层，后续异步准备会再次耦合。
