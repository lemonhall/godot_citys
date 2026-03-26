# ECN-0042: Drone Wingman Strike Presentation

## 基本信息

- **ECN 编号**：ECN-0042
- **关联 PRD**：PRD-0027
- **关联 Req ID**：
  - `REQ-0027-012`
  - `REQ-0027-013`
- **发现阶段**：`v57` closeout 后用户手测
- **日期**：2026-03-26

## 变更原因

`v57` 已经把机群 strike 命令与命中结算打通，但用户手测后明确指出两处 presentation 缺口：

- 僚机撞击地面时没有正式爆炸环和爆炸音效，读起来像“静默消失”；
- 僚机 strike 路径过于笔直且匀速，缺少俯冲弧线和机间差异。

这两个问题不改变 `v57` 已冻结的命令语义，但会直接影响打击手感与可读性，因此作为 `v58` 的正式增量处理。

## 变更内容

### 原设计

- `v57` 只冻结了：
  - 左键单架僚机 dispatch
  - 中键 area strike 波次
  - leader fallback / `NO SIGNAL`
- 对僚机 strike 的 presentation 没有单独冻结“必须复用正式爆炸表现与音效”“必须不是完美直线匀速”的要求。

### 新设计

- 新增 `REQ-0027-012`
  - 僚机撞击地面时必须播放正式爆炸环、爆炸球与爆炸音效；
  - 复用当前项目正式爆炸资产风格，不再给僚机单独造一套完全不同的爆炸语言。
- 新增 `REQ-0027-013`
  - 僚机 strike 路径必须表现为 deterministic 的俯冲弧线；
  - 不同僚机之间要有小幅 seed 驱动差异；
  - 但差异不得破坏命中点合同。

## 影响范围

- 受影响的 Req ID：
  - `REQ-0027-012`
  - `REQ-0027-013`
- 受影响的 vN 计划：
  - `docs/plan/v58-index.md`
  - `docs/plan/v58-drone-wingman-strike-presentation.md`
- 受影响的测试：
  - `tests/world/test_city_player_drone_squadron_wingman_impact_presentation_contract.gd`
  - `tests/world/test_city_player_drone_squadron_wingman_dive_profile_contract.gd`
  - `tests/e2e/test_city_player_drone_squadron_strike_presentation_flow.gd`
- 受影响的代码文件：
  - `city_game/combat/drone/CityPlayerDroneWingman.gd`
  - `city_game/combat/drone/CityPlayerDroneSquadronRuntime.gd`
  - `city_game/combat/CitySurfaceExplosionFx.gd`

## 处置方式

- [x] PRD 已同步更新（标注 ECN 编号）
- [x] v58 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新
