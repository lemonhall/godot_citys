# PRD-0027 Drone Flight Foundation

## Vision

`godot_citys` 现在已经有成熟的玩家控制器、主世界 debug hotkey 分发、独立 lab-first 工作流，以及一份已经正式归档的无人机视觉资产，但还没有一条**玩家自有、可部署、可回收、可被正式测试锁定**的无人机主链。`PRD-0027` 的目标不是“按一个键在空中冒出一架模型”，也不是“临时切一个 inspection camera 假装在飞”；它要建立一条正式的第三人称无人机基础链：玩家按下**小键盘 `5`** 后，无人机在玩家身旁完成一段约 `2.0s` 的放飞动画，随后系统完全接管视角和输入，玩家身体、位置、武器、准星与鼠标瞄准全部被冻结，控制权转交给一架自稳定、第三人称追踪视角的无人机。再次按下**同一个小键盘 `5`** 时，无人机自动执行回收动画，飞回玩家身旁并归位，动画结束后才把完整控制权交还给玩家。

这轮成功标准不是“能往前飞”，而是同时满足六件事。第一，正式无人机系统必须落在 `city_game/combat/drone/` 目录，**不再依附 `helicopter` combat runtime**；可以复用现有 rotor blur shader，但飞控、状态机、相机与输入接管必须是 drone 自己的主链。第二，入口键必须冻结为**小键盘 `5` (`KEY_KP_5`)**，不是主键盘 `5`；放飞与回收都绑定在同一个键上，并且在 transition 期间重复按键必须被正式忽略。第三，放飞与回收都必须是 formal sequence，而不是“瞬移生成 / 瞬移消失”；视角切换必须在放飞动画结束后才发生，玩家控制恢复必须在回收动画结束后才发生。第四，活跃无人机必须是**第三人称自稳定飞行**，输入语义接近玩家水中移动：`W/A/S/D` 平面移动、`E` 与 `Space` 上升、`Q` 下降，但姿态与速度必须更平滑，有 hover 与 auto-brake，而不是穿越机式的 acro/FPV。第五，本轮只做 foundation，不做武器挂载、侦察 UI、电池、失联、碰撞伤害、任务接入或 autonomous AI。第六，主世界与未来独立 lab wrapper 必须共享同一套 drone runtime；不得先做一个 main-world 版本，再做一套 lab-only 版本。

## Background

- 当前主世界输入热键由：
  - `res://city_game/scripts/CityPrototype.gd`
  - `handle_debug_keypress(keycode, physical_keycode)`
  负责分发。
- 当前玩家移动器已经存在接近目标语义的水中 traversal：
  - `res://city_game/scripts/PlayerController.gd`
  - `_process_water_traversal(delta)`
  - `_read_move_input()`
  - `_read_water_vertical_input()`
- 当前正式无人机资产与视觉 scene 已存在：
  - `res://city_game/assets/environment/source/aircraft/drone_a.glb`
  - `res://city_game/combat/drone/CityDroneGunship.tscn`
- 当前无人机场景只是视觉 authoring 起点；它暂时仍引用直升机脚本做 placeholder runtime，这个状态**不是正式设计终点**。
- 用户已经冻结的交互前提：
  - 入口键只认小键盘 `5`
  - 第一次按下：放飞
  - 无人机已在空中时再次按下：回收
  - 放飞/回收都要有约 `2.0s` 动画
  - 动画结束后才切到无人机第三人称视角
  - 活跃期间玩家控制器位置和输入全部锁死

## Scope

本 PRD 只覆盖 `drone flight foundation`。

包含：

- 正式玩家无人机 runtime / state machine
- 小键盘 `5` 放飞 / 回收 toggle contract
- 放飞 / 回收 formal animation sequence
- 无人机第三人称 chase camera takeover
- 自稳定 hover flight foundation
- 玩家控制冻结 / 恢复 contract
- debug state、focused tests 与 future lab portability hooks

不包含：

- 不做无人机开火、导弹、机枪、投弹或挂载武器
- 不做第一人称 FPV / 穿越机 / acro mode
- 不做 battery、续航、信号丢失、返航失控或 GPS 模拟
- 不做拍照、录像、侦察面板、目标标记或 minimap picture-in-picture
- 不做敌对 AI、自动巡航、自动避障、路径规划或 waypoint
- 不做碰撞伤害、玩家失败态、坠机爆炸或维修系统
- 不做任务 pin / world ring / map route 接入

## Non-Goals

- 不追求首版就做“大疆全功能摄影无人机”
- 不追求把玩家相机直接绑到 drone 节点上就算完成
- 不追求让无人机沿用直升机 orbit / missile / defeat runtime
- 不追求在没有 formal deploy / recover sequence 的情况下先做瞬切试玩
- 不追求先把主世界做通、以后再回头补 lab portability contract

## Requirements

### REQ-0027-001 系统必须提供正式的 drone-only scene/runtime 主链

**动机**：用户已经明确指出“无人机和直升机没关系”；现有 `CityDroneGunship.tscn` 只能作为视觉与 rotor blur authoring 起点，不能把正式飞控建立在 `helicopter` combat runtime 上。

**范围**：

- 正式无人机 scene/runtime 必须位于：
  - `res://city_game/combat/drone/`
- 允许复用：
  - `drone_a.glb`
  - 通用 rotor blur shader
  - editor debug preview helper
- 不允许复用：
  - 直升机炮艇的 combat state machine
  - 直升机导弹 / 击落 / orbit attack runtime
- drone foundation 必须显式拆出：
  - deploy / recover state machine
  - active flight controller
  - camera ownership
  - player lock contract

**验收口径**：

- 自动化测试至少断言：正式 drone runtime script path 位于 `combat/drone/`，而不是 `combat/helicopter/`。
- 自动化测试至少断言：正式 drone scene 继续消费 `drone_a.glb`。
- 反作弊条款：不得把直升机脚本换个文件名或加一层 wrapper 就宣称“无人机已独立”。

### REQ-0027-002 小键盘 `5` 必须成为放飞 / 回收的唯一正式入口

**动机**：用户已经明确冻结入口是小键盘 `5`；而 Godot 里主键盘 `5` 与小键盘 `5` 是两个不同常量，不能混淆。

**范围**：

- 正式入口键冻结为：
  - `KEY_KP_5`
- 主键盘 `5`：
  - `KEY_5`
  - 本轮不得触发无人机系统
- 按键语义冻结为：
  - `stowed` 状态下按 `KEY_KP_5` -> 进入 `deploying`
  - `active` 状态下按 `KEY_KP_5` -> 进入 `recovering`
  - `deploying` / `recovering` 期间重复按 `KEY_KP_5` -> 忽略，不排队
- 当下列模式占用输入时，系统必须显式拒绝放飞并返回 formal reason：
  - full map open
  - dialogue / interaction modal
  - driving vehicle
  - missile command mode
  - 其他明确禁用玩家输入接管的模式

**验收口径**：

- 自动化测试至少断言：`KEY_KP_5` 会触发放飞 / 回收 toggle。
- 自动化测试至少断言：`KEY_5` 不会触发无人机系统。
- 自动化测试至少断言：transition 期间重复按键不会把状态机打乱。

### REQ-0027-003 放飞必须是 formal sequence，并在结束后才切换到无人机第三人称视角

**动机**：用户不要“按下键就立刻切视角”的硬切；他要先看到无人机从玩家身边升空，再把视角完全交给无人机。

**范围**：

- 放飞 sequence 目标时长冻结为：
  - `2.0s ± 0.35s`
- 放飞起点必须基于玩家回收锚点附近的 authored world position，而不是场景固定原点。
- 放飞最小视觉流程冻结为：
  - 无人机出现在玩家侧后或侧前的回收锚点
  - 缓慢升空
  - 进入初始 hover 位
  - transition 结束后切到无人机 chase camera
- 玩家在 `deploying` 全阶段必须：
  - 位置冻结
  - 移动输入失效
  - 武器输入失效
  - 准星 / ADS / primary fire 失效

**验收口径**：

- 自动化测试至少断言：进入 `deploying` 后，玩家位置在 sequence 结束前保持冻结。
- 自动化测试至少断言：camera owner 只会在 deploy sequence 结束后从 player 切到 drone。
- 自动化测试至少断言：deploy sequence 期间玩家武器与准星输入不再生效。

### REQ-0027-004 回收必须是 formal return sequence，并在结束后才恢复玩家控制

**动机**：用户要求再次按小键盘 `5` 时不是“秒收”，而是让无人机飞回玩家身边并完成一段明确的归位动画。

**范围**：

- 回收 sequence 目标时长冻结为：
  - `2.0s ± 0.35s`
- 回收最小视觉流程冻结为：
  - active drone 退出手动飞行
  - 自动飞向玩家回收锚点
  - 降到归位高度
  - sequence 结束后隐藏 / stow drone
  - 恢复玩家 camera owner 与 input owner
- 玩家在 `recovering` 全阶段继续保持：
  - 位置冻结
  - 输入冻结
- 回收首版允许：
  - 直接插值 / 曲线飞回
  - 不做 obstacle avoidance

**验收口径**：

- 自动化测试至少断言：active 状态按下 `KEY_KP_5` 会进入 `recovering`。
- 自动化测试至少断言：recover sequence 结束前，玩家控制不会提前恢复。
- 自动化测试至少断言：recover complete 后 drone runtime 回到 `stowed`，玩家 camera/input owner 恢复为 player。

### REQ-0027-005 活跃无人机必须提供第三人称自稳定飞行，而不是穿越机或 inspection camera

**动机**：用户已经明确把手感目标冻结为“像大疆一样的自稳定第三人称飞行”，而不是高速 acro 或单纯漂浮 inspection camera。

**范围**：

- 活跃飞行必须是第三人称 chase camera，不做 first-person FPV。
- 平面移动输入冻结为：
  - `W` 前进
  - `S` 后退
  - `A` 左移
  - `D` 右移
- 垂直输入冻结为：
  - `E` 上升
  - `Q` 下降
  - `Space` 不再承担无人机抬升语义；该键位必须让位给更高优先级的 howitzer `Space` 击发链，避免无人机与操炮复合模式发生输入抢占
- 平面移动坐标系冻结为：
  - 基于 drone chase camera yaw 的相对平面
- 自稳定语义冻结为：
  - 松手后自动 hover
  - 速度渐进加减速
  - 视觉 pitch / roll 随指令或速度有阻尼倾斜
  - yaw 平滑，而不是瞬时硬转
- 本轮不得实现：
  - acro 翻滚
  - 手动油门持续下坠模型
  - 独立准星射击

**验收口径**：

- 自动化测试至少断言：`W/A/S/D` 影响的是 camera-relative planar velocity，而不是玩家身体移动。
- 自动化测试至少断言：`E` 提供上升输入，`Q` 提供下降输入。
- 自动化测试至少断言：active drone 下单独按 `Space` 不会再触发无人机抬升，确保该键位可以在与 howitzer 复合操作时继续归 howitzer `Space` 击发所有。
- 自动化测试至少断言：无人机在释放输入后会回到 near-zero velocity hover，而不是继续漂移或立刻硬停。
- 反作弊条款：不得把 active drone 仅实现成“一个 inspection camera 沿着位移向量移动”。

### REQ-0027-006 系统必须冻结 player lock / camera ownership / debug state contract

**动机**：这条链最容易坏的不是模型，而是“玩家到底是不是被完全锁住了”“当前谁拥有相机和输入”“transition 是否中途泄漏控制权”。

**范围**：

- 系统必须暴露只读 debug state，最小字段至少包括：
  - `system_state`
  - `camera_owner`
  - `input_owner`
  - `transition_progress`
  - `player_locked`
  - `drone_visible`
  - `drone_world_position`
  - `planar_velocity_mps`
  - `vertical_velocity_mps`
  - `last_reject_reason`
- shared runtime 必须允许：
  - `CityPrototype` 接入
  - future standalone labs 接入
- 不允许：
  - main world 一套 runtime
  - Spider / other labs 再造一套 drone-only runtime

**验收口径**：

- focused tests 至少覆盖：
  - toggle contract
  - deploy / recover state machine
  - camera takeover contract
  - flight input contract
  - world wrapper contract
  - portability contract
- 不接受只靠手测说“控制应该已经切过去了”。

## Acceptance Summary

- 小键盘 `5` 成为无人机放飞 / 回收唯一正式入口；主键盘 `5` 不触发。
- 放飞 / 回收都拥有约 `2.0s` 的 formal sequence。
- 放飞结束后才切到无人机第三人称 chase camera。
- 回收结束后才恢复玩家完整控制权。
- 活跃无人机是第三人称自稳定飞行：`W/A/S/D` 平移、`E/Space` 上升、`Q` 下降、松手 hover。
- drone runtime 正式脱离直升机 combat runtime。
