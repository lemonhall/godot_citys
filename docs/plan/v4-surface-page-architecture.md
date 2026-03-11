# V4 Surface Page Architecture

## Goal

为未来的 RVT-lite / clipmap 风格道路地表体系预留结构，把“每 chunk 一张独立 mask”的数据接口升级成“可多 chunk 共用 surface page”的 contract。

## 实现状态

已从“contract 预留”升级为“可运行的 shared page lite 版本”：

- `CityRoadSurfacePageLayout.gd` 继续负责 page key、origin chunk、UV 子区块映射。
- 新增 `CityRoadSurfacePageProvider.gd`，负责 page request、page cache signature、runtime texture sharing。
- page 纹理现在以 `shared page -> per-chunk uv_rect` 的方式复用，同一 page 内相邻 chunk 不再各自持有独立 road/stripe texture。
- shader 新增 `surface_uv_offset` 与 `surface_uv_scale`，chunk 只采样自身 page tile。

## PRD Trace

- REQ-0001-004
- REQ-0001-010

## Scope

做什么：

- 定义 surface page 概念、page key、page size、chunk 到 page 的 UV 子区域映射
- 提供最小 contract 和测试，允许后续把 per-chunk 缓存平滑迁移到 per-page 缓存

不做什么：

- 不在本计划里完成完整的 RVT / clipmap 实现
- 不在本计划里重写整条道路渲染链

## Acceptance

- 存在明确的 `surface page contract`，能表达一个或多个 chunk 共享道路表面数据来源。
- 自动化测试至少断言 chunk 可解析出 page key 和子区域映射。
- 反作弊条款：不得只在文档里画概念图而没有代码 contract 或测试。

当前额外已满足：

- 相邻同 page chunk 的 runtime material 共享同一张 road mask texture。
- 不同 chunk 通过不同 `uv_rect` / `surface_uv_offset` 采样 page 的不同子区域。

## Files

- `city_game/world/rendering/*SurfacePage*.gd`
- `tests/world/test_city_surface_page_contract.gd`
- `tests/world/test_city_surface_page_runtime_sharing.gd`

## Steps

1. 写失败测试（红）
2. 运行到红：`test_city_surface_page_contract.gd`
3. 实现 contract（绿）
4. 运行到绿：surface page contract 测试
5. 必要重构：把 per-chunk cache key 与 page key 的关系稳定下来
6. E2E：本计划无需单独 E2E，作为后续分页渲染前置条件

## Risks

- 如果 page contract 与当前 chunk LOD / cache 签名脱节，后续迁移会二次返工。
- 如果现在就试图一步到位做完 clipmap，风险和工程量都会失控。

## Evidence

- `tests/world/test_city_surface_page_contract.gd`
- `tests/world/test_city_surface_page_runtime_sharing.gd`
- `tests/world/test_city_ground_road_overlay_material.gd`
