# 2026-03-24 V51 World Howitzer Summon And Ballistics Design

## 背景

`v44-v50` 已经把 M777 的包装场景、lab 操炮、fire presentation、north/bearing 语义与诸元 HUD 全部冻结，但主世界里仍然没有 howitzer 的真实存在感。用户这一轮的要求非常明确：按 `KP_8` 能在玩家面前直接召唤一门炮，主世界的操炮体验和 lab 一样，而且必须把炮弹实体、弹道与落点放进主世界，否则 howitzer 仍然只是“能动的模型”。

## 方案对比

### 方案 A：主世界再写一套 howitzer 交互逻辑

优点：

- 改动面看起来局部，只碰 `CityPrototype.gd`。

缺点：

- lab 与主世界很快会出现两套 prompt / HUD / ownership / `Space` 抑制逻辑；
- 之后任何 howitzer 手感调参都要双改；
- 最终一定回到“lab 可以，主世界又不一样”的返工状态。

### 方案 B：抽共享操炮 controller，主世界只做 host 接入

优点：

- lab 和主世界共享 `E`、`J/L`、`I/K`、`Space`、20m retention、HUD 语义；
- 主世界只负责 howitzer summon、HUD 接线和 shell spawn；
- 后续把 howitzer 接入任务、地标或服务建筑时，仍然复用同一 controller。

缺点：

- 这一轮需要顺手重构 `M777HowitzerLab.gd`。

### 方案 C：只在主世界补 shell，不收共享 controller

优点：

- 眼前开发速度最快。

缺点：

- 交互 contract 继续漂移；
- 之后只要再调一次 lab，就会立刻回到双标行为。

## 冻结结论

采用 **方案 B**。

这轮建立三条正式主链：

1. `CityM777HowitzerOperationController`
   - 负责 shared howitzer ownership、提示、输入与 HUD 状态；
   - `lab` 与 `CityPrototype` 都只做 host，不再各写一套操炮状态机。
2. `CityPrototype` world host
   - 负责 `KP_8` summon、唯一实例管理、HUD state 推送、primary interaction 接线；
   - world 侧 accepted fire 时，生成 artillery shell。
3. `CityArtilleryShell`
   - 以 howitzer `firing_solution` 为唯一 launch 真源；
   - 做带重力的正式 flight、impact 与 explosion result；
   - 复用主世界现有爆炸消费链，而不是发明 howitzer 专用伤害旁路。

## 关键设计

### 1. Summon 语义

- `KP_8` 只维护一门当前 summoned howitzer；
- 再次召唤会释放旧实例并重建到玩家当前前方；
- 放置点使用地表采样，避免悬空或插地。

### 2. Shared Operation Controller

- controller 负责：
  - 距离判定；
  - `E` 进退操炮；
  - `J/L/I/K` 驱动 yaw/pitch；
  - `Space` fire ownership 与 jump suppression；
  - interaction prompt state；
  - artillery solution HUD state；
  - operator lanyard target 同步。
- host 负责：
  - 提供 `howitzer` 与 `player`；
  - 每帧调用 `update()`；
  - 在自己的 HUD 中消费 controller state；
  - 决定 accepted fire 后是否还要生成 shell。

### 3. Ballistics

- shell launch 使用 howitzer `firing_solution`：
  - `origin_world_position`
  - `muzzle_direction_world`
  - `muzzle_velocity_mps`
- shell 保留真实发射口径，同时引入显式 `ballistic_time_scale` 来压缩 flight 等待时间；
- impact 结果接入：
  - `city_enemy`
  - `city_destructible_building`
  - `resolve_pedestrian_explosion()`
  - `resolve_vehicle_explosion()`
- world host 保存 `last_artillery_shell_explosion_result` 供测试和后续系统复用。

## 验证策略

- contract tests：
  - summon 唯一实例与地表放置；
  - world prompt / operation / HUD 与 lab 共线；
  - accepted fire 生成 live shell，shell 飞行并留下 impact result。
- e2e：
  - `KP_8 -> 靠近 -> E -> Space -> shell impact` 整链路。
