# PRD-0029 Artillery Howitzer Scene Foundation

## Summary

在现有 `m777_3_parts.glb` 三段式火炮资产基础上，建立一套正式、可复用、可继续扩展的火炮包装场景与调试 lab。该交付的核心不是“把模型摆进一个预览器”，而是冻结一条未来可接入主世界、音效、控制面、射击逻辑与世界 feature 的正式 scene contract：`lower_base` 固定、`upper_carriage` 负责水平回转、`gun_assembly` 负责俯仰；同时把两个关键轴心位置显式 author 成手工可调的锚点。

## Problem

当前仓库只有拆分后的原始 `glb` 资产，没有正式火炮 scene wrapper、没有可复用节点层级、没有锚点 contract，也没有独立 lab 可用来调试俯仰/旋转、控制面与后续音效。直接把 `glb` 塞进主世界会导致：

- yaw / pitch 轴心没有正式口径，只能靠代码硬编码猜位置；
- 后续音效、开火点、乘员位、交互点、任务挂点都没有稳定 scene contract；
- 没有独立 lab，后续调试会把“火炮本体问题”和“主世界接入问题”混在一起。

## Goals

- 建立正式的 `CityM777Howitzer.tscn` 火炮包装场景。
- 把 `m777_3_parts.glb` 收口进稳定的三层 runtime 层级：`lower_base -> yaw -> pitch`。
- 把底盘回转轴与炮身俯仰耳轴做成手工可调 `Marker3D` 锚点。
- 暴露后续可复用的最小 runtime API：设置/读取 yaw、pitch、anchors、debug state。
- 建立独立 `lab` 场景，允许在不接主世界的情况下调试火炮 scene。
- [已由 ECN-0030 变更] 在 `lab` 中建立上下文化操炮交互：靠近火炮约 `5m` 时出现 `按 E 操作炮` 提示，进入操炮态后 HUD 必须持续显示 `J/L`、`I/K` 与 `E` 的控制提示，且只有离炮约 `20m` 后才自动脱离操炮态。
- [已由 ECN-0031 变更] 在正式 `CityM777Howitzer` runtime 中加入可复用的开火演出 contract：`6s` 冷却、炮口火光、烟尘、拉火绳张紧、轻微后坐与正式 weapon fire audio，但不生成炮弹实体。

## Non-Goals

- 不在本轮接入主世界 registry / landmark / task / full map。
- [已由 ECN-0031 变更] 不在本轮实现炮弹实体、弹道、落点、爆炸、杀伤判定或火控解算；本轮新增范围仅限正式 howitzer runtime 的开火演出与 lab 内的触发交互。
- [已由 ECN-0030 变更] 不在本轮实现主世界火炮交互 UI、乘员、动画、AI、任务或对话；本轮新增的交互范围仅限 `M777HowitzerLab` 内的近距进入/退出操炮态。
- 不在本轮实现真实火控解算、射表、射界限制或联网同步。

## User Experience

1. 开发者可以直接打开正式 `CityM777Howitzer.tscn`，看到完整包装好的火炮 scene。
2. 开发者可以在该 scene 中手工微调：
   - `YawPivotAnchor`
   - `PitchPivotAnchor`
3. 打开 `M777HowitzerLab.tscn` 后，可以以正式 `PlayerController` 进入独立地面环境，看见胶囊玩家、火炮实例和可用相机视角。
4. lab 中可以直接驱动 yaw / pitch 调试，不依赖主世界逻辑。
5. 调试完成后，该 howitzer scene 可以作为后续主世界接入与功能扩展的正式基础。
6. [已由 ECN-0030 变更] 玩家在 `lab` 中接近火炮约 `5m` 时，会看到共享 HUD prompt：`按 E 操作炮`。
7. [已由 ECN-0030 变更] 玩家按下 `E` 后进入操炮态，HUD 必须持续显示 `J/L` 调整方位、`I/K` 调整高低、`E` 退出的控制提示；仅当玩家再次按下 `E`，或离炮约 `20m` 后，操炮态才会结束。
8. [已由 ECN-0031 变更] 玩家进入操炮态后，可在 `20m` 保活范围内按下 `Space` 触发 howitzer 的正式开火演出，而不是 lab-only 假按钮。
9. [已由 ECN-0031 变更] 每次 accepted fire 都必须给出明显的火光、烟尘、拉火绳绷紧、轻微后坐与 weapon fire audio 反馈，并进入 `6s` 装填冷却。
10. [已由 ECN-0031 变更] 冷却期间 HUD 必须明确显示 `装填中 X.Xs...`；冷却结束后必须明确显示 `可击发`，而不是让玩家靠猜。

## Requirements

### REQ-0029-001 Formal Scene Wrapper

必须提供正式火炮包装场景 `res://city_game/combat/artillery/CityM777Howitzer.tscn`，并由专用脚本驱动。该 scene 必须包装 `res://city_game/assets/environment/source/artillery/m777/m777_3_parts.glb`，不能退回 root 级散装资产或脚本临时拼装；同时必须把 AI 生成的缩水 source asset 归一化到可进入主世界的真实武器平台量级，不能保持“玩具炮”尺寸。

### REQ-0029-002 Three-Part Runtime Hierarchy

正式 scene 必须把三段模型收口进稳定层级：

- `m777_lower_base`
- `m777_upper_carriage`
- `m777_gun_assembly`

其中：

- `lower_base` 固定在底盘层；
- `upper_carriage` 围绕 yaw 轴旋转；
- `gun_assembly` 围绕 pitch 轴旋转。

### REQ-0029-003 Manual Anchor Contract

正式 scene 必须 author 两个手工可调 `Marker3D` 锚点：

- `Anchors/YawPivotAnchor`
- `Anchors/PitchPivotAnchor`

runtime 必须读取这两个锚点来定位真正的 `YawPivot` 与 `PitchPivot` 节点，而不是把轴心硬编码在脚本常量里。

### REQ-0029-004 Runtime API Contract

火炮 scene root 必须至少暴露以下接口，供 lab / future world integration / focused tests 复用：

- `get_visual_root()`
- `set_yaw_degrees(value: float)`
- `set_pitch_degrees(value: float)`
- `set_axis_angles_degrees(yaw_deg: float, pitch_deg: float)`
- `get_yaw_degrees()`
- `get_pitch_degrees()`
- `get_anchor_state()`
- `get_debug_state()`

其中 `pitch` 的对外语义冻结为“校准后的真实仰角”：

- 炮口视觉放平时为 `0°`
- 正值表示抬高炮口，负向不对外暴露
- 当前模型允许保留一个内部零位校准偏置量
- 对外 `pitch` 必须被限制在 `0-71°`
- 对外 `yaw` 必须归一到 `0-360°` 圆周内；跨过整圈后回卷，不继续暴露累计转圈数
- `get_pitch_degrees()`、`set_pitch_degrees()`、`set_axis_angles_degrees()` 与 lab HUD 都必须共享同一口径，而不是一边显示模型内部角、一边显示真实仰角

### REQ-0029-005 Lab Scene Contract

必须提供独立 lab 场景 `res://city_game/scenes/labs/M777HowitzerLab.tscn`，它要挂载正式火炮 scene，而不是直接挂 `glb`。该 lab 必须具备基础地面、光照、正式 `PlayerController` 玩家、当前可用的玩家相机，以及最小调试 UI / 状态输出，用于后续继续调控制面与音效。

### REQ-0029-006 Lab Control Contract

lab 必须允许直接驱动火炮 yaw / pitch，并暴露最小查询/重置接口，确保未来调试不依赖主世界。具体输入映射可以简化，但必须有稳定可复用的脚本 API，而不是只能靠编辑器手动拧 Inspector。

### REQ-0029-007 Lab Operation Interaction Contract

[由 ECN-0030 新增] `M777HowitzerLab` 必须把键盘操炮从“全局热键”收口为“近距上下文交互”：

- 玩家只有在接近火炮约 `5m` 时，HUD 才能出现 `按 E 操作炮` 提示；
- 按下 `E` 后进入操炮态，再次按下 `E` 可手动退出；
- 进入操炮态后，HUD 必须持续显示 `按 E 退出操炮  J/L 方位  I/K 高低  R 复位`；
- 只有在操炮态激活时，`J/L` 才能控制火炮 yaw，`I/K` 才能控制 pitch；
- 进入操炮态后，玩家离开 `5m` 进入半径但仍处于约 `20m` 的保活半径内时，操炮态必须继续保持；
- 只有手动退出，或离炮约 `20m` 之后，操炮态与 `J/L/I/K` 所有权才会被释放；
- `lab` 的 prompt 必须复用主世界既有的 HUD prompt contract，而不是再造第三套提示协议。

### REQ-0029-008 Formal Fire Presentation Contract

[由 ECN-0031 新增] 正式 `CityM777Howitzer` runtime 必须内建一条可复用、可测试、非 lab 私货的开火演出 contract：

- scene 必须正式 author 至少两枚开火演出锚点：
  - `Anchors/MuzzleFxAnchor`
  - `Anchors/LanyardAnchor`
- runtime root 必须至少暴露以下 fire API：
  - `can_fire()`
  - `request_fire()`
  - `get_fire_state()`
- accepted fire 的冻结语义：
  - 默认冷却为 `6.0s`
  - 触发炮口火光
  - 触发短寿命炮口烟尘
  - 触发拉火绳从“略松”到“瞬间绷紧”的演出
  - 触发轻微炮身后坐
  - 触发正式 weapon fire audio
- rejected fire 的冻结语义：
  - 冷却期间再次请求必须被拒绝，并暴露明确 cooldown state
- 反作弊条款：
  - 不允许通过 runtime 临时生成 projectile / grenade / missile 节点来伪装“开火已实现”
  - 不允许把上述演出只写在 `M777HowitzerLab` 脚本里，正式 howitzer scene runtime 必须是唯一真源
  - `get_fire_state()` / `get_debug_state()` 必须显式暴露冷却、火光、烟尘、拉绳、后坐与 weapon fire audio 的 runtime 状态，便于 focused tests 回归

## Acceptance

1. 自动化测试必须证明：`CityM777Howitzer.tscn` 与对应脚本存在，并且场景文本直接引用正式 `m777_3_parts.glb`。
2. 自动化测试必须证明：火炮 scene runtime 层级里存在 `ModelRoot/YawPivot/PitchPivot` 以及两枚正式锚点 `Anchors/YawPivotAnchor`、`Anchors/PitchPivotAnchor`。
3. 自动化测试必须证明：`m777_lower_base`、`m777_upper_carriage`、`m777_gun_assembly` 在 runtime 中分别处于固定层、yaw 层、pitch 层，而不是重新塌回单层根节点。
4. 自动化测试必须证明：火炮 scene root 暴露 `REQ-0029-004` 约定的最小 API。
5. 自动化测试必须证明：调用 yaw / pitch API 会分别改变 `YawPivot` 与 `PitchPivot` 的角度，不会把两级旋转混成单轴。
6. 自动化测试必须证明：`yaw` API 对外暴露的是归一化圆周角，而不是超过 `360°` 的累计转圈数；整圈必须回到 `0°`。
7. 自动化测试必须证明：`pitch` API 对外暴露的是校准后的真实仰角；炮口放平时 `pitch=0°`，正值表示抬高炮口，而不是继续暴露模型内部偏置角或把方向写反。
8. 自动化测试必须证明：`pitch` 被限制在 `0-71°` 射界之内，不能继续无限上抬或下压。
9. 自动化测试必须证明：`M777HowitzerLab.tscn` 存在，并且挂载正式火炮 scene，而不是直接实例化 `glb`。
10. 自动化测试必须证明：lab scene 暴露最小 howitzer 获取 / 状态读取 / 重置接口，并能驱动 yaw / pitch 调试链。
11. 自动化测试必须证明：lab scene 启动时存在正式 `PlayerController` 玩家节点与当前玩家相机，而不是只剩一个静态观察相机。
12. 自动化测试必须证明：正式 howitzer scene 的最终可见包围尺寸已经脱离 `1m` 级缩水资产，达到正式武器平台的最低 world-scale 量级。
13. [由 ECN-0030 新增] 自动化测试必须证明：只有当玩家进入火炮 `5m` 交互半径时，HUD 才出现 `按 E 操作炮` 提示；进入操炮态后 HUD 会持续显示 `J/L`、`I/K` 与 `E` 的控制提示；`J/L/I/K` 仅在操炮态内生效；离开 `5m` 但未超过约 `20m` 时仍保持操炮态；只有再次按 `E` 或离炮约 `20m` 后才释放操炮态。
14. [由 ECN-0031 新增] 自动化测试必须证明：正式 howitzer scene author 了 `MuzzleFxAnchor` 与 `LanyardAnchor`，并且 root 暴露 `can_fire()`、`request_fire()` 与 `get_fire_state()`。
15. [由 ECN-0031 新增] 自动化测试必须证明：accepted fire 会触发正式 runtime 的火光、烟尘、拉火绳张紧、后坐与 weapon fire audio，同时进入默认 `6.0s` 冷却；冷却期间重复 fire 请求会被拒绝。
16. [由 ECN-0031 新增] 自动化测试必须证明：lab 中只有进入操炮态后，`Space` 才能触发正式 howitzer fire API；HUD 会显示 `Space` 提示、冷却中的 `装填中 X.Xs...` 与冷却完成后的 `可击发`。
17. [由 ECN-0031 新增] 自动化测试必须证明：本轮 fire presentation 不会生成任何 projectile / grenade / missile 运行时节点，不把“演出反馈”偷换成“弹道链已实现”。
