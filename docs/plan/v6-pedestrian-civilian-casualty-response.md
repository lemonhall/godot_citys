# V6 Pedestrian Civilian Casualty Response

## Goal

把 pedestrian 从“玩家暴力只会触发非致命 reaction”的状态，推进到“direct victim 会死亡、周边 crowd 会逃散、但系统仍服从 crowd budget”的状态。

## PRD Trace

- REQ-0002-009

## Scope

做什么：

- 让 projectile direct hit 能对 pedestrian 结算 civilian death
- 让 grenade / explosion 对 lethal radius 内 pedestrian 结算死亡，对外圈 threat radius 内 pedestrian 触发 `panic / flee`
- 为 pedestrian runtime 增加 alive/dead 或等价 death resolution 契约，确保 direct victim 会从 live crowd 中退出
- 保持事件驱动、预算受控的 crowd runtime，不把所有 pedestrian 升级为常驻 combat NPC
- 在实现完成后重新跑 isolated crowd/runtime profiling，确认 combat response 没有打穿红线

不做什么：

- 不做 ragdoll、持久尸体物理或 civilian 反击
- 不做 police / wanted system
- 不做全图级 panic propagation 或全城 combat AI

## Acceptance

1. 自动化测试必须证明：player projectile 的 direct hit 会杀死目标 pedestrian，并使其从 live crowd roster 或 active render set 中移除。
2. 自动化测试必须证明：grenade / explosion 对 lethal radius 内 pedestrian 结算死亡，对 threat radius 内但 lethal radius 外 pedestrian 切换到 `panic` 或 `flee`。
3. 自动化测试必须证明：threat radius 外 pedestrian 保持存活并继续 ambient 行为，不发生全图级 panic。
4. 自动化测试必须证明：重复 fire / explosion 事件后，nearfield / Tier 3 预算仍受控，不出现 count leak 或永久高成本 promotion。
5. fresh isolated `tests/e2e/test_city_pedestrian_performance_profile.gd` 与 `tests/e2e/test_city_runtime_performance_profile.gd` 必须继续 `PASS`，且 `wall_frame_avg_usec <= 16667`。
6. 反作弊条款：不得通过“只播 reaction、不结算死亡”“战斗时直接隐藏全部 pedestrian”或“爆炸半径内无差别全删”来宣称需求完成。

## Files

- Modify: `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/combat/CityProjectile.gd`
- Modify: `city_game/combat/CityGrenade.gd`
- Create: `tests/world/test_city_pedestrian_projectile_kill.gd`
- Create: `tests/world/test_city_pedestrian_grenade_kill_and_flee.gd`
- Create: `tests/e2e/test_city_pedestrian_combat_flow.gd`
- Verify: `tests/e2e/test_city_pedestrian_performance_profile.gd`
- Verify: `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 写失败测试（红）
   - `test_city_pedestrian_projectile_kill.gd` 断言 projectile direct hit 会杀死 target pedestrian。
   - `test_city_pedestrian_grenade_kill_and_flee.gd` 断言 explosion 内圈 lethal、外圈 flee。
   - `test_city_pedestrian_combat_flow.gd` 断言真实 combat flow 下不会出现全图 panic 或 count leak。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是当前 crowd 只会接收 reaction event，不会结算 civilian death。
3. 实现（绿）
   - 为 pedestrian runtime 增加 death resolution，并把 projectile / explosion 与 crowd runtime 的命中判定接起来。
4. 跑到绿
   - kill / flee / combat flow 测试全部 PASS，证明玩家暴力已能对 crowd 产生致命和逃散后果。
5. 必要重构（仍绿）
   - 收敛 projectile / explosion 与 pedestrian runtime 的事件接口，避免 combat 系统和 crowd 系统形成硬耦合。
6. E2E / Profiling
   - isolated 重新运行 `test_city_pedestrian_performance_profile.gd` 与 `test_city_runtime_performance_profile.gd`，确认新行为没有带来红线回退。

## Risks

- 如果通过给每个 Tier 1 pedestrian 加物理碰撞体来做命中，会直接破坏 crowd 性能边界。
- 如果 death resolution 只做删除、不清理 page / tier / snapshot 状态，travel 或回访时会出现 count leak 和 ghost state。
- 如果 explosion 只做单圈 kill 或单圈 global panic，用户感知会继续失真，且测试难以证明行为边界正确。

## Verification

- 2026-03-13 本地 headless `PASS`：`tests/world/test_city_pedestrian_projectile_kill.gd`
- 2026-03-13 本地 headless `PASS`：`tests/world/test_city_pedestrian_grenade_kill_and_flee.gd`
- 2026-03-13 本地 headless `PASS`：`tests/e2e/test_city_pedestrian_combat_flow.gd`
- 2026-03-13 回归 `PASS`：`tests/e2e/test_city_pedestrian_travel_flow.gd`，证明 mixed travel + combat 下 Tier 3 reaction 仍能被捕获且不会泄漏
- projectile fresh 证据：direct-hit victim 进入 `life_state = dead`，`death_cause = projectile`，并从 live crowd snapshot 移除
- grenade fresh 证据：`lethal_radius_m = 4.0` 杀伤 direct victim，`threat_radius_m = 12.0` 仅把周边 survivor 推入 `flee`，threat radius 外 pedestrian 保持 ambient 行为
- 2026-03-13 isolated profiling 继续守线：`tests/e2e/test_city_pedestrian_performance_profile.gd` warm `15518`、first-visit `14214`；`tests/e2e/test_city_runtime_performance_profile.gd` warm `15765`
