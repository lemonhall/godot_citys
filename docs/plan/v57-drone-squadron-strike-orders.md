# V57 Drone Squadron Strike Orders

## Goal

把 `v56` 的机群从“只会召唤/回收”推进到“能正式接受攻击命令”：左键优先派 1 架僚机冲锋，长机保留观察位；中键对准星周围区域下达阶梯式僚机冲锋；只剩长机时回退到现有 leader kamikaze + `NO SIGNAL` 旧链。

## Dependencies

- leader runtime：
  - `res://city_game/combat/drone/CityPlayerDroneRuntime.gd`
- squadron manager：
  - `res://city_game/combat/drone/CityPlayerDroneSquadronRuntime.gd`
- wingman runtime：
  - `res://city_game/combat/drone/CityPlayerDroneWingman.gd`
- 主世界 host：
  - `res://city_game/scripts/CityPrototype.gd`
- 既有 kamikaze tests：
  - `res://tests/world/test_city_player_drone_suicide_strike_contract.gd`
  - `res://tests/e2e/test_city_player_drone_kamikaze_flow.gd`

## PRD Trace

- `REQ-0027-010`
- `REQ-0027-011`

## Scope

做什么：

- 给长机 FPV ADS 左键增加“优先派单架僚机”合同
- 给长机 FPV ADS 中键增加“面域阶梯式僚机冲锋”合同
- 扩展 wingman runtime，让其支持真实 strike / explosion / attrition
- 暴露 squadron strike debug state，便于验证波次、落点、计数与 fallback
- 保留 leader-only 自爆 + `NO SIGNAL` 作为最后一架时的旧链 fallback

不做什么：

- 不做玩家手工点名某一架僚机
- 不做玩家框选区域
- 不做正式 flocking / 避障 / 威胁规避
- 不做长机和僚机混合编队智能战术
- 不做中键波次配置 UI

## Acceptance

1. 自动化测试必须证明：`FPV ADS + active wingman >= 1` 时左键只会派 1 架僚机冲锋，长机不会进入 `strike_committed`。
2. 自动化测试必须证明：单架僚机 strike 完成后，机群 active/desired 总数正式减少 `1`。
3. 自动化测试必须证明：僚机 strike 期间长机不会进入 `signal_loss`，也不会显示 `NO SIGNAL`。
4. 自动化测试必须证明：`active wingman == 0` 时左键会回退到现有 leader kamikaze + `NO SIGNAL` 旧链。
5. 自动化测试必须证明：中键 area strike 会生成多个不同落点，这些落点都落在准星中心周围 `12m` 半径内。
6. 自动化测试必须证明：中键 area strike 的 dispatch 波次遵循 `1 -> 2 -> 3` 循环，且相邻两批次间隔不少于 `0.6s`。
7. 自动化测试必须证明：中键 area strike 期间长机持续保持 camera/input owner，不会被任何僚机抢镜头。

## Files

- Update: `docs/prd/PRD-0027-drone-flight-foundation.md`
- Create: `docs/ecn/ECN-0041-drone-squadron-strike-orders.md`
- Create: `docs/plans/2026-03-26-v57-drone-squadron-strike-orders-design.md`
- Create: `docs/plan/v57-index.md`
- Create: `docs/plan/v57-drone-squadron-strike-orders.md`
- Update: `city_game/combat/drone/CityPlayerDroneRuntime.gd`
- Update: `city_game/combat/drone/CityPlayerDroneSquadronRuntime.gd`
- Update: `city_game/combat/drone/CityPlayerDroneWingman.gd`
- Create: `tests/world/test_city_player_drone_squadron_single_strike_dispatch_contract.gd`
- Create: `tests/world/test_city_player_drone_squadron_area_strike_command_contract.gd`
- Create: `tests/e2e/test_city_player_drone_squadron_strike_flow.gd`
- Create: `docs/plan/v57-m3-verification-2026-03-26.md`

## Steps

1. Docs Freeze
   - 冻结 left-click single wingman dispatch、middle-click area strike、`12m` 半径、`0.6s` 间隔、leader-only fallback。
2. TDD Red
   - 先写/改：
     - `test_city_player_drone_squadron_single_strike_dispatch_contract.gd`
     - `test_city_player_drone_squadron_area_strike_command_contract.gd`
     - `test_city_player_drone_squadron_strike_flow.gd`
3. Run Red
   - 预期第一轮红灯原因：
     - 左键仍让 leader 自爆
     - 中键仍无正式语义
     - wingman 仍只有 follow 可视节点，没有真实 strike / explosion / attrition
4. TDD Green
   - 实现 squadron strike dispatch、wave queue、wingman strike runtime 与 debug state。
5. Verification
   - 跑 focused tests + 既有 `leader-only kamikaze` / `squadron summon` regressions；
   - 回填 `v57-m3-verification-2026-03-26.md`。

## Risks

- 如果 wingman strike 不做 attrition bookkeeping，机群数量会很快和实际场景脱节。
- 如果中键 area strike 不暴露 dispatch events，测试很难稳定验证 `1 -> 2 -> 3` 波次合同。
- 如果有僚机时左键仍允许 leader fallback，玩家会感觉“长机会不会送死”不可预测。
