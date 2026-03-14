# PRD-0004 Vehicle Hijack Driving

## Vision

把 `godot_citys` 从“玩家只能看 ambient traffic 跑动”推进到“玩家能在不打穿 `60 FPS = 16.67ms/frame` 红线的前提下，先用子弹或手榴弹截停近景车辆，再走近按 `F` 接管，并驾驶这辆车穿城移动”的状态。成功标准不是第一轮就做成完整 GTA 载具体系，而是让 `v8` 已经守住的 ambient traffic foundation 真正长出一条最小但可玩的 `截停 -> 抢车 -> 驾驶` 主链。

本 PRD 的目标用户仍然是项目开发者本人及后续协作 agent。核心价值不是先做完整物理、撞击破坏或下车系统，而是证明现有 `vehicle_query -> layered runtime -> renderer` 底盘可以被玩家玩法消费，同时继续服从 chunk streaming、node budget 与 profiling guard。

## Background

- `PRD-0003` 已完成 `v8 ambient traffic foundation`，车辆已经具备 deterministic `vehicle_query`、lane graph、layered runtime 与 renderer。
- `PRD-0003` 明确把“玩家驾驶、载具物理、碰撞破坏”排除在 `v8` 范围外，因此 `v9` 必须作为新的需求集处理，不能回写旧范围假装它原本就在 `v8`。
- 当前玩家已经有第三人称移动、枪械与手榴弹 combat 链路，车辆 runtime 已具备 Tier 2 / Tier 3 近景实体表示。
- 当前车辆系统仍以 ambient traffic 为主，不允许为了可驾驶而把所有车辆回退成全时刚体或海量 runtime node。

## Scope

本 PRD 只覆盖 `v9 vehicle hijack driving`。

包含：

- 玩家使用 `rifle projectile` 直接命中近景车辆后触发截停
- 玩家使用 `grenade explosion` 在近景车辆附近引发截停
- 近景已截停车辆进入可接管状态，并能被玩家在近距离按 `F` 接管
- 玩家进入最小驾驶模式：隐藏步行模型、挂载被接管车辆的模型、使用基本车辆加速/刹车/转向移动
- 玩家在 driving mode 中再次按 `F` 可下车；下车后原 hijacked vehicle 保留为一个 `15` 秒可返场的 parked vehicle，期间可再次按 `F` 重新上车，超时后才消失
- HUD / runtime snapshot / tests 暴露 hijack / driving 状态
- 与现有 traffic runtime、streaming、page cache、profile guard 共存

不包含：

- 不做全城车辆刚体化
- 不做复杂撞击破坏、车辆生命值、翻车、悬挂、轮胎物理
- 不做复杂下车系统、开关门动画、座位系统、NPC 驾驶员可视化
- 不做 wanted / police chase / carjacking 反抗 / 乘客系统
- 不做“所有 tier 车辆都可被射停”的重型全局碰撞求解

## Non-Goals

- 不追求 `v9` 阶段就交付完整 GTA 载具玩法
- 不追求所有车辆都可在任意距离被精确命中并进入高级事故状态
- 不追求把玩家移动系统彻底改写成新载具控制器树
- 不追求通过降低 traffic density、关闭 renderer 或关闭 pedestrians 给驾驶玩法让路

## Requirements

### REQ-0004-001 近景车辆可被子弹或手榴弹截停

**动机**：如果车辆仍然只是纯视觉背景，玩家武器与 traffic runtime 之间没有任何行为闭环，就谈不上“抢车”。

**范围**：

- `rifle projectile` 直线命中近景车辆时，车辆进入 `stopped / hijackable` 状态
- `grenade explosion` 在近景车辆半径内爆炸时，车辆进入 `stopped / hijackable` 状态
- 截停只要求覆盖 `Tier 2 / Tier 3` 近景车辆，不要求把全城 tier 都升级成交互体

**非目标**：

- 不做车辆生命值或爆炸摧毁
- 不做远景 `Tier 1` 命中求解

**验收口径**：

- 自动化测试至少断言：projectile direct hit 能让近景车辆从 `ambient` 进入 `stopped` 状态。
- 自动化测试至少断言：grenade explosion 能让近景车辆从 `ambient` 进入 `stopped` 状态。
- 自动化测试至少断言：车辆截停后不再继续沿 lane 前进。
- 反作弊条款：不得通过“命中后直接隐藏车辆”“全局冻结所有 traffic”“把所有车都算命中”来宣称完成。

### REQ-0004-002 玩家可在近距离按 F 接管已截停车辆

**动机**：仅仅把车打停不够，必须形成可验证的 carjacking 接管闭环。

**范围**：

- 玩家与已截停车辆距离进入近距窗口后，按 `F` 可尝试接管
- 接管成功后，原 ambient traffic 中的该 `vehicle_id` 必须退出 traffic runtime 可见集合
- 接管结果必须保留原车辆的 `vehicle_id`、`model_id` 与基础尺寸信息

**非目标**：

- 不做开门动画、司机拖拽或 NPC 乘员处理
- 不做“按错键”复杂交互分支

**验收口径**：

- 自动化测试至少断言：只有 `stopped` 且处于近距窗口内的车辆才能被 `F` 接管。
- 自动化测试至少断言：接管成功后，玩家 driving state 中的 `vehicle_id / model_id` 与被接管车辆一致。
- 自动化测试至少断言：接管成功后，ambient runtime snapshot 不再把同一 `vehicle_id` 继续当作可见 traffic vehicle 渲染。
- 反作弊条款：不得通过“玩家附近凭空生成一辆新车”“不关联原 traffic state 只切模型”来宣称完成。

### REQ-0004-003 接管后玩家进入最小驾驶模式

**动机**：用户要的是能马上开着抢来的车在城里跑，而不是只切一个静态壳子。

**范围**：

- 接管成功后，玩家进入 driving mode
- driving mode 隐藏步行模型，显示被接管车辆模型
- driving mode 提供基本前进、倒车/刹车、转向与第三人称跟随镜头
- driving mode 禁用步行态跳跃、攀墙、地面砸击与射击

**非目标**：

- 不做漂移、手刹、碰撞伤害、撞飞行人
- 不做下车系统

**验收口径**：

- 自动化测试至少断言：进入 driving mode 后，步行模型隐藏且玩家状态明确报告 `driving = true`。
- 自动化测试至少断言：驱动车辆数十帧后，玩家世界位置与朝向发生可观测变化，而不是只换壳不移动。
- 自动化测试至少断言：持续加速若干帧后，driving state 会达到调优后的可感知巡航速度，而不是停留在明显迟滞的低速基线。
- 自动化测试至少断言：driving mode 下不会继续触发步行 combat/traversal 动作。
- 反作弊条款：不得通过直接把玩家切到 inspection 飞行感速度、或只做模型替换没有车辆控制，来宣称完成。

### REQ-0004-004 v9 不得打穿 traffic / combined runtime 红线

**动机**：`v8` 的价值就在于已经把 traffic runtime 守到红线内；`v9` 不能靠新玩法把这些性能资产吃光。

**范围**：

- `v8` 既有 vehicle runtime guard、page cache、combined runtime profiling 仍需通过
- `v9` 新增 hijack / driving 逻辑只能引入单玩家驱动车辆这一份额外 runtime 成本

**非目标**：

- 不要求 `v9` 阶段重写现有 traffic profiler
- 不要求 `v9` 阶段做 full traffic mode

**验收口径**：

- 相关 world tests 与 `test_city_vehicle_runtime_node_budget.gd` 必须继续通过。
- `test_city_runtime_performance_profile.gd` 与 `test_city_first_visit_performance_profile.gd` 必须继续通过现有 `16.67ms/frame` 红线。
- 自动化测试至少断言：接管/驾驶过程中不出现 `duplicate_page_load_count` 回退。
- 反作弊条款：不得通过 profiling 时关闭 hijack feature、关闭 vehicles、降低 traffic density 到近乎 `0`、或仅在空场景验证来宣称达标。

### REQ-0004-005 玩家可从 driving mode 下车，原 hijacked vehicle 短暂残留后消失

**动机**：一旦玩家已经把车抢到手，必须能以最小交互成本回到步行态；否则玩家会被锁死在驾驶态里，玩法闭环不完整。

**范围**：

- 玩家处于 driving mode 时，再次按 `F` 可退出驾驶并恢复 player on-foot 状态
- 下车后原 hijacked vehicle 允许以单个 `15` 秒可返场 parked vehicle 停留在场景里，期间可再次按 `F` 重新接管，超时后自动消失
- 退出 driving mode 后不得把同一 `vehicle_id` 再塞回 ambient traffic runtime

**非目标**：

- 不做停车保持、重新上同一辆残留车、开关门或乘员同步
- 不做复杂下车碰撞检测、车门朝向选择或残车物理

**验收口径**：

- 自动化测试至少断言：driving mode 中再次触发 `F` 交互后，玩家恢复 `driving = false`，步行模型重新显示。
- 自动化测试至少断言：下车后场景内只留下一个 `15` 秒可返场的 hijacked vehicle parked visual，期间按 `F` 可重新上车并继续驾驶。
- 自动化测试至少断言：若玩家在 `15` 秒内未重新上车，该 parked vehicle 会在超时后自动清理。
- 自动化测试至少断言：下车期间与清理之后，ambient runtime snapshot 仍然不会重新出现同一 `vehicle_id`。
- 反作弊条款：不得通过“按 F 直接清空玩家状态但不恢复步行模型”“下车瞬间整车立刻消失”“把 hijacked vehicle 重新塞回 traffic runtime 继续跑”来宣称完成。

## Open Questions

- `v9` 是否需要立刻支持下车。当前答案：需要最小版本，只做 `F` 退出驾驶 + `15` 秒可返场 parked vehicle；不做复杂下车系统。
- `v9` 是否需要车辆撞击伤害。当前答案：不需要，避免 scope 扩张。
- `v9` 是否需要远景 `Tier 1` 命中。当前答案：不需要，只做近景可互动层。
