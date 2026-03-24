# 2026-03-25 V52 Artillery Gameplay Ballistic Solver Design

## 背景

用户已经明确把本轮 artillery 范围从“尽量真实”收紧成“游戏里够像真的，但不要过于硬核”。因此这轮不追求军规级外弹道，而是冻结一套 gameplay 级 ballistic model，满足三件事：

1. 当前 M777 默认射程 envelope 固定为 `1.5km~22.5km`；
2. 给定 firing solution，系统能预测这一发大概会落到哪里；
3. 给定火炮位置和目标位置，系统能反向解出 bearing 与 pitch。

关键点不是“数学上最真实”，而是“同一套 model 同时服务 forward / inverse / live shell”，否则后面一定再次分叉。

## 方案对比

### 方案 A：继续用当前 `827m/s + gravity`

优点：

- 代码最少。

缺点：

- 极限射程会远大于 `22.5km`；
- 反解虽然容易，但与 gameplay 射程目标直接冲突；
- live shell / target solve / future HUD 会从第一天起就建立在错误 envelope 上。

### 方案 B：引入 gameplay profile + tuned solver velocity

优点：

- 可以严格冻结 `1.5km~22.5km`；
- 正解 / 反解依旧保持同一模型下的互逆关系；
- live shell runtime 也能直接吃同一 profile；
- 数学简单，测试和回归都容易做硬。

缺点：

- `solver_muzzle_velocity_mps` 不再等同于公开资料里的参考初速，需要在文档里把“reference velocity”和“solver velocity”区分开。

### 方案 C：直接做带阻力数值积分

优点：

- 更接近真实外弹道。

缺点：

- 对当前用户目标明显过度设计；
- 反解、调参、测试复杂度都会显著上升；
- 当前地图与玩法并不需要这个级别的真实度。

## 冻结结论

采用 **方案 B**。

## 设计冻结

### 1. 单一正式 ballistic utility

创建 `CityArtilleryBallistics.gd` 作为唯一真源，提供：

- `get_shell_profile(shell_type_id)`
- `build_firing_solution_from_angles(...)`
- `predict_impact_from_firing_solution(...)`
- `solve_firing_solution_to_target(...)`

### 2. 当前默认弹型

- `shell_type_id = "m795_he"`
- `min_range_m = 1500`
- `max_range_m = 22500`
- `reference_muzzle_velocity_mps = 827`
- `solver_muzzle_velocity_mps = sqrt(max_range * g)` 对应的 gameplay 求解速度

这保证 `45°` 附近 shot 的理论极限射程就是 `22.5km`。

### 3. 正向 / 反向 / live shell 共线

- howitzer payload 明确带出当前 shell profile 信息；
- forward prediction 用 shared utility；
- inverse solve 解出 bearing / pitch 后，再用 forward prediction 做 round-trip 验算；
- live shell runtime 的 launch velocity 由 shared utility 统一生成，不再保留旧的私有速度路径。

### 4. 非目标

- 不做气象、风偏、装药号、旋偏、科氏力；
- 不做预测落点 HUD；
- 不做 AI 自动装表或炮兵任务链。

## 验证策略

- ammo profile contract：卡住 `1.5km~22.5km`
- forward solver：卡住 `45°` 极限射程和结构化返回
- inverse solver：卡住 in-range / out-of-range
- round-trip：卡住 `target -> solve -> predict`
- world regression：卡住 live shell runtime 与 shared utility 共线
