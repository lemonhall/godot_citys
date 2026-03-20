# V32 Player Missile Launcher Design

## Summary

`v32` 采用“新 weapon mode + 新 live missile projectile + 复用既有 explosion resolver”的方案。`PlayerController` 继续只负责 mode / signal / input；`CityPrototype` 继续负责真正的 spawn；新 missile projectile 自己管理飞行、轻微摆动、碰撞与 `500m` 自爆；爆炸则直接复用当前 `grenade` 已经接通的 enemy / pedestrian / vehicle 影响主链。这样能把新武器做成正式 combat 资产，同时避免再复制一套 crowd/traffic damage 系统。

## Options

### Option A: 独立 missile projectile，复用现有 explosion resolver

推荐方案。

- 新增正式 `missile_launcher` mode 与 signal
- 新增 `CityMissile.gd` / `CityMissile.tscn`
- 运行时实例化 `InterceptorMissileVisual.tscn` 作为 visual child
- missile 自己做：
  - 前向飞行
  - 轻微 sway / wobble
  - ray/path 碰撞
  - 超过 `500m` 自爆
- `CityPrototype` 只在爆炸时调用既有：
  - `resolve_explosion_impact`
  - `resolve_vehicle_explosion`

优点：

- 与现有 `PlayerController -> CityPrototype` 架构一致
- 风险低
- 可直接复用 v29 视觉资产
- 测试边界清晰

缺点：

- 需要一份新的 projectile runtime

### Option B: 直接把 grenade 改成“导弹视觉 + 直线飞”

不推荐。

优点：

- 代码最少

缺点：

- 会把 grenade 的弧线合同打坏
- 后续测试会变脏
- 语义错误：导弹不是手雷

### Option C: 把 Missile Command runtime 的 interceptor 轨迹直接移植为玩家武器

不采用。

原因：

- `v29` 的 interceptor 是固定炮台平面玩法，输入和坐标语义不同
- 直接搬 runtime 会把玩家武器链和 minigame 链耦死
- 需要额外剥离 `battery_mode` 相关状态

## Frozen Design

- 正式 weapon mode：`missile_launcher`
- 正式切换热键：`8`
- 新增 signal：`missile_launcher_requested`
- 新增 runtime projectile：
  - `res://city_game/combat/CityMissile.gd`
  - `res://city_game/combat/CityMissile.tscn`
- 新增 combat root：
  - `CombatRoot/Missiles`
- 视觉复用：
  - `res://city_game/assets/minigames/missile_command/projectiles/InterceptorMissileVisual.tscn`
- 结束条件冻结：
  - 碰撞即爆炸
  - `distance_travelled_m >= 500.0` 自爆
- wobble 设计冻结为：
  - 主轨迹仍朝向瞄准方向前进
  - 在垂直于主方向的局部平面里叠加低幅值、低频 sway
  - 视觉和命中位置共用同一偏移，避免“模型在摆但判定是直线”

## Data Flow

`PlayerController(missile mode)`
-> `missile_launcher_requested`
-> `CityPrototype._on_player_missile_launcher_requested()`
-> `_spawn_missile(origin, direction, player, player)`
-> `CityMissile`
-> hit / max_distance reached
-> explode
-> `CityPrototype._on_player_missile_exploded()`
-> existing explosion resolvers + camera shake

## Test Strategy

- world contract test 优先锁定：
  - `8` 键/正式 mode
  - missile spawn
  - no rifle/grenade/laser regression
  - `500m` 自爆
  - live sway
- 再补一条 e2e/flow 或 explosion 回归：
  - 证明 missile explosion 能进入现有 resolver 主链

## Why This Fits The Repo

- 与 `v15` 武器模式扩展方式一致
- 与 `CityPrototype` 当前 combat root 架构一致
- 最大化复用 `v29` 的导弹视觉资产
- 不把 minigame runtime 和玩家武器 runtime 强绑在一起
