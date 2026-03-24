# ECN-0036: Artillery Gameplay Ballistic Solver

## 基本信息

- **ECN 编号**：ECN-0036
- **关联 PRD**：PRD-0029
- **关联 Req ID**：
  - `REQ-0029-014`
  - `REQ-0029-015`
  - `REQ-0029-016`
  - `REQ-0029-017`
- **发现阶段**：v51 closeout 后的火炮下一轮范围冻结
- **日期**：2026-03-25

## 变更原因

`v51` 已经让 howitzer 在主世界里能真正开火、生成 live shell 并产生落点/爆炸结果，但当前 ballistic path 仍然停留在“`muzzle_velocity + gravity` 的通用抛体”层：

- 它可以飞、可以炸；
- 但它还没有正式的弹种 profile；
- 也没有“由目标反向求诸元”的正式 solver；
- 更关键的是，它的口径还没有冻结成符合当前游戏地图体验的射程 envelope。

用户已经明确降低真实度要求，不追求军规级气象/装药/风偏火控，而是希望：

1. 当前 M777 只需要“大概像真的”；
2. 默认最大射程冻结为 `22.5km`；
3. 由于当前地图/城区是缩水后的 gameplay 语义，最小射程进一步放宽为 `1.5km`；
4. 正向落点预测与反向目标求诸元必须共用同一套 model，避免之后 HUD、solver、live shell 三套口径分叉。

## 变更内容

### 原设计

- `shell_type_id` 只是 payload 占位；
- shell runtime 仍使用旧的直接 launch velocity + gravity 积分；
- 没有 formal target solve；
- 没有 formal range envelope；
- 预测落点仍未合同化。

### 新设计

- 新增正式 `REQ-0029-014 Gameplay Artillery Ammo Profile Contract`
  - 默认弹型 `m795_he`
  - 射程 envelope 冻结为 `1.5km~22.5km`
  - profile 必须同时暴露 reference velocity 与 solver velocity
- 新增正式 `REQ-0029-015 Forward Ballistic Prediction Contract`
  - 从 firing solution 正向解算 predicted impact
- 新增正式 `REQ-0029-016 Inverse Fire Solution To Target Contract`
  - 从发射点与目标点反向求 bearing / pitch
- 新增正式 `REQ-0029-017 Shared Ballistic Model Contract`
  - howitzer payload、forward prediction、inverse solve 与 live shell runtime 必须共享同一套 gameplay ballistic math

## 影响范围

- 受影响的 Req ID：
  - `REQ-0029-014`
  - `REQ-0029-015`
  - `REQ-0029-016`
  - `REQ-0029-017`
- 受影响的 vN 计划：
  - `docs/plan/v52-index.md`
  - `docs/plan/v52-artillery-gameplay-ballistic-solver.md`
- 受影响的测试：
  - `tests/world/test_city_artillery_ammo_profile_contract.gd`
  - `tests/world/test_city_artillery_ballistics_forward_solver_contract.gd`
  - `tests/world/test_city_artillery_ballistics_inverse_solver_contract.gd`
  - `tests/world/test_city_artillery_ballistics_round_trip_contract.gd`
- 受影响的代码文件：
  - `city_game/combat/artillery/CityArtilleryBallistics.gd`
  - `city_game/combat/artillery/CityM777Howitzer.gd`
  - `city_game/combat/artillery/CityArtilleryShell.gd`

## 处置方式

- [x] PRD 已同步更新
- [x] v52 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新
