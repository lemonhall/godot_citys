# V6 Pedestrian Nearfield Fidelity Restabilization

## Goal

在 `M10` 的 density-preserving runtime 上，把 `M8/M9` 已经拿下的近景 fidelity 要求重新全部收口，确保真实模型、death visual、inspection mode、violent reaction 不会因为 runtime 重构而回退。

## PRD Trace

- REQ-0002-012
- REQ-0002-013
- REQ-0002-014
- REQ-0002-015

## Scope

做什么：

- 在 `M10` 新 runtime 上重新验证并稳定 `Tier2 + Tier3` 真模型、walk/run/death、inspection mode、violent reaction、death visual
- 确保近景高保真只作用于 fixed nearfield set，不与高密度 Tier 1 的大人口共用同一套全量更新链路
- 把 `M8/M9` 的 hand-play 需求重新挂到新 runtime 的 promotion / demotion / death visual / threat routing 上

不做什么：

- 不回退 `M10` 的 density-preserving core
- 不新增 police / wanted / rumor / citywide panic 等大玩法
- 不在本轮引入 ragdoll、持久尸体或完整行为树
- 不通过关闭近景 fidelity 来换取 `M10` 的 profile 结果

## DoD 硬度自检

1. 本计划所有 DoD 都可二元判定：模型实例存在、动画路由存在、状态机不抖动、inspection 不误触发、death visual 可见窗口持续存在。
2. 本计划所有 DoD 都绑定可重复命令：`tests/world/test_city_pedestrian_character_asset_manifest.gd`、`tests/world/test_city_pedestrian_character_scale_normalization.gd`、`tests/world/test_city_pedestrian_visual_height_calibration.gd`、`tests/world/test_city_pedestrian_runtime_visual_height_live_models.gd`、`tests/world/test_city_pedestrian_sustained_fire_reaction.gd`、`tests/world/test_city_pedestrian_inspection_mode_non_threat.gd`、`tests/world/test_city_pedestrian_death_visual_persistence.gd`、`tests/e2e/test_city_pedestrian_character_visual_presence.gd`、`tests/e2e/test_city_pedestrian_live_burst_fire_stability.gd`。
3. 反作弊条款明确：不得通过关闭真实模型、把 panic/flee 全局降成 yield、延迟真正死亡判定、或只在单测场景手工保留 death node 来宣称完成。
4. 本计划边界明确：只做 nearfield fidelity 在新 runtime 上的重回归，不扩玩法边界。

## Acceptance

1. 自动化测试必须证明：`Tier2 + Tier3` 在 `M10` 新 runtime 上继续实例化真实 civilian model，而不是回退到 BoxMesh 占位。
2. 自动化测试必须证明：7 个 civilian model 的 live rendered height 继续满足 `>= 3.0m` 与 height spread 合同，不因 runtime 改造重新出现 `animated_woman.glb` 异常巨人或整体矮人化。
3. 自动化测试必须证明：sustained gunfire / overlapping violent events 期间，不再出现 `run -> walk -> run` 抖动；inspection mode 仅靠近玩家时仍最多触发 `yield / sidestep`。
4. 自动化测试必须证明：凡是模型提供 `death/dead` clip 的 casualty 路径，都继续保留至少 `0.75s` 的可见 death visual 窗口，不因 tier 切换、page runtime 或 chunk remount 被提前抹掉。
5. 自动化测试必须证明：在通过上述近景 fidelity 回归后，`tests/e2e/test_city_pedestrian_performance_profile.gd` 与 `tests/e2e/test_city_runtime_performance_profile.gd` 仍继续 `PASS`。
6. 反作弊条款：不得通过重新降低默认人口、屏蔽 inspection mode、关闭真模型、缩短 death visual、或把 violent threat 广播只保留 direct victim 来宣称 `M11` 完成。

## Files

- Modify: `city_game/world/pedestrians/rendering/CityPedestrianVisualCatalog.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianVisualInstance.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `tests/world/test_city_pedestrian_character_asset_manifest.gd`
- Modify: `tests/world/test_city_pedestrian_character_scale_normalization.gd`
- Modify: `tests/world/test_city_pedestrian_visual_height_calibration.gd`
- Modify: `tests/world/test_city_pedestrian_runtime_visual_height_live_models.gd`
- Modify: `tests/world/test_city_pedestrian_sustained_fire_reaction.gd`
- Modify: `tests/world/test_city_pedestrian_inspection_mode_non_threat.gd`
- Modify: `tests/world/test_city_pedestrian_death_visual_persistence.gd`
- Modify: `tests/e2e/test_city_pedestrian_character_visual_presence.gd`
- Modify: `tests/e2e/test_city_pedestrian_live_burst_fire_stability.gd`
- Verify: `tests/e2e/test_city_pedestrian_performance_profile.gd`
- Verify: `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 写失败测试（红）
   - 先在 `M10` 新 runtime 上重跑 `M8/M9` 的近景 fidelity 测试，确认哪些点因 runtime 改造重新变红。
2. 跑到红
   - 必须让失败原因明确落在新的 runtime 接缝上，例如 promotion / demotion、death visual lifecycle、inspection routing、violent-state hold，而不是 unrelated breakage。
3. 实现（绿）
   - 调整 Tier 2 / Tier 3 promotion 与 render hooks。
   - 把 death visual 生命周期重新挂到新 runtime。
   - 校正 inspection 与 violent threat 路由。
   - 重新校准真实模型与新 runtime 的 visual scaling / animation entry。
4. 跑到绿
   - 近景 fidelity world tests 与 E2E 全部 PASS。
5. 必要重构（仍绿）
   - 清理临时适配代码，确保近景 fidelity 与 `M10` runtime 的边界清晰，不再互相侵蚀。
6. E2E / Profiling
   - 与 `M10` 一样，fresh isolated 重新运行 pedestrian/runtime profile，确认 `M11` 没有重新打穿红线。

## Risks

- 如果 `M10` 没有把 nearfield set 与 Tier 1 大人口彻底解耦，`M11` 会再次把高密度拖回主线程热路径。
- 如果 death visual 还绑定 live roster 生命周期，任何新的 page/snapshot 逻辑都会继续把它吞掉。
- 如果 inspection 与 violent threat 仍共用广播链，`M10` 的调度改造会让这个问题更隐蔽而不是消失。
