# V32 Player Missile Launcher

## Goal

交付正式 `missile_launcher` 玩家武器模式，让玩家在主世界中通过 `8` 键切换并左键发射 live missile。该导弹必须复用 `v29` 的导弹视觉资产与尾焰，飞行中具有轻微 sway / wobble，触碰命中或飞行超过 `500m` 时爆炸，并接入现有 enemy / pedestrian / vehicle explosion 主链。

## PRD Trace

- Direct consumer: REQ-0022-001
- Direct consumer: REQ-0022-002
- Direct consumer: REQ-0022-003
- Guard / Regression: REQ-0022-004

## Dependencies

- 依赖 `v15` 已冻结 weapon mode / signal / crosshair 主链
- 依赖 `v29` 已冻结 `InterceptorMissileVisual` 导弹视觉资产
- 依赖现有 `grenade` 爆炸 resolver：`resolve_explosion_impact` / `resolve_vehicle_explosion`

## Contract Freeze

- 正式 weapon mode：`missile_launcher`
- 正式切换热键：`8`
- 正式 combat root：`CombatRoot/Missiles`
- 导弹飞行最大距离冻结为：`500m`
- live missile 最小 runtime contract：
  - `get_velocity()`
  - `has_exploded()`
  - `get_distance_travelled_m()`
- 爆炸必须沿既有 explosion 主链扩展，不新增第二套 crowd / vehicle damage 系统

## Scope

做什么：

- 在 `PlayerController` 新增 `missile_launcher` 模式、signal、`8` 键切换
- 在 `CityPrototype` 新增 missile spawn / count / exploded handler
- 新增 `CityMissile.tscn` + `CityMissile.gd`
- 复用 `InterceptorMissileVisual.tscn` 作为 visual child
- 更新 HUD debug status / crosshair 口径
- 新增 world tests，并补跑旧武器与 explosion 回归

不做什么：

- 不做锁定、追踪、装填、弹药限制
- 不做 missile-only HUD 面板
- 不重写 grenade 或 laser 逻辑
- 不把 Missile Command 固定炮台玩法直接搬进玩家模式

## Acceptance

1. 自动化测试必须证明：玩家能切换到正式 `missile_launcher` 模式，并能通过正式 request 发射导弹。
2. 自动化测试必须证明：`missile_launcher` 模式下不会继续生成 rifle projectile、grenade 或 laser beam。
3. 自动化测试必须证明：导弹节点会挂到 `CombatRoot/Missiles`，并消费正式 `InterceptorMissileVisual` 视觉资产。
4. 自动化测试必须证明：导弹在飞行若干 physics frame 后会产生可观测位移，并存在非零 lateral sway。
5. 自动化测试必须证明：导弹近距命中世界目标会爆炸，而不是穿透。
6. 自动化测试必须证明：导弹飞过 `500m` 会自爆，而不是静默删除。
7. 自动化测试必须证明：爆炸会触发正式 camera shake / explosion contract。
8. 自动化测试必须证明：现有 `grenade / laser / crosshair` 主链继续通过。
9. 反作弊条款：不得只把 grenade 换导弹模型；不得只让模型摆动而判定仍完全直线；不得用短寿命近似 `500m` 却不绑定真实飞行距离。

## Files

- Create: `docs/prd/PRD-0022-player-missile-launcher.md`
- Create: `docs/plans/2026-03-20-v32-player-missile-launcher-design.md`
- Create: `docs/plan/v32-index.md`
- Create: `docs/plan/v32-player-missile-launcher.md`
- Create: `city_game/combat/CityMissile.gd`
- Create: `city_game/combat/CityMissile.tscn`
- Modify: `city_game/scripts/PlayerController.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/ui/PrototypeHud.gd`
- Create: `tests/world/test_city_player_missile_launcher.gd`
- Modify: `docs/plan/v32-index.md`

## Steps

1. Analysis
   - 固定 `8` 键、`missile_launcher` mode、`500m` 自爆与 visual reuse 口径。
2. Design
   - 写 `PRD-0022`、design doc、`v32-index` 与本计划文档。
3. TDD Red
   - 先写 missile weapon contract test，覆盖切换、spawn、sway、impact explode、500m self-destruct。
4. Run Red
   - 逐条运行新测试，确认当前失败原因是 `v32` 尚未实现。
5. TDD Green
   - 新增 missile projectile/runtime scene。
   - 扩展 `PlayerController` 与 `CityPrototype`。
   - 接入既有 explosion resolver。
6. Refactor
   - 让 missile logic 尽量留在独立 projectile/runtime，而不是继续膨胀 `CityPrototype`。
7. E2E / Regression
   - 跑 missile world test。
   - 补跑 `grenade / laser / explosion` 关键回归。
8. Review
   - 更新 `v32-index` 追溯矩阵与验证证据。

## Risks

- 如果直接复用 grenade runtime，`grenade` 既有 contract 会被污染。
- 如果 missile explosion 不复用现有 resolver，行人/车辆会再长一套分叉逻辑。
- 如果 sway 只做模型旋转不做路径偏移，用户手感会像假的。
