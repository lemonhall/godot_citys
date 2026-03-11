# V4 Surface Page Architecture

## Goal

为未来的 RVT-lite / clipmap 风格道路地表体系预留结构，把“每 chunk 一张独立 mask”的数据接口升级成“可多 chunk 共用 surface page”的 contract。

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

## Files

- `city_game/world/rendering/*SurfacePage*.gd`
- `tests/world/test_city_surface_page_contract.gd`

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
