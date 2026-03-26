# 2026-03-26 V58 Drone Wingman Strike Presentation Design

## 背景

`v57` 已经把机群 strike 的“命令语义”做对了，但用户手测后指出两个很具体的 presentation 缺口：

- 僚机撞地后缺少正式爆炸环与爆炸音效；
- 僚机 strike 路径过于笔直、匀速，像调试射线，不像俯冲攻击。

这两个问题都不该通过“再发明一套僚机专用大系统”来解决。最稳的做法，是把它们限定在 presentation 层：复用当前项目已有的正式爆炸语言，并在现有 strike 状态机上叠加 deterministic 的曲线路径参数。

## 方案比较

### 方案 A：抽一个共享 surface impact FX helper，并在 wingman strike 中加入 seeded dive profile

推荐方案。

- 爆炸表现：
  - 新增共享 `surface impact FX` helper；
  - 由 wingman impact 时动态创建；
  - helper 负责地面环、爆炸球、爆炸音效、自动清理。
- 路径表现：
  - wingman 在 `begin_strike()` 时冻结：
    - `path_seed`
    - lateral offset
    - arc height
    - speed curve
  - 之后沿 deterministic dive curve 前进。

优点：

- presentation 职责单独收口，不把 `CityPlayerDroneWingman.gd` 继续膨胀成 FX 仓库；
- 后续如果 missile / grenade / shell 想共用，也有清晰落点；
- deterministic 好测。

### 方案 B：直接把 missile 爆炸节点和音频代码复制进 wingman

拒绝。

- 最快，但会把爆炸表现复制成第二份实现；
- 后续改色、改音频、改时长时，必然漂移。

### 方案 C：拿 `CityMissile.tscn` 整体假扮成 impact FX

拒绝。

- 语义不对；
- 会把 missile 飞行逻辑和 wingman impact 表现耦死。

## 决策冻结

- impact FX：
  - 复用当前正式爆炸语言；
  - 必须包含：
    - 爆炸环
    - 爆炸球
    - 爆炸音效
- path：
  - 不是完美直线；
  - 不是严格恒速；
  - 不同僚机之间存在小幅 deterministic 差异；
  - 仍严格命中已冻结的 target world position。

## 实现落点

### Shared Impact FX

新增：

- `res://city_game/combat/CitySurfaceExplosionFx.gd`

职责：

- 只负责地表 impact FX 的 visual/audio 生命周期；
- 不负责弹道；
- 不负责伤害；
- 不负责 camera ownership。

### Wingman Runtime

`CityPlayerDroneWingman.gd`

- 在 `begin_strike()` 时冻结路径参数；
- 在 strike 过程中记录 path metrics；
- impact 时：
  - 先做既有伤害结算；
  - 再创建 shared impact FX；
  - 把 impact/audio/path summary 写进 `last_strike_result`。

### Squadron Runtime

`CityPlayerDroneSquadronRuntime.gd`

- 在 wingman spent 前读取完整 `last_strike_result`；
- 回写到 `recent_strike_events`，保证测试不必依赖肉眼观察。

## 测试策略

### Focused Contract

- `test_city_player_drone_squadron_wingman_impact_presentation_contract.gd`
  - 锁 impact FX / 音效存在性
- `test_city_player_drone_squadron_wingman_dive_profile_contract.gd`
  - 锁 path seed / 曲线偏移 / 速度变化

### E2E

- `test_city_player_drone_squadron_strike_presentation_flow.gd`
  - 单架 dispatch + area strike 连续执行；
  - 长机观察位不丢；
  - resolved strike events 都带 presentation summary。

### 回归

- `test_city_player_drone_squadron_single_strike_dispatch_contract.gd`
- `test_city_player_drone_squadron_area_strike_command_contract.gd`
- `test_city_player_drone_squadron_strike_flow.gd`
- `test_city_player_drone_suicide_strike_contract.gd`

## 风险

- 如果 impact FX 只做 helper，但不把结果写回 debug/event payload，测试无法稳定证明“真的播了”。
- 如果路径差异直接用真正随机数，deterministic contract 会立刻被打爆。
- 如果曲线偏移过大，会破坏已冻结的命中点合同；因此曲线路径只能做“小幅差异”，不能改 target。
