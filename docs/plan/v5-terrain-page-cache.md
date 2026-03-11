# V5 Terrain Page Cache

## Goal

建立 page 级 terrain height/normal cache，让相邻 chunk 共享边界采样结果，并让已访问区域在后续 mount 时不再重复全量采样。

## PRD Trace

- REQ-0001-003
- REQ-0001-004
- REQ-0001-006
- REQ-0001-011

## Scope

做什么：

- 定义 terrain page key、page origin、chunk 到 page 的样本映射
- 缓存 height/normal 数据页或等价共享样本页
- 提供 page contract、runtime sharing 与 seam continuity 测试
- 在 profiling 中输出 terrain page cache hit/miss

不做什么：

- 不在本计划里做 terrain async prepare
- 不在本计划里做最终 LOD/clipmap 分层
- 不在本计划里重写 road surface page

## Acceptance

1. 自动化测试必须断言相邻 chunk 可以解析到稳定的 terrain page key，并共享边界样本。
2. 自动化测试必须断言跨 chunk / page 边界的高度和法线签名连续，不能因为分页缓存重新出现地形 seam。
3. revisit 同一静态 terrain page 时，profiling 必须出现 `terrain_page_cache_hit_count >= 1`，且该 page 不得再次全量采样。
4. 反作弊条款：不得通过把整个世界钉死在单一 page、禁用 streaming、或直接复用旧 mesh 不更新可见区域来伪造 cache 命中。

## Files

- Create: `city_game/world/rendering/CityTerrainPageLayout.gd`
- Create: `city_game/world/rendering/CityTerrainPageProvider.gd`
- Modify: `city_game/world/rendering/CityChunkGroundSampler.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Create: `tests/world/test_city_terrain_page_contract.gd`
- Create: `tests/world/test_city_terrain_page_runtime_sharing.gd`
- Create: `tests/world/test_city_terrain_page_seam_continuity.gd`
- Modify: `tests/world/test_city_chunk_setup_profile_breakdown.gd`

## Steps

1. 写失败测试（红）
   - `test_city_terrain_page_contract.gd` 断言 terrain page key、origin 和 chunk 映射存在。
   - `test_city_terrain_page_runtime_sharing.gd` 断言相邻 chunk 共享同一 terrain page 数据源。
   - `test_city_terrain_page_seam_continuity.gd` 断言跨 page seam 的高度/法线连续。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是 terrain 仍按 chunk 本地独立采样。
3. 实现（绿）
   - 引入 terrain page provider 与缓存签名。
   - 让 chunk ground 从 page 样本页取唯一顶点高度/法线。
4. 跑到绿
   - page contract / runtime sharing / seam continuity 测试全部 PASS。
5. 必要重构（仍绿）
   - 稳定 page cache key 与 version/signature 规则。
6. E2E 测试
   - 在 runtime profile 中确认 revisit 场景出现 terrain cache hit，且 chunk 边界不出现新 seam。

## Risks

- terrain page 边界如果没有预留共享边/halo 样本，法线连续性会比高度连续性更难处理。
- 如果 page signature 漂移，缓存收益会被随机种子和参数抖动吃掉。
