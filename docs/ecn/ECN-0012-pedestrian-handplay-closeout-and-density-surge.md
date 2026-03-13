# ECN-0012: Pedestrian Hand-Play Closeout And Density Surge

## 基本信息

- **ECN 编号**：ECN-0012
- **关联 PRD**：PRD-0002
- **关联 Req ID**：REQ-0002-010、REQ-0002-011、REQ-0002-012、新增 REQ-0002-013、新增 REQ-0002-014、新增 REQ-0002-015、新增 REQ-0002-016
- **发现阶段**：`v6 M8` 推送后的手玩验收 / 用户反馈
- **日期**：2026-03-13

## 变更原因

`M7/M8` 已经在自动化与 fresh profiling 上收口，但 2026-03-13 的真实手玩反馈继续暴露出 6 组新的产品级问题：

- 7 个 civilian `glb` 的尺寸归一化并不可靠，至少有一个模型会变成“女巨人”；
- 其余模型整体仍明显偏矮，视觉上没有对齐 player 圆柱参考体；
- 连发枪时 pedestrian 会出现 `run / flee -> walk -> run` 的状态抖动；
- 按 `C` 切到 inspection 模式后，仅靠近玩家也会误触发 `panic / flee`；
- casualty 在某些路径上仍会直接消失，不稳定播放 `death/dead` 动画；
- 默认 `lite` crowd density 仍让城市显得空旷，用户要求至少提升到当前存在感的 `10x`。

这说明 `M7/M8` 的自动化口径虽然成立，但 hand-play closeout 仍有明显缺口。继续把 `M8` 视为“完全收口”只会让后续修复越来越碎，因此必须把这批问题正式升级成 `M9`，而不是零散补丁。

## 变更内容

### 原设计

- `REQ-0002-010` 与 `REQ-0002-012` 只要求 witness flee、walk/run/death 动画接入与基本近景真模型替换，没有把“连续 threat 状态稳定性”“inspection mode 误触发隔离”“death visual 在所有移除路径中保活”写成独立需求。
- `REQ-0002-012` 的尺寸合同只要求 `source_height_m / source_ground_offset_m` 能映射到 simulation `height_m`，没有把“必须对齐 player 参考圆柱体”的视觉尺度收口写成正式验收。
- `REQ-0002-011` 只要求把 `lite` crowd 从 `M6` 稀疏基线向上抬一轮，没有把“数量级级别的人流存在感”写成正式 DoD。

### 新设计

- 新增 `REQ-0002-013`：把“近景模型尺度校准与 manifest 鲁棒性”单独立项，要求 7 个 civilian model 对齐 player 参考圆柱体，且不再允许单模型出现巨人级离群。
- 新增 `REQ-0002-014`：把“连续 violent threat 下的状态机稳定性”和“inspection / C 模式隔离”单独立项，要求 sustained gunfire 不再抖回 walk，`C` 模式仅靠近玩家不再误触发 flee。
- 新增 `REQ-0002-015`：把“death visual 保活与延迟移除合同”单独立项，要求 casualty 在 projectile / explosion / tier 变动 / chunk 回访路径中都稳定留下可见 death clip。
- 新增 `REQ-0002-016`：把默认 `lite` crowd density 再抬一个数量级，明确以 `M8` 基线为参照推进到 `10x` 级别的人流存在感。
- `v6` 新开 `M9`，专门承载上述手玩 closeout；在 `M9` 完成前，`v6` 不再视为最终收口。

## 影响范围

- 受影响的 Req ID：
  - REQ-0002-010
  - REQ-0002-011
  - REQ-0002-012
  - 新增 REQ-0002-013
  - 新增 REQ-0002-014
  - 新增 REQ-0002-015
  - 新增 REQ-0002-016
- 受影响的 vN 计划：
  - `docs/plan/v6-index.md`
  - `docs/plan/v6-pedestrian-handplay-closeout.md`
- 受影响的测试：
  - `tests/world/test_city_pedestrian_visual_height_calibration.gd`
  - `tests/world/test_city_pedestrian_sustained_fire_reaction.gd`
  - `tests/world/test_city_pedestrian_inspection_mode_non_threat.gd`
  - `tests/world/test_city_pedestrian_death_visual_persistence.gd`
  - `tests/world/test_city_pedestrian_density_order_of_magnitude.gd`
  - `tests/e2e/test_city_pedestrian_live_burst_fire_stability.gd`
  - `tests/e2e/test_city_pedestrian_character_visual_presence.gd`
  - `tests/e2e/test_city_pedestrian_performance_profile.gd`
  - `tests/e2e/test_city_runtime_performance_profile.gd`
- 受影响的代码文件：
  - `city_game/assets/pedestrians/civilians/pedestrian_model_manifest.json`
  - `city_game/world/pedestrians/rendering/CityPedestrianVisualCatalog.gd`
  - `city_game/world/pedestrians/rendering/CityPedestrianVisualInstance.gd`
  - `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
  - `city_game/world/pedestrians/model/CityPedestrianConfig.gd`
  - `city_game/world/pedestrians/model/CityPedestrianQuery.gd`
  - `city_game/world/pedestrians/streaming/CityPedestrianBudget.gd`
  - `city_game/scripts/CityPrototype.gd`
  - `city_game/scripts/PlayerController.gd`

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0012）
- [x] v6 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新
