# ECN-0044: 城市生成从「沿路撒建筑」改为「总规驱动」

## 基本信息

- **ECN 编号**：ECN-0044
- **关联 PRD**：PRD-0034
- **关联 Req ID**：REQ-0034-001 ~ REQ-0034-007（新增）
- **发现阶段**：v62 收尾后的用户验收
- **日期**：2026-10-19

## 变更原因

v62 完成了建筑单体、材质、街道家具与区域调色，但用户验收结论是「平平无奇、没有欲望逛下去」。复盘确认：问题不在单体精度，而在生成范式——

- 没有地理因果（河/海/山/铁路），城市是均匀撒出来的；
- 只有路径，没有边缘/节点/地标；
- 地块语法全城一套，没有时间层；
- 没有可进入/可攀爬/可发现的内容。

继续在 v62 上调细节无法解决，需要一次生成范式的范围变更。

## 变更内容

### 原设计

`CityChunkProfileBuilder` 以 chunk 为单位：按路网撒临街候选点，用哈希选区域/体量/颜色，地形为平地，街区与地块不存在。

### 新设计

新增世界级 `CityPlan`：

1. 地形与水系（河/海岸/缓丘/湿地）；
2. 历史核心与生长轴（老城、主街、铁路与车站）；
3. 路网与轨道（老城不规则网 + 新区网格 + 环线铁路）；
4. 街区与地块（按区域语法细分，产生街墙/巷弄/内院）；
5. 建筑时代语法与 3 个地标（只有地标允许收分）。

落地方式：先做 1km² 垂直切片（水岸 + 市场广场 + 老城窄巷 + 可上天台地标），切片外回退 v62；验证通过后再推广全城。

## 影响范围

- 受影响的 Req ID：新增 REQ-0034-001 ~ 007。
- 受影响的 vN 计划：新增 `docs/plan/v63-index.md`、`docs/plan/v63-city-plan-generator.md`。
- 受影响的测试：新增 `tests/world/test_city_plan_*.gd`、`tests/e2e/test_city_plan_slice_walkthrough.gd`；复用 chunk setup / first-visit 性能测试。
- 受影响的代码文件：
  - 新增 `city_game/world/generation/plan/*`
  - 修改 `city_game/world/rendering/CityChunkProfileBuilder.gd`
  - 修改 `city_game/world/rendering/CityChunkScene.gd`（地形/水面）
  - 修改 `city_game/world/generation/CityDistrictCharacter.gd`（由 plan 驱动）

## 处置方式

- [x] PRD 已同步更新（PRD-0034）
- [x] vN 计划已同步更新（v63）
- [ ] 追溯矩阵已同步更新（v63-index）
- [ ] 相关测试已同步更新（M1 开始）
