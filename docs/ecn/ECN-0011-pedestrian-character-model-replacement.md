# ECN-0011: Pedestrian Character Model Replacement

## 基本信息

- **ECN 编号**：ECN-0011
- **关联 PRD**：PRD-0002
- **关联 Req ID**：新增 REQ-0002-012
- **发现阶段**：v6 M7 收口后的手玩验收 / 用户反馈
- **日期**：2026-03-13

## 变更原因

`M7` 已经把 pedestrian 的行为层口径拉到 `500m / 4x / 跑满500m`，但当前近景视觉仍然沿用 `BoxMesh` / 竖棍式占位。这样会让行人系统在功能上已经成立、在观感上却仍然非常抽象，用户无法把“人群在逃跑”感知为真实街头事件。

本轮用户已提供 7 个 civilian `glb` 模型，并且每个模型都包含可用于 locomotion 的 `walk` 变种动画；后续核查也确认这些模型都带有可利用的 `death/dead` 片段。既然资产已经具备，继续保留近景占位视觉或让 casualty 继续“命中即无”都不再是“以后再美术化”的合理借口，而是产品级缺口。

## 变更内容

### 原设计

- `REQ-0002-003` 与 `REQ-0002-005` 只要求 tier 表示、budget 和 reactive behavior 成立，没有把“Tier 2 / Tier 3 不能长期停留在抽象占位体”写成正式需求。
- 现有 [CityPedestrianCrowdBatch.gd](../../city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd)、[CityPedestrianCrowdRenderer.gd](../../city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd)、[CityPedestrianReactiveAgent.gd](../../city_game/world/pedestrians/simulation/CityPedestrianReactiveAgent.gd) 仍在用 `BoxMesh` 做 pedestrian 视觉。

### 新设计

- 新增 `REQ-0002-012`：把 pedestrian 近景视觉替换单独立项，要求 `Tier2 + Tier3` 改为真实 civilian character `glb` 模型，不再使用当前盒子/竖棍占位。
- 本轮只替换 `Tier2 + Tier3`，`Tier1` 继续保持轻量 batched representation；除非后续另开 ECN，否则不在 `M8` 里重写 Tier1 的远景群体表示层。
- 用户提供的 7 个 `glb` 统一归档到 `city_game/assets/pedestrians/civilians/`，并落一份 manifest，固定 `idle / walk / run / death` 动画名，避免后续实现阶段靠字符串猜测。
- 由于这 7 个 `glb` 的原始尺寸与根节点脚底偏移不一致，manifest 还必须显式记录逐模型 `source_height_m / source_ground_offset_m`，把所有近景 civilian 统一归一化到 pedestrian `height_m` 与贴地契约，而不是依赖单一全局缩放常数。
- 已被 projectile / explosion 判定为死亡的近景 pedestrian，会通过短暂 death visual 播放 `death/dead` clip，同时 live crowd roster 仍按 `REQ-0002-009` 口径移除，不把尸体残留升级成新的常驻高成本 agent。
- `v6` 新开 `M8`，专门承载“真实路人模型替换近景占位视觉”这一轮收口。

## 影响范围

- 受影响的 Req ID：
  - 新增 REQ-0002-012
- 受影响的 vN 计划：
  - `docs/plan/v6-index.md`
  - `docs/plan/v6-pedestrian-character-model-replacement.md`
- 受影响的测试：
  - `tests/world/test_city_pedestrian_character_asset_manifest.gd`
  - `tests/world/test_city_pedestrian_character_scale_normalization.gd`
  - `tests/world/test_city_pedestrian_tier2_visual_instances.gd`
  - `tests/world/test_city_pedestrian_tier3_visual_instances.gd`
  - `tests/e2e/test_city_pedestrian_character_visual_presence.gd`
  - `tests/e2e/test_city_pedestrian_performance_profile.gd`
  - `tests/e2e/test_city_runtime_performance_profile.gd`
- 受影响的代码文件：
  - `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianReactiveAgent.gd`
  - `city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd`（仅在 M8 确认是否需要 minimal silhouette 调整时触及）
  - `city_game/assets/pedestrians/civilians/pedestrian_model_manifest.json`
  - 以及后续 `pedestrian visual catalog / animation routing` 相关文件

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0011）
- [x] v6 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新
