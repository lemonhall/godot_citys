# PRD-0005 Vehicle Pedestrian Impact

## Vision

把 `godot_citys` 从“玩家能抢车并驾驶穿城移动”推进到“玩家在 driving mode 中可以用自己当前控制的车撞击近景行人，并触发可见的致死、创飞、局部恐慌和车辆减速反馈，同时继续守住 `60 FPS = 16.67ms/frame` 红线”的状态。成功标准不是把系统直接膨胀成完整事故/警察/保险模拟，而是在不破坏 `v6 pedestrian death/flee` 与 `v9 hijack driving` 既有资产的前提下，把 `驾驶 -> 撞人 -> 视觉反馈 -> crowd response -> 继续开走` 这条黑色玩法链补成正式 contract。

本 PRD 的目标用户仍然是项目开发者本人及后续协作 agent。核心价值不是追求复杂物理或 ragdoll，而是证明现有 `player driving state + pedestrian tier controller + death visual` 底盘可以消费“车撞人”这条玩法语义，而且不会把 `ambient traffic`、空车残留或 combined runtime 性能一起拖下水。

## Background

- `PRD-0002` 与 `v6` 已完成 `projectile / grenade -> pedestrian death + flee + death visual` 主链。
- `PRD-0004` 与 `v9` 已完成 `截停 -> 抢车 -> 驾驶`，但明确把“撞飞行人”排除在范围外，因此本轮必须作为新的需求集处理。
- `v8` 曾保留 `pedestrian vehicle conflict guard` 作为未来可选增强，但最新产品口径仍允许 ambient traffic 与行人穿模，因此不能把本轮偷换成人车全局事故系统。
- 当前仓库已经有 `Tier 2 / Tier 3` 近景行人、death visual 持续化、violent witness gate 和 driving mode 基础速度/相机状态。

## Scope

本 PRD 只覆盖 `v11 vehicle pedestrian impact`。

包含：

- 只有玩家当前正在驾驶的 hijacked vehicle 才能对近景行人触发撞击判定
- 撞击近景行人时，目标会进入与枪击/手雷一致的 `death` 结算，并额外产生向前创飞数米、落在车前的视觉效果
- 撞击成功后，玩家车辆速度会被立即打到个位数，但仍可继续按 `W` 加速离开
- 撞击致死会触发比枪击/手雷更小范围的局部恐慌，只作用于最近 player 的近景层，且只有约 `60%` 的候选行人进入 `panic/flee`
- HUD / runtime snapshot / tests 暴露 impact / crowd response / vehicle slowdown 结果
- 与既有 `v6` crowd runtime、`v9` driving mode、page cache、profile guard 共存

不包含：

- 不做 ambient traffic 主动撞人
- 不做玩家下车后的空车、abandoned parked vehicle 或 resumed parked visual 继续撞人
- 不做 ragdoll、持久尸体碰撞、轮胎碾压物理或车身损伤
- 不做 wanted / police / 车祸调查 / 目击者报警系统
- 不做三层事故恐慌传播；本轮只做最近 player 的近层候选

## Non-Goals

- 不追求 `v11` 阶段就交付完整 GTA 事故系统
- 不追求所有车辆、所有 tier、所有空车状态都能撞人
- 不追求把 pedestrian runtime 改造成连续物理布娃娃
- 不追求通过降低 pedestrian density、关闭 crowd 或关闭 vehicles 给撞击玩法让路

## Requirements

### REQ-0005-001 玩家驾驶车辆可对近景行人结算撞击致死与创飞

**动机**：如果驾驶中的车仍然穿过行人而没有任何反馈，驾驶主链缺少最直观的暴力交互闭环。

**范围**：

- 只有 `player.is_driving_vehicle() = true` 且玩家当前控制的 hijacked vehicle 才能触发撞击判定
- 撞击只覆盖 `Tier 2 / Tier 3` 近景行人，不要求把全城 pedestrian 升成物理碰撞体
- 被撞行人复用既有 `death` 动画/死亡结算，但在 visual 上要先被向前抛出数米，再落在车前

**非目标**：

- 不做 ambient traffic 撞人
- 不做玩家下车后空车继续撞人
- 不做 ragdoll 或尸体物理阻挡

**验收口径**：

- 自动化测试至少断言：driving mode 下命中的近景 pedestrian 会变成 `life_state = dead`，并从 live crowd snapshot 退出。
- 自动化测试至少断言：death visual 继续播放 `death/dead` 动画，而不是切成 run/walk 或直接消失。
- 自动化测试至少断言：death event 会带出创飞方向/落点信息，且最终落点位于车辆前向数米范围内，而不是仍停在原地。
- 反作弊条款：不得通过“只删掉 pedestrian state”“只播一个原地 death”“把 ambient traffic 或空车也算成撞击源”来宣称完成。

### REQ-0005-002 撞击会把玩家车辆速度打到个位数，但不锁死驾驶

**动机**：如果撞人后车辆完全无反馈，手感会失真；如果直接锁车，玩家又会被玩法打断。

**范围**：

- 成功撞击后，玩家当前 driving speed 会立刻被衰减到个位数速度区间
- 车辆仍保留 driving mode，可继续接收 `W/A/S/D` 输入并再次加速

**非目标**：

- 不做发动机熄火、翻车或复杂失控
- 不做连续多段碰撞损伤模型

**验收口径**：

- 自动化测试至少断言：撞击前车辆处于可感知巡航速度，撞击后 `speed_mps < 10.0`。
- 自动化测试至少断言：撞击后继续给正油门若干帧，车辆仍会重新加速并继续前进。
- 反作弊条款：不得通过“每帧永久钳死低速”“撞击后直接退出 driving mode”来宣称完成。

### REQ-0005-003 撞击致死会触发缩小版局部恐慌，且只有约 60% 近层候选逃亡

**动机**：车祸也会引发周边人群反应，但它与枪击/手雷的社会语义不同，不能直接复用同半径、同强度的全套 violent witness 规则。

**范围**：

- 撞击事件只作用于最近 player 的近景 pedestrian 反应层
- 使用比枪击/手雷更小的 witness / threat 半径
- 候选行人中只有约 `60%` 会进入 `panic/flee`，其余保持 ambient

**非目标**：

- 不做 `0-200m / 200-400m / >400m` 三层事故恐慌
- 不做全图 audible panic broadcast

**验收口径**：

- 自动化测试至少断言：撞击事件附近至少会有一部分幸存近层 pedestrian 进入 `panic` 或 `flee`。
- 自动化测试至少断言：超出本轮缩小半径的 pedestrian 保持 calm，不进入 panic cascade。
- 自动化测试至少断言：同一组近层候选里不会变成 `100%` 必逃，deterministic 结果应收口在约 `60%` 响应。
- 反作弊条款：不得通过“直接复用 gunshot 400m 半径”“把所有见证者都改成 flee”“把远层/全图候选都拉进来”来宣称完成。

### REQ-0005-004 `v11` 不得打穿 combined runtime 红线

**动机**：`v6` 和 `v9` 已经分别把 pedestrian/runtime 与 hijack/driving 守在线内；`v11` 不能为了撞击反馈把这些资产吞掉。

**范围**：

- 只允许新增“玩家当前驾驶车辆 vs 近景 pedestrian”这一份额外判定成本
- 既有 `pedestrian`、`vehicle`、combined runtime profiling guard 必须继续通过

**非目标**：

- 不要求 `v11` 重写 profiler
- 不要求 `v11` 让 ambient traffic 获得同等事故语义

**验收口径**：

- 相关 world/e2e 测试必须继续通过，且 `test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 继续满足 `wall_frame_avg_usec <= 16667`。
- 自动化测试至少断言：撞击流程不会引入 `duplicate_page_load_count` 回退。
- 反作弊条款：不得通过 profiling 时关闭 pedestrians、关闭撞击逻辑、降低 traffic / crowd density、或只在空场景验证来宣称达标。

## Open Questions

- 撞击是否需要低速非致死判定。当前答案：本轮不做复杂非致死分支，只要命中进入有效撞击窗口，就直接走致死链。
- 撞击后的尸体是否要参与后续碾压。当前答案：不做尸体物理，只保留 death visual + 创飞落点表现。
- ambient traffic 是否未来也要具备事故能力。当前答案：本轮明确不做，后续若要扩展需新开 PRD/ECN。
