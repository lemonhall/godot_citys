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

## Non-Goals

- 不在本轮接入主世界 registry / landmark / task / full map。
- 不在本轮实现开火、弹道、装填、炮口焰、后坐、炮弹爆炸。
- 不在本轮实现乘员、动画、AI、任务、对话或交互 UI。
- 不在本轮实现真实火控解算、射表、射界限制或联网同步。

## User Experience

1. 开发者可以直接打开正式 `CityM777Howitzer.tscn`，看到完整包装好的火炮 scene。
2. 开发者可以在该 scene 中手工微调：
   - `YawPivotAnchor`
   - `PitchPivotAnchor`
3. 打开 `M777HowitzerLab.tscn` 后，可以以正式 `PlayerController` 进入独立地面环境，看见胶囊玩家、火炮实例和可用相机视角。
4. lab 中可以直接驱动 yaw / pitch 调试，不依赖主世界逻辑。
5. 调试完成后，该 howitzer scene 可以作为后续主世界接入与功能扩展的正式基础。

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

### REQ-0029-005 Lab Scene Contract

必须提供独立 lab 场景 `res://city_game/scenes/labs/M777HowitzerLab.tscn`，它要挂载正式火炮 scene，而不是直接挂 `glb`。该 lab 必须具备基础地面、光照、正式 `PlayerController` 玩家、当前可用的玩家相机，以及最小调试 UI / 状态输出，用于后续继续调控制面与音效。

### REQ-0029-006 Lab Control Contract

lab 必须允许直接驱动火炮 yaw / pitch，并暴露最小查询/重置接口，确保未来调试不依赖主世界。具体输入映射可以简化，但必须有稳定可复用的脚本 API，而不是只能靠编辑器手动拧 Inspector。

## Acceptance

1. 自动化测试必须证明：`CityM777Howitzer.tscn` 与对应脚本存在，并且场景文本直接引用正式 `m777_3_parts.glb`。
2. 自动化测试必须证明：火炮 scene runtime 层级里存在 `ModelRoot/YawPivot/PitchPivot` 以及两枚正式锚点 `Anchors/YawPivotAnchor`、`Anchors/PitchPivotAnchor`。
3. 自动化测试必须证明：`m777_lower_base`、`m777_upper_carriage`、`m777_gun_assembly` 在 runtime 中分别处于固定层、yaw 层、pitch 层，而不是重新塌回单层根节点。
4. 自动化测试必须证明：火炮 scene root 暴露 `REQ-0029-004` 约定的最小 API。
5. 自动化测试必须证明：调用 yaw / pitch API 会分别改变 `YawPivot` 与 `PitchPivot` 的角度，不会把两级旋转混成单轴。
6. 自动化测试必须证明：`M777HowitzerLab.tscn` 存在，并且挂载正式火炮 scene，而不是直接实例化 `glb`。
7. 自动化测试必须证明：lab scene 暴露最小 howitzer 获取 / 状态读取 / 重置接口，并能驱动 yaw / pitch 调试链。
8. 自动化测试必须证明：lab scene 启动时存在正式 `PlayerController` 玩家节点与当前玩家相机，而不是只剩一个静态观察相机。
9. 自动化测试必须证明：正式 howitzer scene 的最终可见包围尺寸已经脱离 `1m` 级缩水资产，达到正式武器平台的最低 world-scale 量级。
