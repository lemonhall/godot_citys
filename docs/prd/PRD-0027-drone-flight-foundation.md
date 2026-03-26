# PRD-0027 Drone Flight Foundation

## Vision

`godot_citys` 现在已经有成熟的玩家控制器、主世界 debug hotkey 分发、独立 lab-first 工作流，以及一份已经正式归档的无人机视觉资产，但还没有一条**玩家自有、可部署、可回收、可被正式测试锁定**的无人机主链。[已由 ECN-0040 变更] `PRD-0027` 的目标不再停留在“单架无人机 toggle”，而是扩展为一条正式的第三人称无人机主链 + 机群召唤控制基础：玩家短按**小键盘 `5`** 时，系统先按既有合同放飞一架长机；此后继续短按同一个键，会在长机周围逐架增援僚机，直到命中当前冻结的总编制上限。长按**同一个小键盘 `5`** 时，则触发“全部回收”语义：僚机退出当前编队，长机执行正式回收流程，动画结束后才把完整控制权交还给玩家或交还给回收前的正式交互上下文。

这轮成功标准不是“能往前飞”，而是同时满足六件事。第一，正式无人机系统必须落在 `city_game/combat/drone/` 目录，**不再依附 `helicopter` combat runtime**；可以复用现有 rotor blur shader，但飞控、状态机、相机与输入接管必须是 drone 自己的主链。第二，入口键必须冻结为**小键盘 `5` (`KEY_KP_5`)**，不是主键盘 `5`；放飞与回收都绑定在同一个键上，并且在 transition 期间重复按键必须被正式忽略。第三，放飞与回收都必须是 formal sequence，而不是“瞬移生成 / 瞬移消失”；视角切换必须在放飞动画结束后才发生，玩家控制恢复必须在回收动画结束后才发生。第四，活跃无人机必须是**第三人称自稳定飞行**，输入语义接近玩家水中移动：`W/A/S/D` 平面移动、`E` 上升、`Q` 下降，但姿态与速度必须更平滑，有 hover 与 auto-brake，而不是穿越机式的 acro/FPV。第五，本轮只做 foundation，不做武器挂载、侦察 UI、电池、失联、碰撞伤害、任务接入或 autonomous AI。第六，主世界与未来独立 lab wrapper 必须共享同一套 drone runtime；不得先做一个 main-world 版本，再做一套 lab-only 版本。

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
  - 第一次短按：放飞长机
  - 长机已在空中后，继续短按：逐架增援僚机
  - 长按同一个键：全部回收
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

### REQ-0027-007 小键盘 `5` 必须升级为机群召唤控制热键，而不是只会单架 toggle

**动机**：用户已经明确把本轮目标收束为“无人机机群的召唤控制合同”，并冻结了 `KP_5` 的长短按语义：短按逐架增援，长按全部回收。

**范围**：

- 系统必须冻结一条总编制上限：
  - 当前版本总上限为 `10` 架；
  - 该数量口径包含长机本身。
- `KEY_KP_5` 的正式语义变更为：
  - `stowed + 短按` -> 放飞长机，机群总数变为 `1`
  - `leader engaged + 短按` -> 机群总数 `+1`
  - `leader engaged + 长按` -> 全部回收
- 主键盘 `5`：
  - `KEY_5`
  - 仍不得触发无人机系统。
- 本轮不要求：
  - 用数字键直选机群数量
  - 多种编队模式切换
  - 战术命令或攻击命令

**验收口径**：

- 自动化测试至少断言：短按 `KP_5` 会把总机群数从 `0` 提到 `1`，并保持长机 takeover 语义不变。
- 自动化测试至少断言：长机已 engaged 时再次短按 `KP_5` 会把总机群数按 `1` 递增，直到 `10` 架封顶。
- 自动化测试至少断言：长按 `KP_5` 会把总机群数清回 `0`，而不是只回收长机或只清理僚机。
- 自动化测试至少断言：`KEY_5` 不会触发机群系统。

### REQ-0027-008 僚机首版必须保持可见分散编队，而不是生成后挤成一团

**动机**：用户本轮并不要求完整 flocking/战术 AI，但明确要求“模型层面不挤在一块”。因此首版必须先冻结一条最小可见编队合同。

**范围**：

- 长机仍然是唯一：
  - camera owner
  - input owner
  - FPV/ADS owner
  - artillery composite owner
- 僚机首版只承担：
  - 生成
  - 跟随长机
  - 保持分散 slot
- 僚机首版不承担：
  - 独立玩家切换控制
  - 独立 FPV
  - 开火 / 自爆 / 任务交互
  - 正式 flocking / 避障 / 队形命令
- 至少要提供一条稳定的默认编队：
  - 允许是左右交错、楔形或梯形；
  - 但不得让僚机与长机或彼此长期处于明显重叠状态。

**验收口径**：

- 自动化测试至少断言：召出 `3+` 架后，leader 与 wingmen 的世界位置存在可复核的最小分离距离。
- 自动化测试至少断言：短按继续增援时，camera owner 与 input owner 仍保持在长机上，不会被新僚机抢走。
- 反作弊条款：不得只在 debug state 里虚报“有 3 架”，实际场景里仍只有 1 个模型。

### REQ-0027-009 机群回收不得破坏既有正式交互上下文

**动机**：当前项目已经存在 `drone + howitzer` 复合态；用户明确要求机群控制不能把这条上下文链打坏。

**范围**：

- 当长机处于普通飞行上下文时：
  - 长按 `KP_5` 全收回后
  - 必须回到玩家正式控制上下文。
- 当长机处于 `howitzer 操炮 active + drone active` 复合上下文时：
  - 长按 `KP_5` 全收回后
  - 必须回到 howitzer 操炮上下文；
  - artillery HUD 不得消失；
  - `Space` / `I/K/J/L` 这些操炮链不得被无人机收回动作偷偷吃掉。
- 本轮不要求：
  - 僚机在回收过程中保留单独镜头
  - 多机逐架回收表演

**验收口径**：

- 自动化测试至少断言：复合态下长按 `KP_5` 后，howitzer operation 仍保持 active。
- 自动化测试至少断言：复合态下长按 `KP_5` 后，artillery solution HUD 仍保持可见。
- 自动化测试至少断言：全收回完成后，drone camera ownership 已释放，但 howitzer 操炮 ownership 没有被一并释放。

### REQ-0027-010 机群存在僚机时，FPV 左键必须优先派遣单架僚机自杀冲锋，而不是让长机先去送死

**动机**：用户已经明确冻结了新的攻击语义：当机群里还有僚机可用时，长机优先保留观察与控制职责，左键只派 1 架僚机去执行自杀冲锋；只有真正只剩最后一架长机时，才回退到当前“长机自爆 + NO SIGNAL closeout”的旧链。

**范围**：

- 当 `leader active + FPV ADS active + active wingman count >= 1` 时：
  - `MOUSE_BUTTON_LEFT`
  - 必须优先派遣 1 架可用僚机执行自杀冲锋；
  - 当前版本允许“任取 1 架”，但实现必须 deterministic，便于测试回归；
  - 长机不得进入 `strike_committed`；
  - 长机必须继续保持：
    - `camera_owner = drone`
    - `input_owner = drone`
    - `manual_flight_input_enabled = true`
- 僚机自杀冲锋必须实际飞向目标并产生真实爆炸结算；不得只做一段假动画。
- 僚机自杀冲锋完成后：
  - 该僚机视为已消耗；
  - 机群总数必须减少；
  - 长机不得播放 `NO SIGNAL` closeout。
- 当 `active wingman count == 0`，只剩长机时：
  - `MOUSE_BUTTON_LEFT`
  - 必须回退到当前既有长机自杀冲锋链；
  - 包含既有 `NO SIGNAL` closeout。
- 本轮不要求：
  - 玩家手动指定“哪一架”僚机去冲锋；
  - 僚机冲锋时独立切镜头；
  - 长机与僚机同时双重自杀冲锋。

**验收口径**：

- 自动化测试至少断言：有僚机时左键只会让 1 架僚机进入 strike，不会让长机进入 `strike_committed`。
- 自动化测试至少断言：僚机 strike 完成后，机群 active/desired 总数会按 `1` 正式扣减。
- 自动化测试至少断言：僚机 strike 期间，长机不会进入 `signal_loss` / `NO SIGNAL`。
- 自动化测试至少断言：当只剩长机时，左键仍会回退到当前 leader kamikaze + `NO SIGNAL` 旧链。

### REQ-0027-011 FPV 中键必须下达僚机面域阶梯式自杀冲锋命令，而不是让所有僚机同时砸向同一个点

**动机**：用户希望把“机群打击”做成更像一条命令链，而不是把所有僚机瞬间扔向同一个准星点。中键必须承担“面域、波次、间隔”的正式命令语义。

**范围**：

- 当 `leader active + FPV ADS active + idle wingman count >= 1` 时：
  - `MOUSE_BUTTON_MIDDLE`
  - 必须把当前准星目标点冻结为 area strike 中心；
  - 必须对该中心周围半径 `12m` 的区域生成僚机打击落点，而不是单点重合；
  - 必须按波次 dispatch，而不是同时全放；
  - 波次规模冻结为：
    - `1`
    - `2`
    - `3`
    - 然后按 `1 -> 2 -> 3` 循环，直到可用僚机耗尽；
  - 相邻两批次的最小 dispatch 间隔冻结为：
    - `0.6s`
- 同一批次内的僚机可以同时起飞，但不同批次之间必须可见分离，避免“一次全冲下去”。
- 中键面域命令只消费当前可用僚机：
  - 已在 strike / exploding / spent 的僚机不得被重复派遣；
  - 长机不得被中键 area strike 自动纳入冲锋名单。
- 中键 area strike 执行期间：
  - 长机继续保留 FPV / camera / input owner；
  - 不触发 `NO SIGNAL`。
- 本轮不要求：
  - 玩家手动画圈定义打击区域；
  - 可配置波次规模、可配置间隔；
  - 根据地形、障碍物或威胁等级做智能编队规划。

**验收口径**：

- 自动化测试至少断言：中键 area strike 会把多架僚机分配到不同落点，而不是全部锁到同一个点。
- 自动化测试至少断言：中键 area strike 的 dispatch 事件存在至少两批，且批次间隔不小于 `0.6s`。
- 自动化测试至少断言：批次规模遵循 `1 -> 2 -> 3` 的循环合同，最后一批允许因僚机数量不足而缩短。
- 自动化测试至少断言：中键 area strike 期间长机不会进入 `strike_committed`，也不会触发 `NO SIGNAL`。

## Acceptance Summary

- 小键盘 `5` 成为机群召唤控制唯一正式入口；主键盘 `5` 不触发。
- 短按 `KP_5` 逐架增援，长按 `KP_5` 全部回收，总数上限冻结为 `10` 架。
- 放飞 / 回收都拥有约 `2.0s` 的 formal sequence。
- 放飞结束后才切到无人机第三人称 chase camera。
- 回收结束后才恢复玩家完整控制权。
- 活跃无人机是第三人称自稳定飞行：`W/A/S/D` 平移、`E` 上升、`Q` 下降、松手 hover。
- 僚机首版只做可见分散编队，不做正式 flocking / 战术命令 / 独立 FPV。
- 机群收回不得破坏 howitzer 复合操炮上下文。
- 有僚机时，左键优先派 1 架僚机自杀冲锋；只剩长机时才回退 leader kamikaze + `NO SIGNAL`。
- 中键会下达面域阶梯式僚机冲锋：区域半径 `12m`、波次 `1 -> 2 -> 3` 循环、批次间隔 `0.6s`。
- drone runtime 正式脱离直升机 combat runtime。
