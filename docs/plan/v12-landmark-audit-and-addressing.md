# V12 Landmark Audit and Addressing

## Goal

把 `v12` 的数量级、路名规模、地址语法和 AI 候选池规模先冻结，为后续 `Place Index`、route query 和地图 UI 提供不漂移的世界口径。

## PRD Trace

- REQ-0006-001
- REQ-0006-002
- REQ-0006-008

## Scope

做什么：

- 跑出正式 world counts：`roads / intersections / lanes / blocks / parcels / current unique names`
- 新增 `street cluster` 审计逻辑，得到 canonical road-name 数量
- 冻结地址编号语法、intersection 命名规则和 landmark proper-name 策略
- 生成首轮 AI road-name / landmark-name candidate pool 的数量目标

不做什么：

- 不在本计划里完成搜索 UI
- 不在本计划里完成 route planner
- 不在本计划里完成全屏地图或 HUD

## Acceptance

1. 自动化测试必须证明：相同 seed 下能稳定得到 world counts、street cluster counts 和 candidate pool targets。
2. 自动化测试必须证明：同一 street cluster 下多段 road edge 共享同一 canonical road name，而不是 segment 级随机名。
3. 自动化测试必须证明：地址语法保持 deterministic，左右两侧奇偶分离，block 百位推进稳定。
4. 文档必须明确：canonical street cluster 目标数量带宽、AI road-name candidate pool 带宽、landmark proper-name pool 带宽。
5. 反作弊条款：不得通过继续保留 `Reference 00000` / `district_xx_yy Connector` 作为正式产品命名、或只给少量手工样例起名来宣称完成。

## Files

- Modify: `city_game/world/model/CityBlockLayout.gd`
- Create: `city_game/world/model/CityAddressGrammar.gd`
- Create: `city_game/world/generation/CityStreetClusterBuilder.gd`
- Create: `city_game/world/generation/CityNameCandidateCatalog.gd`
- Create: `tests/world/test_city_place_index_world_counts.gd`
- Create: `tests/world/test_city_street_cluster_naming.gd`
- Create: `tests/world/test_city_address_grammar.gd`
- Modify: `docs/plan/v12-index.md`

## Steps

1. 写失败测试（红）
   - 先补 counts/street-cluster/address-grammar 三类测试。
2. 运行到红
   - 预期失败点是当前没有正式 `street_cluster`、没有正式地址语法、仍有占位 road name。
3. 实现（绿）
   - 构建 `street cluster` 审计与 canonical naming grammar。
   - 冻结 block-based address grammar 与 candidate pool 尺度。
4. 运行到绿
   - 新增 tests 全绿。
5. 必要重构（仍绿）
   - 让 naming/address grammar 独立于 UI 与 route consumer。
6. E2E
   - 如需要，补一个 headless audit script 输出 counts 与样例地址快照。

## Risks

- 如果 street name 仍按 raw edge 命名，后续 place query 和 HUD 会持续返工。
- 如果地址主键仍绑在 chunk-local building mesh 上，streaming 一定会打断地址稳定性。
- 如果 AI candidate pool 规模没有先冻结，后面大规模重命名会污染缓存与测试。
