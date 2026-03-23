# V42 Drone Flight Foundation Design

## Context

这轮不是在仓库里再塞一个“会飞的 inspection camera”，而是要正式建立一条**玩家自有无人机**主链。当前工程已经具备三项非常值钱的现实基础。第一，`PlayerController` 已经有现成的水中 traversal 语义：`W/A/S/D` 的 camera-relative 平面移动、`Space` 的向上输入、以及 `move_toward` 风格的平滑速度收敛。这意味着无人机首版不必从零发明飞控输入语义，而应该复用“水中移动的输入口径 + 更稳定的 hover/stabilize 外层”。第二，`CityPrototype` 已经承担 debug hotkey 分发与独立 runtime wrapper 接线；小键盘 `+/-/*//` 等热键都走 `handle_debug_keypress()`，所以把无人机入口放在 `KEY_KP_5` 是现有架构允许的。第三，`drone_a.glb` 与 `CityDroneGunship.tscn` 已经提供了视觉与四旋翼 blur authoring 起点，但这条 scene 目前只是视觉资产落位，不应该继续挂靠直升机 combat semantics。

真正的难点在于**权力移交**：谁拥有输入、谁拥有相机、玩家什么时候冻结、什么时候恢复。如果这次只是把 camera 切到 drone，再让玩家实体继续自由移动，系统立刻会出现“玩家身体乱跑、准星仍在开火、无人机和玩家同时响应输入”的双主控问题；而如果把所有逻辑都塞进 `PlayerController`，又会把原本已经很重的玩家脚本继续膨胀。所以本轮设计必须把“玩家锁定 / 无人机接管 / transition 动画 / 第三人称飞控”拆成清晰层次：世界 wrapper 只负责编排，drone runtime 只负责状态机和飞控，player controller 只负责接受 formal lock/unlock contract。

## Alternatives Considered

### 方案 A：World-owned drone runtime + dedicated chase camera + player lock contract

推荐方案。由 `CityPrototype`（以及未来独立 lab）持有一个正式 `CityPlayerDroneRuntime`。它在 `stowed -> deploying -> active -> recovering` 四态间切换，拥有独立的 drone scene、独立 chase camera rig、独立 transition 播放和 debug state；玩家只是被 lock / unlock，而不是“变成无人机”。优点是权责清楚，main-world 与 lab 能共享同一 runtime，后续加 payload、照片、侦察 UI 也有固定插槽。缺点是要补正式的 camera ownership contract 与 wrapper glue。

### 方案 B：把玩家 transform 与 camera 直接绑到 drone 上

不推荐。做起来快，但玩家身体、武器、collision、HUD、输入与 drone flight 会全部混在一起，recover 时也很容易出现位置错乱。这个方案只适合一次性 demo，不适合正式主链。

### 方案 C：继续复用 helicopter runtime，只把 orbit/attack 拆空

明确不选。用户已经明确指出无人机与直升机没有关系；如果继续沿 `helicopter` runtime 退化复用，后续每加一个 drone feature 都会被炮艇历史包袱污染。

## Chosen Approach

本轮选择方案 A：**world-owned drone runtime + drone-only state machine + dedicated third-person chase camera + formal player lock contract**。同时冻结以下边界：

- 入口只认 `KEY_KP_5`
- deploy / recover 都是 formal sequence
- active 阶段是第三人称自稳定 hover flight
- 玩家完全失去位置与输入控制，直到 recover sequence 结束
- 不做 FPV、武器、电池、失控、避障

## Runtime Architecture

### 1. World Wrapper

推荐新增一个 world-owned wrapper，例如：

- `res://city_game/combat/drone/CityPlayerDroneRuntime.gd`

它由 `CityPrototype` 持有，未来也允许 `SpiderCrawlerLab` 或其他独立 lab 以同样方式持有。wrapper 负责：

- 监听 `KEY_KP_5`
- 判断当前是否允许 deploy
- 维护 `stowed / deploying / active / recovering`
- 在 deploy / recover 完成时切换 `camera_owner` 与 `input_owner`
- 对外暴露只读 `get_player_drone_debug_state()`

这一层**不负责**飞控细节，也不负责把所有输入直接塞进 `PlayerController`。

### 2. Transition Layer

deploy / recover 应该是单独的一层，而不是 active flight 的特例。推荐维护两个 authored anchor：

- `player_retrieval_anchor`
- `drone_hover_entry_anchor`

Deploy：

1. 在玩家身边 retrieval anchor 出现 drone
2. 播一段约 `2.0s` 的升空曲线
3. 结束时切到 chase camera，并进入 `active`

Recover：

1. 从 active flight 收束控制输入
2. 自动飞向 retrieval anchor
3. 降到归位高度
4. 结束时隐藏 / stow drone，并把控制权交回玩家

因为用户明确要求“动画结束后才切到无人机第三人称视角”，所以 deploy 期间不能先把相机硬切过去。推荐 deploy 期间仍让玩家相机保持主导，只做有限的过渡 bias；recover 期间则相反，保持 drone camera 直到最后一刻再切回玩家。

### 3. Flight Controller

active 阶段不做 FPV，也不做 acro。建议把飞控拆成：

- `desired_planar_velocity`
- `desired_vertical_velocity`
- `smoothed_velocity`
- `desired_yaw`
- `visual_pitch_roll`

输入语义直接复用现有玩家水中模式的优点：

- `W/A/S/D`：基于相机 yaw 的平面相对移动
- `E` 与 `Space`：上升
- `Q`：下降

但实现上比水中更稳定：

- 松手后自动 brake 到 hover
- yaw 有阻尼，不硬转
- 视觉 pitch / roll 只反映速度和指令，不参与真实 acro
- 不再使用玩家准星/ADS 作为控制中心

换句话说，这是一套“第三人称摄影无人机”手感，而不是“挂着四个桨的飞行玩家”。

### 4. Camera and Input Ownership

这轮最关键的 contract 不是“能不能飞”，而是 ownership 明不明确。推荐冻结两条布尔真相：

- 当前谁拥有输入：`player` / `drone`
- 当前谁拥有相机：`player` / `drone`

在任何时刻都不允许出现“player 与 drone 同时吃移动输入”。

具体冻结如下：

- `stowed`：input owner = `player`，camera owner = `player`
- `deploying`：input owner = `none`，camera owner = `player`
- `active`：input owner = `drone`，camera owner = `drone`
- `recovering`：input owner = `none`，camera owner = `drone`

这能直接防止最常见的两类 bug：

1. deploy 期间玩家还能乱走、开枪、切 ADS
2. recover 期间玩家已经恢复控制，但 camera 还挂在 drone 上

### 5. Testing Strategy

至少规划六类 focused tests：

1. `toggle contract`
   - 只认 `KEY_KP_5`
   - `KEY_5` 不触发
2. `deploy / recover state machine`
   - transition 期间重复按键被忽略
3. `camera takeover contract`
   - deploy 完成后才切 drone camera
   - recover 完成后才切回 player camera
4. `player lock contract`
   - deploying / active / recovering 三段都不会泄漏玩家移动 / 武器输入
5. `flight input contract`
   - `W/A/S/D`、`E/Space`、`Q` 映射正确，且 hover/brake 成立
6. `portability contract`
   - main-world 与 future lab 用同一 runtime，不允许旁路复制

## Recommendation

`v42` 不要把范围扩成“完整无人机系统”。先守住四件事：

- `KEY_KP_5` toggle
- deploy / recover sequence
- third-person chase camera takeover
- self-stabilized hover flight

只要这四件事以 drone-only runtime 正式落成，后续无论加侦察 UI、照片、挂载 payload，还是把无人机接进蜘蛛 lab，都会有一条干净主链可继续扩展。
