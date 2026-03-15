# 2026-03-15 V14 Task System Design

## Context

当前仓库已经有：

- `v12` 交付的 `full map + minimap + route_result + destination pin`
- `CityMapPinRegistry.gd` 可承载多类 pin
- `CityDestinationWorldMarker.gd` 的火焰圈模型与动画
- `CityPrototype.gd` 里的 full-map open / select / route / autodrive / fast-travel 主链

但还没有：

- 正式 `task definition / task slot / task runtime`
- 正式任务状态机
- 地图侧 `Tasks / Brief` 页面
- 世界里的任务 start/objective ring runtime
- “玩家或车辆进入触发圈就开始任务”的正式 contract

## Option A：继续把任务当 debug pin 做薄层扩展

做法：

- 继续使用 `register_task_pin()`
- 在 `CityMapScreen` 侧手工拼一个任务列表
- 世界里再单独做一个 `TaskMarker` node

优点：

- 初期改动最少
- 很快能做出“地图上有几个点”

缺点：

- 没有正式 `task_id -> state -> pin -> trigger` 链
- 地图、world marker、任务页签会各有一套临时状态
- 任务从 `available -> active -> completed` 没法被稳定追踪
- 后续加 objective、奖励或失败条件时必然返工

结论：

- 不推荐。这条路本质上是把 `v14` 做成 `v12` debug pin 的 UI 外挂。

## Option B：`Task Catalog + Task Runtime + Shared Presenters`

做法：

- 定义正式 `task definition / task slot / task state`
- 用 `task runtime` 维护 `available / active / completed`
- 由 runtime 统一投影出 `pin view model`、`brief view model`、`world ring view model`
- full map、minimap、world ring、route target 都消费同一份任务状态

优点：

- 与 `v12` 的 `resolved_target + route_result + pin_registry` 主链一致
- 能把地图页签、任务状态、世界触发整成一条可测 contract
- 后续扩展多阶段 objective、奖励、失败条件更自然
- 可以把世界 marker 约束在已有火焰圈模型族里，不会再造第二套视觉系统

缺点：

- 前期设计量与测试量更大
- 必须先把任务 slot 和状态机写硬

结论：

- 推荐方案。这是唯一同时满足用户体验、可扩展性和现有仓库架构纪律的路线。

## Option C：直接做重型 mission graph / quest framework

做法：

- 一上来引入多阶段任务图、条件树、奖励树、失败分支、脚本事件系统

优点：

- 理论上能力最强

缺点：

- 明显超出当前需求
- 会把“地图联动 + 触发开始 + 任务页签”这个首要目标冲散
- 文档和实现都很容易失控

结论：

- 当前不取。`v14` 先把任务主链骨架做硬，复杂叙事与事件系统留给后续版本。

## Recommended Design

### 1. 任务数据层：先冻结 `task slot`

`v14` 的 authoring 单元不是 cutscene，也不是行为树，而是 `task slot`。每个任务至少有：

- `task_id`
- `title`
- `summary`
- `status`
- `icon_id`
- `start_slot`
- `objective_slots`
- `auto_track_on_start`

`slot` 至少有：

- `slot_id`
- `slot_kind`：`start` / `objective`
- `world_anchor`
- `trigger_radius_m`
- `marker_theme`
- `route_target_override`

首版任务模型冻结为：

- `available`：可接，地图可见，附近可显示绿色世界圈
- `active`：已接，任务页签顶置，objective 变蓝色 pin / 蓝色圈
- `completed`：不再默认显示世界圈；地图是否显示由过滤策略决定

### 2. 展示层：地图始终可见，任务页签贴边

不推荐把 `CityMapScreen` 改成完全切页。更合理的是：

- 左侧保留 full map 画布
- 右侧新增 `Tasks` 页签/侧栏
- 侧栏承载：
  - 当前追踪任务
  - `进行中`
  - `待开始`
  - `已完成`（默认可折叠）
  - 当前 objective 文案

这相当于用“地图始终可见 + 任务侧栏”去吸收 GTA5 的 `Map + Brief + Objective` 语义，但比 literal 复刻 Pause Menu 更适合当前 UI。

### 3. 图标策略：contract 用 `icon_id`，UI 才决定是不是 emoji

用户明确接受 emoji 风格，但底层 contract 不应直接写死 emoji 字符。推荐冻结：

- 数据层：`status`, `icon_id`, `color_theme`
- UI 层：决定渲染成 emoji、字体 glyph 还是 atlas sprite

建议首轮主题：

- `available`：绿色
- `active`：蓝色
- `completed`：白/灰
- `destination`：沿用当前橙色导航主题

### 4. 世界 marker：共享火焰圈模型族，不再新造

`CityDestinationWorldMarker.gd` 已经给出了成熟的火焰圈视觉。`v14` 不应再做另一套 `TaskMarker` 模型，而应把它抽成可配置 theme 的 shared ring marker：

- `destination`: 橙色
- `task_available_start`: 绿色
- `task_active_objective`: 蓝色

同时要加一条 runtime 纪律：

- 世界里只渲染 `tracked active objective` 与 `nearby available starts`
- 不允许全城任务圈常亮

### 5. 触发与导航：任务是 route consumer，不是 route solver

进入 `start slot` 时：

1. `available -> active`
2. 任务页签刷新
3. active objective 设为当前 tracked destination
4. 地图/minimap/world ring 一起切到 active 语义

进入 `objective slot` 时：

1. `active -> completed`
2. 如果该任务没有后续 objective，则清理 active task route
3. map/world marker 退出 active 展示

这意味着任务系统消费 `resolved_target + route_result`，但不允许再造第二套路线求解。

## Error Handling

- 多个 start slot 重叠时，必须由 `priority + distance + explicit enabled` 决定唯一命中项，不能同帧连开多个任务。
- 当前已有 active task 时，再进入另一个 available start slot，默认不自动切换任务；应提示或忽略，避免状态乱跳。
- 无 route target 的纯叙事任务允许没有导航线，但仍必须有正式 `task state` 和 `brief` 项。
- 车辆触发时必须以“当前玩家正在驾驶的车辆”作为合法载体，ambient traffic 经过不可误触发。

## Testing Direction

- `task catalog` seed stability
- `task runtime` state machine
- `task slot` spatial query
- map tab render contract
- task pin projection and legend
- task selection -> route target sync
- shared ring marker theme contract
- on-foot trigger start
- in-vehicle trigger start
- active objective completion flow
- performance redline trio
