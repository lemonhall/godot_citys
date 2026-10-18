# v63 城市总规生成计划

- **Goal**：用「先地理、后城市、再做建筑」的范式替换 v62 的均匀撒点生成，并在 1km² 垂直切片上证明「想逛」。
- **PRD Trace**：PRD-0034 / REQ-0034-001 ~ REQ-0034-007
- **Cost Profile**：standard（每里程碑最多 3 轮 Review）
- **基线**：v62 已完成；切片外必须保持 v62 行为。

## Scope

### 做

1. `CityPlan` 世界级数据与确定性生成器（地形、水系、历史、路网、轨道、区域、街区、地块、地标）。
2. chunk 侧采样器：用 plan 决定地形高度、水面、区域、地块、建筑时代。
3. 1km² 垂直切片：水岸步道、市场广场、老城窄巷、可上天台地标。
4. E2E 步行验收与性能三件套。
5. Review Loop 与文档回写。

### 不做

- 不做夜景/天气/人流 AI（v64）。
- 不做完整室内装修与任务链。
- 不改作者场景（汉堡店/枪店/咖啡馆/服务建筑/venue）。
- 不改共享导航/任务/地图 contract（只接新地标）。

## 架构

```
CityPlanGenerator (world_seed)
  -> CityPlan { version, seed, plan_hash, terrain, water, history, roads, rail,
                districts, blocks, parcels, landmarks }
  -> CityPlanCache (user://cache/world/city_plan_<seed>.bin)
CityPlanSampler
  -> terrain_height_at(x,z), water_mask_at(x,z), district_at(x,z)
  -> parcels_near(chunk_rect), landmark_at(...)
CityChunkProfileBuilder
  -> 切片内: plan 驱动的区域/地块/时代/地标
  -> 切片外: v62 原路径（fallback）
CityChunkScene
  -> 地形高度来自 plan，水面 mesh/材质，岸线
```

## 里程碑

### M0 文档与门禁

- **Goal**：PRD / ECN / v63 计划 / 追溯矩阵齐全，DoD 与 Doc QA 通过。
- **Acceptance**：
  - `docs/prd/PRD-0034-city-plan-generation.md` 存在且含 7 条 Req ID。
  - `docs/ecn/ECN-0044-city-plan-generation.md` 存在且已同步 PRD。
  - `docs/plan/v63-index.md` 含里程碑、DoD、追溯矩阵、ECN 索引。
  - `tashan_loop stage` 的 `gate_dod` 与 `gate_doc_qa` 均为 pass。
- **验证**：`tashan_loop status` 输出 gates 为 pass。

### M1 确定性总规 + 地形水系

- **Goal**：`CityPlanGenerator` 可复现；地形高度与水面可用。
- **PRD Trace**：REQ-0034-001、REQ-0034-002
- **Scope**：`plan/CityPlanGenerator.gd`、`plan/CityTerrainPlan.gd`、`plan/CityPlanSampler.gd`、`plan/CityPlanCache.gd`。
- **Acceptance（硬）**：
  1. 同 seed 生成两次 `plan_hash` 相等；不同 seed 不相等。
  2. 主河折线 ≥ 3000m，宽度 40~120m。
  3. 切片内水面覆盖 ≥ 2%（按 10m 网格采样）。
  4. `height_at` 除堤岸外相邻 1m 高差 ≤ 2m。
  5. 缓存写入后重新加载，`plan_hash` 不变。
- **TDD Steps**：
  1. 写 `tests/world/test_city_plan_determinism.gd`（红）：断言同 seed 哈希相等、不同 seed 不等、缓存往返一致。
  2. 运行：`& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_plan_determinism.gd'`，预期 FAIL（生成器不存在）。
  3. 实现 `CityPlanGenerator` / `CityPlanCache`，跑到 PASS。
  4. 写 `tests/world/test_city_plan_terrain.gd`（红）：河长/河宽/水面占比/高差连续。
  5. 实现 `CityTerrainPlan` + 采样器，跑到 PASS。
- **Files**：新增 `city_game/world/generation/plan/CityPlanGenerator.gd`、`CityTerrainPlan.gd`、`CityPlanSampler.gd`、`CityPlanCache.gd`；测试两个。
- **Risks**：地形高度与现有 chunk 地形/碰撞耦合；先只在切片内启用，切片外返回 0。

### M2 历史核心 + 路网 + 铁路 + 区域

- **Goal**：城市有核心、轴、铁路与车站，区域由地理派生。
- **PRD Trace**：REQ-0034-003、REQ-0034-004
- **Scope**：`plan/CityHistoryPlan.gd`、`plan/CityRoadPlan.gd`、`plan/CityDistrictPlan.gd`。
- **Acceptance（硬）**：
  1. `history.core` 落在水岸 800m 内。
  2. ≥ 2 条生长轴从核心放射。
  3. 铁路折线闭合，车站 ≥ 3。
  4. 10km 采样窗内每类区域 ≥ 3%（waterfront ≥ 2%）；1km 切片含 waterfront 且 ≥ 2 类。
  5. 道路不穿过水面（水面网格上的路点数为 0）。
- **TDD Steps**：
  1. `tests/world/test_city_plan_history.gd`（红）→ 实现 → 绿。
  2. `tests/world/test_city_plan_roads.gd`（红）→ 实现 → 绿。
  3. `tests/world/test_city_plan_districts.gd`（红）→ 实现 → 绿。
- **Risks**：路网与现有 `CityRoadLayoutBuilder` 冲突；采用「plan 主路 + 现有支路」的混合，支路仍由现有 builder 生成。

### M3 街区与地块语法

- **Goal**：路网切街区，街区按区域语法切地块，产生街墙/巷弄/内院。
- **PRD Trace**：REQ-0034-004
- **Scope**：`plan/CityBlockPlan.gd`、`plan/CityParcelGrammar.gd`。
- **Acceptance（硬）**：
  1. 抽样 100 个临街地块，≥ 70% 立面落在人行道后 8m 内。
  2. oldtown 平均面宽 ≤ 12m；downtown ≥ 24m。
  3. 巷弄宽度 ≥ 4m 且连通到主街（图连通性检查）。
  4. 内院概率与区域配置一致（oldtown ≥ 30%，downtown ≤ 10%）。
- **TDD Steps**：
  1. `tests/world/test_city_plan_parcels.gd`（红）→ 实现 → 绿。
  2. `tests/world/test_city_plan_street_wall.gd`（红）→ 实现 → 绿。
- **Risks**：地块切分与现有建筑落位冲突；切片内走 plan 地块，切片外保持 v62。

### M4 时代建筑语法 + 3 地标 + 可上天台

- **Goal**：建筑按时代生成；3 个地标；地标可进入底层并上到天台。
- **PRD Trace**：REQ-0034-005、REQ-0034-006
- **Scope**：`CityBuildingMassingBuilder` 增加 era 参数；`plan/CityLandmarkPlan.gd`；天台可达的碰撞/楼梯。
- **Acceptance（硬）**：
  1. 抽样 100 栋，≥ 95% 的 era 与区域匹配。
  2. 3 个地标 `landmark_id` 唯一；最高 ≥ 120m。
  3. 非地标建筑收分体量 ≤ 10%。
  4. E2E 可从地面到达地标天台（高度 ≥ 建筑高度 90%）。
- **TDD Steps**：
  1. `tests/world/test_city_plan_era_grammar.gd`（红）→ 实现 → 绿。
  2. `tests/world/test_city_plan_landmarks.gd`（红）→ 实现 → 绿。
  3. `tests/e2e/test_city_plan_slice_roof_access.gd`（红）→ 实现 → 绿。
- **Risks**：天台可达需要新的碰撞/传送/楼梯机制；优先做楼梯 + 传送点兜底。

### M5 1km² 切片 + E2E + 性能 + Review

- **Goal**：切片可步行体验，性能不破，Review 清零。
- **PRD Trace**：REQ-0034-006、REQ-0034-007
- **Scope**：切片区域配置、水面渲染、市场广场、水岸步道、4 点截图 E2E。
- **Acceptance（硬）**：
  1. 4 个路径点（水岸/市场/窄巷/天台）各产出 1 张截图，文件存在且 > 100KB。
  2. `test_city_chunk_setup_profile_breakdown` PASS。
  3. `test_city_first_visit_performance_profile` PASS。
  4. 切片外 `variant_id` 与 v62 基线一致（抽样 10 个 chunk）。
  5. Review 无 open BLOCKER。
- **TDD Steps**：
  1. `tests/e2e/test_city_plan_slice_walkthrough.gd`（红）→ 实现 → 绿。
  2. 性能三件套顺序跑。
  3. `tashan_loop review` 记录。
- **Risks**：水面/岸线渲染开销；先用单平面 + 岸边几何，不做反射。

## 追溯矩阵

| Req ID | 里程碑 | 测试 | 证据 |
| --- | --- | --- | --- |
| REQ-0034-001 | M1 | `test_city_plan_determinism.gd` | TBD |
| REQ-0034-002 | M1 | `test_city_plan_terrain.gd` | TBD |
| REQ-0034-003 | M2 | `test_city_plan_history.gd` | TBD |
| REQ-0034-003 | M2 | `test_city_plan_roads.gd` | TBD |
| REQ-0034-004 | M2 | `test_city_plan_districts.gd` | TBD |
| REQ-0034-004 | M3 | `test_city_plan_parcels.gd`、`test_city_plan_street_wall.gd` | TBD |
| REQ-0034-005 | M4 | `test_city_plan_era_grammar.gd`、`test_city_plan_landmarks.gd` | TBD |
| REQ-0034-006 | M4/M5 | `test_city_plan_slice_roof_access.gd`、`test_city_plan_slice_walkthrough.gd` | TBD |
| REQ-0034-007 | M5 | 性能三件套 + 回退抽样 | TBD |

## 风险汇总

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| 总规与现有 chunk 流式耦合过深 | 高 | 切片开关 + v62 回退，先小范围 |
| 水面/地形渲染开销 | 中 | 单平面水面 + 低模岸线，不做反射 |
| 地块切分导致建筑重叠 | 中 | 复用现有 occupied 检查 + 地块级互斥 |
| 天台可达机制 | 中 | 楼梯优先，传送点兜底 |
| 范围过大导致里程碑滑期 | 高 | 每里程碑独立可验收，M5 前不推广全城 |
