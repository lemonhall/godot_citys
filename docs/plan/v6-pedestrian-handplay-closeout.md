# V6 Pedestrian Hand-Play Closeout

## Goal

把 pedestrian 从“自动化与 profile 已过线，但手玩仍出现巨人、矮人、状态抖动、误逃散、命中即无、城市过空”的状态，推进到“近景角色体型可信、violent reaction 稳定、death clip 可靠可见、默认 `lite` 人流存在感达到 `M8` 基线 `10x`，且 fresh profiling 继续守住 `16.67ms/frame` 红线”的状态。

## PRD Trace

- REQ-0002-013
- REQ-0002-014
- REQ-0002-015
- REQ-0002-016

## Scope

做什么：

- 修正 civilian manifest / visual scaling 合同，把 7 个 `glb` 的近景最终体型统一抬到 `>= 3.0m` 的 live 可见高度，消灭“女巨人”和整体矮人化
  - `source_height_m` 必须按 walk 启动后的 live skeleton 高度校准，不能继续使用静态 `MeshInstance` AABB 充当最终缩放基准
- 为 continuous gunfire / casualty / explosion 引入稳定的 threat hold contract，防止 `panic / flee / run` 在威胁尚未结束时抖回 ambient walk
- 把 `C` 切出的 inspection mode 从 panic/flee 广播链中隔离出来，保证“仅靠近玩家”最多触发 `yield / sidestep`
- 把 death visual 从 live roster / tier 变动时序中解耦，保证 projectile / explosion / chunk remount / tier demotion 路径下都稳定播放 `death/dead`
- 把默认 `lite` crowd density 从 `M8` 基线再抬一个数量级，优先扩容 `Tier0 + Tier1` 低成本存在感，目标是可见人口存在感达到 `10x`

不做什么：

- 不做 police / wanted / rumor / citywide panic 系统
- 不做 ragdoll、持久尸体、完整行为树或复杂社交 AI
- 不把 Tier 2 / Tier 3 hard cap 直接翻倍当作主要密度解法
- 不在 `M9` 里重写整个 pedestrian lane graph 或 full crowd 模式

## Acceptance

1. 自动化测试必须证明：7 个 civilian model 在平地默认状态下的最终 live rendered height 都 `>= 3.0m`，且最高/最矮比值 `<= 1.10`。
2. 自动化测试必须证明：automatic rifle 或等价 burst fire 持续期间，位于 threat / witness 半径内的 pedestrian 不再出现 `run -> walk -> run` 抖动；inspection mode 仅靠近玩家时不再误触发 `panic / flee`。
3. 自动化测试必须证明：凡是模型提供 `death/dead` clip 的 casualty 路径，都至少保留 `0.75s` 的可见 death visual 窗口，不再出现同帧直接消失。
4. 自动化测试必须证明：以 `2026-03-13` 的 `M8` 基线为参照，默认 `lite` 模式下 warm traversal 的 `tier1_count >= 540`，first-visit traversal 的 `tier1_count >= 600`，且 district / road class 排序仍然成立。
5. `tests/e2e/test_city_pedestrian_performance_profile.gd` 与 `tests/e2e/test_city_runtime_performance_profile.gd` 必须继续 `PASS`，不得因为 `M9` 收口把 `wall_frame_avg_usec` 打穿 `16667`。
6. 反作弊条款：不得通过跳过异常模型、屏蔽 inspection mode、延迟真正死亡判定、只调低测试路线或把大量人口塞进不可见层来宣称 `M9` 完成。

## Latest Status

- 2026-03-13 `M9` 的 hand-play 功能链历史上已经验证通过：
  - `tests/world/test_city_pedestrian_visual_height_calibration.gd`
  - `tests/world/test_city_pedestrian_runtime_visual_height_live_models.gd`
  - `tests/world/test_city_pedestrian_sustained_fire_reaction.gd`
  - `tests/world/test_city_pedestrian_inspection_mode_non_threat.gd`
  - `tests/world/test_city_pedestrian_death_visual_persistence.gd`
  - `tests/world/test_city_pedestrian_density_order_of_magnitude.gd`
  - `tests/e2e/test_city_pedestrian_live_burst_fire_stability.gd`
  - `tests/e2e/test_city_pedestrian_character_visual_presence.gd`
  - `tests/e2e/test_city_pedestrian_live_combat_chain.gd`
- 2026-03-13 当前 main 工作区已经为了止血回退 density 参数：
  - `city_game/world/pedestrians/model/CityPedestrianConfig.gd` 当前回退为 `max_spawn_slots_per_chunk = 20`
  - `city_game/world/pedestrians/model/CityPedestrianConfig.gd` 当前回退为 `get_spawn_slots_for_edge() -> 0/1/2/3`
  - `city_game/world/pedestrians/model/CityPedestrianQuery.gd` 当前回退为 `lane_slot_budget = floor(lane_length / 90.0)`
- 2026-03-13 当前 fresh 真实状态已经变成 split state：
  - `tests/world/test_city_pedestrian_density_order_of_magnitude.gd` `FAIL`，warm `tier1_count = 54`
  - `tests/e2e/test_city_pedestrian_performance_profile.gd` `PASS`，warm `wall_frame_avg_usec = 12989`
  - `tests/e2e/test_city_runtime_performance_profile.gd` `PASS`，warm `wall_frame_avg_usec = 15699`
- 结论：`M9` 不再是当前的主执行面。它保留“手玩功能链曾经成立”的历史证据，但“高密度 + 红线 + hand-play fidelity 同配置同时成立”的最终收口，已经通过 `ECN-0013` 升级为 `M10`（runtime 恢复）和 `M11`（新 runtime 上的近景 fidelity 重回归）。

## Files

- Modify: `city_game/assets/pedestrians/civilians/pedestrian_model_manifest.json`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianVisualCatalog.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianVisualInstance.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/pedestrians/model/CityPedestrianConfig.gd`
- Modify: `city_game/world/pedestrians/model/CityPedestrianQuery.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianBudget.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/scripts/PlayerController.gd`
- Create: `tests/world/test_city_pedestrian_visual_height_calibration.gd`
- Create: `tests/world/test_city_pedestrian_sustained_fire_reaction.gd`
- Create: `tests/world/test_city_pedestrian_inspection_mode_non_threat.gd`
- Create: `tests/world/test_city_pedestrian_death_visual_persistence.gd`
- Create: `tests/world/test_city_pedestrian_density_order_of_magnitude.gd`
- Create: `tests/e2e/test_city_pedestrian_live_burst_fire_stability.gd`
- Modify: `tests/e2e/test_city_pedestrian_character_visual_presence.gd`
- Create: `tests/world/test_city_pedestrian_runtime_visual_height_live_models.gd`
- Verify: `tests/e2e/test_city_pedestrian_performance_profile.gd`
- Verify: `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 写失败测试（红）
   - `test_city_pedestrian_visual_height_calibration.gd` 与 `test_city_pedestrian_runtime_visual_height_live_models.gd` 断言 7 个模型的最终 live skeleton height 与 player standing cylinder 参考高度对齐，不再出现离群巨人或整体矮人化。
   - `test_city_pedestrian_sustained_fire_reaction.gd` 与 `test_city_pedestrian_live_burst_fire_stability.gd` 断言 sustained gunfire 期间 `panic / flee / run` 不再抖回 walk。
   - `test_city_pedestrian_inspection_mode_non_threat.gd` 断言 `C/inspection` 模式仅靠近玩家不会触发 panic/flee，但 inspection 模式下真实开枪仍然会触发。
   - `test_city_pedestrian_death_visual_persistence.gd` 与扩展后的 `test_city_pedestrian_character_visual_presence.gd` 断言 casualty 至少保留 `0.75s` death visual。
   - `test_city_pedestrian_density_order_of_magnitude.gd` 断言默认 `lite` 的 `tier1_count` 达到 warm `540`、first-visit `600`。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是当前 manifest 仍允许离群源高度进入缩放公式，violent threat 缺少 hold window，inspection mode 未与 threat 链路隔离，death visual 仍受 live roster 删除时序影响，density 也仍停在 `54 / 60` 级别。
3. 实现（绿）
   - 修复 manifest / visual scaling 合同，并把 visual target 锚到 player 参考体。
   - 为 sustained violent threat 加入稳定的状态保持窗口与 animation routing contract。
   - 把 inspection mode 与真正 violent threat 广播解耦。
   - 把 death visual 生命周期从 tier/live removal 中解耦。
   - 重构 `lite` low-cost density contract，把默认存在感推进到 `10x` 量级。
4. 跑到绿
   - 尺度、burst fire、inspection mode、death visual 与 density order-of-magnitude 测试全部 PASS。
5. 必要重构（仍绿）
   - 收敛 scale calibration、threat aggregation、death visual lifecycle 与 density query 的共享逻辑，避免再长出分支式补丁。
6. E2E / Profiling
   - isolated 重新运行 `test_city_pedestrian_performance_profile.gd` 与 `test_city_runtime_performance_profile.gd`，确认 `M9` 收口没有把红线打穿。

## Risks

- 如果继续把视觉尺度完全绑定到 simulation `height_m`，就算再改 manifest 数字，也仍然会反复出现“公式对、观感错”的矮人问题。
- 如果 sustained threat 不建立 hold window，任何 burst fire 修复都会继续在 `panic/run` 与 ambient walk 之间来回抖动。
- 如果 inspection mode 和 violent threat 仍共用同一条广播链，后续每次调优 near-player reaction 都会重新把 `C` 模式搞坏。
- 如果 death visual 仍然依附 live roster 生命周期，tier demotion、chunk remount 和 snapshot rebuild 会继续把它吞掉。
- 如果想靠 Tier 2 / Tier 3 骨骼实例直接堆出 `10x` 人口，`M9` 很容易在红线前先失败；必须把主战场放在低成本 tiers。
