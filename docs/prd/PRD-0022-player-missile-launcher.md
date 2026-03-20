# PRD-0022 Player Missile Launcher Weapon

## Vision

把 `godot_citys` 的玩家武器系统从“现有 `rifle / grenade / laser_designator` 三种正式模式”推进到“拥有一把真正重型、可见、可飞行、可爆炸的导弹武器”。`v32` 的目标不是把 `Missile Command` 的场馆逻辑硬搬到玩家身上，也不是临时造一枚没有视觉质量的火箭弹，而是把 `v29` 已经验证过的导弹视觉资产、尾焰质感与飞行气质正式移植到主武器系统里，形成 `8` 号武器 `missile_launcher`。玩家切换到该武器后，左键发射一枚可见导弹；导弹沿真实飞行路径前进，触碰任何世界命中就爆炸，若持续飞行超过 `500m` 也会自爆；爆炸继续接入现有行人、车辆与敌人伤害主链，而不是长出第二套孤立 resolver。

`v32` 的成功标准不是“按 8 后屏幕文案改了”，也不是“空中多了个球形爆炸特效”。它必须同时满足四件事。第一，`missile_launcher` 必须成为正式 weapon mode，并接入 `PlayerController -> CityPrototype -> combat root` 现有链路，`8` 键和左键输入都走正式 request/signal contract。第二，live missile 必须复用正式导弹视觉资产，包含尾焰，并在运行时带有轻微摇摆/摆动感，而不是一条僵硬直线。第三，导弹必须拥有明确的结束条件：碰撞即爆炸，超过 `500m` 或等价 flight budget 也会自爆，且爆炸会进入既有 enemy / pedestrian / vehicle 影响链。第四，这一轮不能把现有 `rifle / grenade / laser_designator`、HUD crosshair、爆炸 witness 传播与载具停止链打坏。

## Background

- `PRD-0008` 与 `v15` 已冻结正式 weapon mode 主链：`PlayerController` 负责 mode / signal / input，`CityPrototype` 负责真正的 fire / trace / spawn。
- `PRD-0019` 与 `v29` 已沉淀 `Missile Command` 导弹视觉资产，包括：
  - `InterceptorMissileVisual.tscn`
  - 正式导弹模型
  - 尾焰/残影
  - 预览态中可见的轻微摆动飞行风格
- 当前仓库已有：
  - `CityProjectile.gd`：步枪直线命中链
  - `CityGrenade.gd`：抛物线 + 爆炸链
  - `chunk_renderer.resolve_explosion_impact()`：行人爆炸结算
  - `chunk_renderer.resolve_vehicle_explosion()`：车辆爆炸结算
- 用户本轮需求已冻结为：
  - `8` 号武器
  - 发射后是 live missile，不是 hitscan
  - 触碰任何东西就爆炸
  - 飞过 `500m` 也会爆炸
  - 需要保留导弹飞行时略微摇摆的质感

## Scope

本 PRD 只覆盖 `v32 player missile launcher weapon`。

包含：

- 新增正式 weapon mode：`missile_launcher`
- `8` 键切换武器
- 左键发射导弹 request / signal / spawn 主链
- 新增 live missile projectile/runtime scene
- 复用 `InterceptorMissileVisual` 作为正式 missile visual
- live missile 飞行中的轻微 sway / wobble
- 触碰命中即爆炸
- 飞行超过 `500m` 自爆
- 爆炸接入既有 enemy / pedestrian / vehicle resolver
- HUD / crosshair / weapon status 文案更新
- 补齐 world / e2e tests 与 verification 文档

不包含：

- 不做锁定目标、追踪导引或热寻的
- 不做导弹库存、装填、冷却 UI 或弹药箱系统
- 不做肩扛火箭筒第一人称持枪建模
- 不做新的爆炸音效系统或任务/成就联动
- 不把 `Missile Command` 的固定炮台玩法输入直接复制到玩家模式

## Non-Goals

- `v32` 首版不追求真实军武模拟或复杂弹道学
- `v32` 首版不追求新的专属 HUD 面板；默认复用现有 crosshair / debug status 体系
- `v32` 首版不要求导弹能穿透后再延迟爆炸；首碰即炸
- `v32` 首版不要求用导弹替代现有 grenade 的全部战术作用

## Requirements

### REQ-0022-001 系统必须提供正式的 `missile_launcher` weapon mode 与 `8` 键输入合同

**动机**：如果只是运行时偷塞一个 debug fire API，就不是正式武器系统的一部分。

**范围**：

- `PlayerController` 新增正式 weapon mode：`missile_launcher`
- `8` 键切换到 `missile_launcher`
- 左键在该模式下触发正式 missile fire request
- 右键默认允许继续复用 ADS / crosshair 口径；本轮不单独发明 missile-only alt fire
- `missile_launcher` 模式下不得继续发射 rifle projectile、grenade 或 laser beam

**非目标**：

- 不要求本轮为 `missile_launcher` 新增独立快捷键帮助面板

**验收口径**：

- 自动化测试至少断言：玩家可切换到正式 `missile_launcher` 模式。
- 自动化测试至少断言：`request_primary_fire()` 在该模式下不会继续生成 rifle projectile。
- 自动化测试至少断言：左键/正式 request 会生成 missile，不会继续生成 grenade 或 laser beam。
- 反作弊条款：不得只改 HUD 文案或 debug status 文字而不新增正式 mode/signal。

### REQ-0022-002 系统必须生成正式的 live missile projectile，并复用导弹视觉资产

**动机**：用户明确要的是“之前那个导弹”，不是一个临时圆球。

**范围**：

- 新增正式 missile projectile/runtime scene
- 该 projectile 必须复用 `InterceptorMissileVisual.tscn` 作为视觉主体
- live missile 必须保留尾焰
- live missile 飞行必须具有可感知但克制的 sway / wobble，而不是完全僵硬直线
- missile 运行态最小 contract 至少包含：
  - `get_velocity()`
  - `has_exploded()`
  - `get_distance_travelled_m()`

**非目标**：

- 不要求把 preview 脚本整份搬进 runtime projectile

**验收口径**：

- 自动化测试至少断言：导弹节点会挂在正式 combat root 下。
- 自动化测试至少断言：导弹节点内存在正式 `InterceptorMissileVisual` 消费链，而不是临时球体占位。
- 自动化测试至少断言：导弹在飞行若干 physics frame 后会移动，并呈现非零横向摆动偏差。
- 反作弊条款：不得把“摇摆感”偷换成随机旋转模型但实际轨迹仍完全无变化。

### REQ-0022-003 导弹必须在触碰命中或飞行超过 `500m` 时爆炸

**动机**：这是用户本轮直接冻结的规则边界。

**范围**：

- 导弹 ray/path 命中世界静态碰撞、敌人、近景载具或其他正式命中对象时立即爆炸
- 导弹若持续飞行超过 `500m`，即使没有命中任何东西也必须自爆
- 爆炸必须进入现有爆炸影响主链：
  - enemy hit
  - pedestrian explosion
  - vehicle explosion
- 爆炸必须暴露 radius / world_position contract

**非目标**：

- 不要求本轮支持穿透多个目标

**验收口径**：

- 自动化测试至少断言：导弹在近距命中世界目标时会进入 exploded 状态，而不是穿透后继续飞。
- 自动化测试至少断言：导弹飞行超过 `500m` 时会自爆，而不是 silently queue_free。
- 自动化测试至少断言：爆炸会触发正式 camera shake / explosion contract，而不是只有节点消失。
- 反作弊条款：不得把 `500m` 自爆偷换成固定短寿命 `1-2s`，除非它在当前速度下严格等价于 `500m`。

### REQ-0022-004 v32 必须保住现有 weapon / combat / HUD 主链

**动机**：新武器不能以破坏既有三把武器和爆炸链为代价。

**范围**：

- 现有 `rifle / grenade / laser_designator` 测试继续通过
- crosshair 可见性语义不回退
- 现有行人爆炸 witness 与车辆爆炸停止链继续通过

**非目标**：

- 不要求本轮对旧武器做额外平衡性调整

**验收口径**：

- 自动化测试至少断言：`test_city_player_grenade.gd`、`test_city_player_laser_designator.gd` 等现有关键武器测试继续通过。
- 若改动触及爆炸主链，至少补跑一条行人或车辆 explosion 回归。
- 反作弊条款：不得通过跳过旧测试、禁用旧武器或 headless 特判来宣称 v32 完成。

## Success Metrics

- 玩家在主世界中按 `8` 能切出正式导弹武器
- 左键能发出一枚肉眼可见、带尾焰和轻微摆动的导弹
- 导弹命中目标或飞过 `500m` 会可靠爆炸
- 旧武器与爆炸主链不回退

## Open Follow-Ups

- `v33+` 可考虑锁定式制导、弹药限制、重武器切换动画
- `v33+` 可考虑专属 HUD、装填节奏与音效
