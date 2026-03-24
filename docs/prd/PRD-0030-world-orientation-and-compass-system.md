# PRD-0030 World Orientation And Compass System

## Summary

为主世界与火炮 lab 建立统一、显式、可复用的东南西北与方位角体系，并把它正式接入 HUD、minimap 与 full map。该版本的目标不是只在某个 UI 上临时画一个 `N`，而是冻结一条未来可支撑火炮方位角操炮、地图判读、任务沟通与作者场景调试的 shared orientation contract：地图北 = 地理北 = 世界北；玩家 HUD 必须持续显示带角度刻度的军用风格指南针条。

## Problem

当前仓库里的 minimap、full map 和玩家朝向虽然已经隐含使用了一套 `x/z` 投影，但没有正式的“世界北”命名、没有统一的 bearing 口径，也没有 HUD compass。结果是：

- 玩家无法快速判断当前朝向是否对着北边、东边或某个具体方位角；
- 火炮 yaw 目前只能凭肉眼调，缺少“朝向 045° / 270°”这类可交流、可复现的口径；
- full map / minimap 的 north-up 只是数学上的隐含结果，没有正式 contract，也没有 focused test 守护；
- 主世界和 lab 对方向概念没有共享接口，后续操炮与调试会继续分叉。

## Goals

- 冻结全项目共享的世界方向 contract：`北 = -Z`，`东 = +X`。
- 冻结全项目共享的 bearing 口径：`北 = 0°`，顺时针增加，`东 = 90°`，`南 = 180°`，`西 = 270°`。
- 让 main world HUD 显示正式的军用风格 compass strip，带刻度和 `N/E/S/W`。
- 让 full map 与 minimap 显式暴露 `north-up` / `map north = geographic north` contract。
- 让 `M777HowitzerLab` 复用同一套 orientation/compass 语义，而不是再造 lab-only 方向逻辑。

## Non-Goals

- 不在本轮实现真实炮兵火控解算、装定、射表或落点解算。
- 不在本轮实现磁偏角、坐标网格编号、UTM/MGRS 等真实军事坐标系统。
- 不在本轮实现炮身方位角和玩家观察方位角的双 HUD 并显。
- 不在本轮改写道路生成、车辆 heading 或其它与视觉模型摆正相关的局部 yaw 公式，除非它们直接影响 compass / north-up contract。

## User Experience

1. 玩家进入主世界后，抬头即可在 HUD 顶部看到连续的 compass strip。
2. compass strip 会显示当前视线/朝向的 bearing，例如 `000° N`、`090° E`。
3. 玩家打开 minimap 或 full map 时，不需要猜旋转规则；地图恒为上北下南左西右东。
4. 玩家进入 `M777HowitzerLab` 时，也能看到相同口径的 compass HUD，便于操炮前先判断朝向。
5. 后续当火炮接入真实方位角控制时，可以直接复用该 contract，而不是再次定义“炮口 0° 到底朝哪边”。

## Requirements

### REQ-0030-001 Shared World Orientation Contract

必须提供一份正式、共享、可复用的世界方向 contract，并在代码中集中定义，而不是让 HUD、minimap、full map、lab 各自硬编码。该 contract 至少冻结：

- 世界北 = `Vector3(0, 0, -1)`
- 世界东 = `Vector3(1, 0, 0)`
- bearing `0°` 指向北
- bearing 正方向为顺时针
- `90° = 东`、`180° = 南`、`270° = 西`

### REQ-0030-002 North-Up Map Contract

full map 与 minimap 必须显式共享“地图北 = 地理北 = 世界北”的 north-up contract。不得让某一张地图偷偷按玩家朝向旋转，也不得让 map north 与世界北脱钩。相关 snapshot / render state 必须能被 focused tests 读取并验证。

### REQ-0030-003 Main-World Compass HUD

主世界 `PrototypeHud` 必须新增正式 compass HUD。该 HUD 必须：

- 在正常游戏中持续可见；
- 显示当前玩家/当前世界操控焦点的 bearing；
- 具有可读的刻度线与度数标签；
- 明确显示 `N/E/S/W` cardinal cue；
- 与 `REQ-0030-001` 的 bearing 口径完全一致。

### REQ-0030-004 Shared Orientation API

主世界 runtime 必须暴露最小可复用 orientation API，至少允许其它系统读取：

- 世界方向 contract
- 当前玩家/当前聚焦控制体的 compass state
- 当前 minimap / full map 的 north-up contract

后续火炮、任务、lab 或其它 authored feature 必须可以复用该 API，而不是再自己算一套 bearing。

### REQ-0030-005 Lab Compass Parity

`M777HowitzerLab` 必须接入同一套 orientation contract，并显示 compass HUD。lab 必须能读取当前玩家朝向对应的 bearing，且 reset 后仍保持与主世界一致的口径；不允许出现 main world 一套、lab 一套的 north/bearing 语义分叉。

## Acceptance

1. 自动化测试必须证明：共享 orientation helper / API 存在，并冻结 `北=-Z`、`东=+X`、`北=0°顺时针增加`。
2. 自动化测试必须证明：minimap 的 world projection 结果满足 north-up 几何关系，向北的世界点映射到地图上方，向东的世界点映射到地图右侧。
3. 自动化测试必须证明：full map 的 world projection 与 render state 共享相同 north-up contract，而不是单独一套 UI 旋转语义。
4. 自动化测试必须证明：`PrototypeHud` 已挂接正式 compass HUD，并能给出当前 bearing / cardinal state。
5. 自动化测试必须证明：玩家转向东侧后，主世界 HUD compass 读数进入 `90°` 口径，而不是继续沿用模型 yaw 或逆时针角度。
6. 自动化测试必须证明：`build_minimap_snapshot()` 与 full map render state 都显式暴露 `north_up` / `map north = geographic north` contract。
7. 自动化测试必须证明：`M777HowitzerLab` 暴露 orientation / compass state，并在玩家转向后维持和主世界一致的 bearing 读数。

