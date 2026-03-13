# V6 Pedestrian Witness Flee Response

## Goal

把 pedestrian 从“只有 direct victim 死亡或极小 direct-threat ring 生效”的状态，推进到“玩家开枪或手雷爆炸后，`500m` 内的周围 witness 都会形成玩家可感知的四散逃离，并且以 `4x` 速度至少跑满 `500m`，同时系统仍服从 crowd budget”的状态。

## PRD Trace

- REQ-0002-010

## Scope

做什么：

- 为 gunfire、direct-hit casualty 与 grenade / explosion 建立 `500m` audible / witness threat event，而不是只结算受害者本身
- 让 `500m` 内的存活 witness pedestrian 在真实运行期里切换到 `panic` / `flee`，并以 `4x` 速度形成可观察的街头逃散
- flee 目标必须保证单次逃散至少跑满 `500m`，不能再依赖短倒计时提前停车
- 把 witness 选择、promotion 和逃散持续时间严格限制在 budgeted runtime 之内，而不是把半径内所有 pedestrian 升成常驻 nearfield agent
- 保持 projectile / grenade / crowd runtime 的事件接口解耦，避免武器脚本直接掌控 pedestrian 全部状态机

不做什么：

- 不做全城级 panic、rumor、广播链和长期记忆
- 不做 police / wanted system
- 不做 civilian 之间的复杂协同行为、呼救或掩体搜索

## Acceptance

1. 自动化测试必须证明：gunshot 声本身就会让 `500m` 内、即使未被直接命中的存活 pedestrian 切换到 `panic` 或 `flee`。
2. 自动化测试必须证明：grenade / explosion 或 casualty 后，位于 `500m` witness radius 内的存活 pedestrian 会切换到 `panic` 或 `flee`，而不是只有 direct victim 或 lethal survivor 状态改变。
3. 自动化测试必须证明：进入 `panic / flee` 的 pedestrian 以至少 `4x base speed` 逃跑，而且单次逃散位移必须 `>= 500m` 才允许停止。
4. 自动化测试必须证明：`> 500m` 的 pedestrian 保持 ambient 行为，不发生全图级 panic。
5. 自动化测试必须证明：重复 gunfire / explosion 事件后，Tier 3 持续 `<= 24`，`nearfield` 总量持续受控，不出现 witness promotion leak；`tests/e2e/test_city_pedestrian_combat_flow.gd` 与 `tests/e2e/test_city_pedestrian_travel_flow.gd` 必须继续 `PASS`。
6. 反作弊条款：不得通过“全图统一切 flee”“只让 direct victim 改状态”“把 witness 直接删掉”或“让 flee 提前计时结束”来宣称需求完成。

## Files

- Modify: `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/combat/CityProjectile.gd`
- Modify: `city_game/combat/CityGrenade.gd`
- Create: `tests/world/test_city_pedestrian_audible_radius_boundary.gd`
- Create: `tests/world/test_city_pedestrian_wide_area_audible_threat.gd`
- Create: `tests/world/test_city_pedestrian_witness_flee_response.gd`
- Create: `tests/e2e/test_city_pedestrian_live_wide_area_threat_chain.gd`
- Create: `tests/e2e/test_city_pedestrian_live_combat_chain.gd`
- Modify: `tests/e2e/test_city_pedestrian_combat_flow.gd`
- Modify: `tests/e2e/test_city_pedestrian_travel_flow.gd`
- Verify: `tests/e2e/test_city_pedestrian_performance_profile.gd`
- Verify: `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 写失败测试（红）
   - `test_city_pedestrian_audible_radius_boundary.gd` 断言 `499.5m / 500.0m / 500.5m` 边界两侧的状态切换不漂移。
   - `test_city_pedestrian_wide_area_audible_threat.gd` 与 `test_city_pedestrian_live_wide_area_threat_chain.gd` 断言枪声 / 爆炸 `500m` witness 生效、`>500m` outsider 保持 calm。
   - `test_city_pedestrian_flee_pathing.gd` 断言 flee 至少按 `4x` 速度跑满 `500m`，且 witness 不是同向挤成一束。
   - 扩展 `test_city_pedestrian_combat_flow.gd`，断言真实 combat flow 下 wide-area witness flee 可见且不扩散为全图 panic。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是当前 runtime 只覆盖 direct victim / direct-threat ring，缺少 witness propagation。
3. 实现（绿）
   - 为 projectile、gunfire、casualty 与 explosion 接入 `500m` witness threat event。
   - 在 reaction model / tier controller 中增加 bounded witness promotion、`4x` flee speed 与 `>=500m` flee resolution。
4. 跑到绿
   - witness flee、combat flow 与 travel regression 全部 PASS。
5. 必要重构（仍绿）
   - 收敛 violence event 到 pedestrian runtime 的统一 threat payload，避免 rifle / grenade 分别长出两套状态切换逻辑。
6. E2E / Profiling
   - isolated 重新运行 `test_city_pedestrian_performance_profile.gd` 与 `test_city_runtime_performance_profile.gd`，确认 witness flee 没有打穿红线。

## Risks

- 如果 witness event 不设硬预算，局部逃散会很快退化成全图级 panic。
- 如果 radius 判定、speed multiplier 或 flee target 只保留旧的 `24m / 20m / 1.85x / 短倒计时` 口径，手玩时仍然会看不到明显四散逃离。
- 如果 gunfire / grenade 各自维护一套独立 threat 传播逻辑，后续扩展武器或事件类型时会迅速失控。

## Verification

- 2026-03-13 本地 headless `PASS x3`：`tests/world/test_city_pedestrian_audible_radius_boundary.gd`
- 2026-03-13 本地 headless `PASS x3`：`tests/world/test_city_pedestrian_flee_pathing.gd`
- 2026-03-13 本地 headless `PASS x3`：`tests/world/test_city_pedestrian_wide_area_audible_threat.gd`
- 2026-03-13 本地 headless `PASS`：`tests/world/test_city_pedestrian_witness_flee_response.gd`
- 2026-03-13 本地 headless `PASS x3`：`tests/e2e/test_city_pedestrian_live_wide_area_threat_chain.gd`
- 2026-03-13 本地 headless `PASS`：`tests/e2e/test_city_pedestrian_live_combat_chain.gd`
- 2026-03-13 本地 headless `PASS`：`tests/e2e/test_city_pedestrian_combat_flow.gd`
- 2026-03-13 回归 `PASS`：`tests/e2e/test_city_pedestrian_travel_flow.gd`，证明 mixed travel + combat 下 witness flee 仍不破坏 streaming continuity
- radius boundary fresh 输出：`500.0m` 仍会触发 `panic / flee`，`500.5m` 保持 `reaction_state = none`
- flee pathing fresh 输出：`displacement_a_m = 500.000030517578`、`displacement_b_m = 500.000030517578`，且前 `1s` 位移按断言达到 `4x base speed`，两名 witness 的逃散向量不再同向重合
- wide-area fresh 输出：world 级 gunshot / grenade witness 分别在 `359.7069m` 触发、在 `522.4133m` 保持 calm；live wide-area chain 连跑 `3` 轮保持为绿
- witness propagation fresh 输出：projectile 场景下 direct-hit victim 会死亡，至少两名 nearby witness 切到 `panic / flee`；explosion / casualty 场景下 lethal radius 外但位于 `500m` witness radius 内的存活 pedestrian 会切到 `flee`，而 `>500m` outsider 保持 `reaction_state = none`
- 2026-03-13 isolated profiling 继续守线：`tests/e2e/test_city_pedestrian_performance_profile.gd` warm `16048`、first-visit `13507`；`tests/e2e/test_city_runtime_performance_profile.gd` warm `12339`
- runtime 侧通过增量 chunk crowd membership、按需 materialize 完整 snapshot 与去重 mount-time crowd apply，把 first-visit redline 从 closeout 前的失败态压回绿线以内，同时未降低 flee / witness / density 验收口径。
