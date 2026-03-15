# PRD-0007 Task And Mission System

## Vision

把 `godot_citys` 从“已经有 full map、destination pin、debug task pin 和 destination world marker”推进到“拥有正式任务定义、任务状态机、地图任务页签、任务 pin、世界任务触发圈和任务开始/追踪主链”的状态。成功标准不是地图上再多几个 debug 点，而是建立一条稳定、可测试、可复用的任务语义链：

`task catalog + task slot index -> task runtime -> task pin / task brief / world ring -> full map / minimap / route target / start trigger`

本 PRD 的目标用户仍然是项目开发者本人及后续协作 agent。核心价值是把“城市里的任务可以被看见、被追踪、被开始，并且和地图/导航/世界标记共用一套语义 contract”正式化，同时继续守住 deterministic 与 `60 FPS = 16.67ms/frame` 的硬红线。

## Background

- `PRD-0006` 与 `v12` 已经交付 `Place Index`、`resolved_target`、`route_result`、`M` 全屏地图、shared pin registry、destination world marker、fast-travel、auto-drive。
- 当前 `CityPrototype.gd` 已经暴露 `register_task_pin()`，但这只是 pin 注册入口，不是正式任务系统。
- 当前 `CityMapScreen.gd` 具备 full map 渲染、route overlay、pin overlay 与 player marker，但没有任务页签或任务状态 view model。
- 当前 `CityDestinationWorldMarker.gd` 已有成熟的火焰圈模型与动画，但颜色和语义仍固定在 destination。
- 当前测试已锁死 `full map pause contract`、`map pin overlay`、`pin priority` 与 `destination world marker contract`，说明 `v14` 必须复用现有主链，而不是另做任务专用第二套地图/marker/runtime。
- `v13` 已把整城 morphology 拉回多中心城市骨架，适合开始补更强可见性的系统增量；任务系统正属于这一类高可见度功能。

## Scope

本 PRD 覆盖 `v14 task system` 大版本。

包含：

- 正式 `task catalog / task definition / task slot` 数据模型
- 正式任务 runtime 与状态机
- `M` 全屏地图侧的 `Tasks` 页签 / Brief 面板
- full map 上的 `available / active / completed` 任务可视状态
- world 里的 shared flame-ring task marker（绿色/蓝色）
- 玩家步行或驾驶车辆进入 trigger circle 即开始任务
- 任务开始后与 destination / route target 同源联动
- 首版 sample tasks 的端到端自动化验证

不包含：

- 不做复杂剧情分支、对话树、导演系统
- 不做奖励经济、商店、金钱或任务结算 UI
- 不做正式存档/跨 session 持久化
- 不做 police / faction / economy 的完整任务生态
- 不做在线协同或多人同步任务

## Non-Goals

- 不追求 `v14` 一次性做成重型 RPG quest journal
- 不追求全城所有任务世界圈长期常亮
- 不追求为了“像 GTA”而照搬其字面菜单结构
- 不追求通过 hardcode 几个测试 pin 或任务名来“假装完成”

## Requirements

### REQ-0007-001 系统必须生成正式 `task catalog` 与 `task slot index`

**动机**：如果任务只存在于 UI 或某个 scene 临时节点里，地图、世界触发、目标追踪和测试都不会有稳定上游。

**范围**：

- world bootstrap 阶段生成正式 `task_catalog`
- 每个任务至少有 `task_id`、`title`、`summary`、`icon_id`、`initial_status`
- 每个任务至少支持 `start slot`，并允许至少一个 `objective slot`
- slot 至少有 `slot_id`、`slot_kind`、`world_anchor`、`trigger_radius_m`、`marker_theme`
- task slot 必须可按 world/chunk 查询，而不是每帧扫全量数组

**非目标**：

- 不做外部数据库或远程任务服务
- 不做 editor-only scene node 才能工作的临时 authoring

**验收口径**：

- 自动化测试至少断言：`world_data` 或等价 runtime 暴露正式 `task_catalog` / `task_query`，而不是只有 UI 临时列表。
- 自动化测试至少断言：相同 seed 下 `task_id`、`slot_id`、`world_anchor` 可重复生成。
- 自动化测试至少断言：`start slot` 与 `objective slot` 可按 active chunk 或 world rect 查询。
- 反作弊条款：不得通过把任务写死在 `PrototypeHud`、只做测试专用列表、或每帧扫描所有任务来宣称完成。

### REQ-0007-002 系统必须维护正式任务状态机

**动机**：没有正式状态机，就无法稳定区分待开始、进行中和已完成任务。

**范围**：

- `v14` 最小状态集冻结为：`available`、`active`、`completed`
- 允许为未来预留 `locked`、`failed`，但不是 `v14` closeout 前置
- runtime 必须能按状态返回任务集合
- active task 必须可被唯一确定

**非目标**：

- 不要求 `v14` 首版支持多 active task 并行
- 不要求 `v14` 首版实现失败分支

**验收口径**：

- 自动化测试至少断言：任务可从 `available -> active -> completed` 按 contract 转移。
- 自动化测试至少断言：active task 切换与 current objective 唯一性稳定。
- 自动化测试至少断言：任务状态变化会驱动 map pin / brief view model 更新。
- 反作弊条款：不得通过只改 UI 文案、不改 runtime 状态，或用多个布尔开关拼状态来宣称完成。

### REQ-0007-003 full map 必须展示正式任务状态，而不是只有 debug pin

**动机**：用户明确要求大地图能显示待完成、进行中的任务。

**范围**：

- `M` 全屏地图展示至少 `available` 与 `active` 两类任务
- 任务 pin 至少携带 `task_id`、`status`、`icon_id`、`title`
- full map 必须能区分 `available` 与 `active`
- `completed` 默认可进页签或过滤器，不要求默认铺满地图

**非目标**：

- 不要求 `v14` 首版做完整筛选矩阵
- 不要求 `v14` 首版支持上百种 icon 分类

**验收口径**：

- 自动化测试至少断言：full map render state 能区分 `available` 与 `active` 任务。
- 自动化测试至少断言：任务 pin 来源于正式 runtime，而不是手工 debug 注入。
- 自动化测试至少断言：任务 pin 与 destination pin 共享同一 pin registry / overlay 主链。
- 反作弊条款：不得通过把任务画成静态背景、截图贴图或另一套 task-only map state 来宣称完成。

### REQ-0007-004 `M` 地图旁必须提供正式 `Tasks` 页签 / Brief 面板

**动机**：用户明确要求地图旁边加任务页签，并参考 GTA5 的任务/Brief 入口。

**范围**：

- full map 打开后，地图旁可见 `Tasks` 页签或等价侧栏
- 页签至少显示：
  - 当前 active task
  - `进行中`
  - `待开始`
  - 当前 objective 文案
- 任务条目可被选中，并驱动当前追踪任务或 destination

**非目标**：

- 不要求完全复刻 GTA5 Pause Menu 整套 tab
- 不要求 `v14` 首版展示剧情对话历史或奖励结算页

**验收口径**：

- 自动化测试至少断言：`M` 地图打开后存在正式 `Tasks` 页签/面板状态，而不是聊天里口头描述。
- 自动化测试至少断言：页签数据来自正式 task runtime。
- 自动化测试至少断言：在任务页签选择 active/available task 会同步 current tracked task 与 map highlight。
- 反作弊条款：不得通过把任务列表塞进 debug overlay、只在 headless 测试打印文本、或把地图完全隐藏成另一页来宣称完成。

### REQ-0007-005 世界任务标记必须复用现有火焰圈模型族

**动机**：用户明确要求“和目的地标记共用一套模型，但用绿色或蓝色，还是那个火焰圈儿的设定”。

**范围**：

- 任务 world marker 必须复用现有 destination marker 的视觉/动画模型族
- 至少提供两种主题：
  - `available start`：绿色
  - `active objective`：蓝色
- destination 继续保留当前导航主题

**非目标**：

- 不要求 `v14` 首版引入新的复杂 3D marker mesh
- 不要求全城所有任务世界圈永远可见

**验收口径**：

- 自动化测试至少断言：任务 world marker 与 destination marker 共享模型族或共享基类 contract。
- 自动化测试至少断言：绿色/蓝色主题能被正式区分。
- 自动化测试至少断言：世界里只渲染 active objective 与 nearby available starts，而不是全城常亮。
- 反作弊条款：不得通过再做第二套世界 marker、改成纯文字浮标、或把任务圈做成 UI 贴图来宣称完成。

### REQ-0007-006 玩家步行或驾驶车辆进入触发圈即可开始任务

**动机**：用户明确要求“player 或车触碰到绿圈儿，就可以触发任务的开始”。

**范围**：

- `available start slot` 支持玩家步行进入触发
- `available start slot` 支持玩家当前驾驶车辆进入触发
- 同一 start slot 被触发后，任务进入 `active`
- ambient traffic 不得误触发玩家任务

**非目标**：

- 不要求 `v14` 首版增加独立交互键确认
- 不要求 NPC 或别的车辆能为玩家接任务

**验收口径**：

- 自动化测试至少断言：玩家步行进入 start slot 会启动任务。
- 自动化测试至少断言：玩家驾驶车辆穿过 start slot 也会启动任务。
- 自动化测试至少断言：非玩家车辆不会误触发任务。
- 反作弊条款：不得通过只支持步行、不支持驾驶，或只在测试里直接调用 `start_task()` 来宣称完成。

### REQ-0007-007 任务开始后必须与 destination / route target 同源联动

**动机**：如果任务系统和导航系统各走各的，地图与世界标记很快就会漂移。

**范围**：

- 任务开始后，当前 active objective 应能转成正式 `resolved_target`
- map、minimap、world marker、task brief 共享同一 active task state
- active objective 可驱动当前 route / destination

**非目标**：

- 不要求每个任务都必须画 route；纯叙事任务可只更新 brief
- 不要求 `v14` 首版支持多目标并行导航

**验收口径**：

- 自动化测试至少断言：开始任务后，active objective 会产出正式 route target 或等价 tracked destination。
- 自动化测试至少断言：map/minimap/world marker/task brief 消费的是同一 active task。
- 自动化测试至少断言：完成 objective 后 active route 能按 contract 清理或切到下一步。
- 反作弊条款：不得通过让任务页签维护私有 current target、或者让世界 marker 不走导航链来宣称完成。

### REQ-0007-008 `v14` 不得破坏 deterministic、streaming 和性能红线

**动机**：任务系统属于强可见性功能，但不允许以牺牲 runtime redline 为代价实现。

**范围**：

- task catalog / slot index / runtime 必须保持 deterministic
- world marker runtime 必须尊重 active chunk / tracked task 限制
- map tab 和任务 pin 接入后，性能三件套仍需复验

**非目标**：

- 不要求 `v14` 首版重写全部 UI 基础设施
- 不要求 `v14` 首版做正式存档系统

**验收口径**：

- 自动化测试至少断言：相同 seed 下 task catalog / slot index 稳定。
- 自动化测试至少断言：world marker runtime 只处理活跃窗口内任务，不做全量每帧扫描。
- `test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 必须继续通过。
- 反作弊条款：不得通过关闭 minimap、关闭任务 world marker、减少 active tasks 到 0、或做 profiling 专用低配路径来宣称过线。

## Open Questions

- UI 最终是否直接使用 emoji 作为任务图标；当前建议 contract 固定 `icon_id`，呈现层再决定是否用 emoji。
- `completed` 任务在大地图默认是否继续显示；当前建议默认不显示，只在 `Tasks` 页签或过滤器里可见。
- `v14` 首版是否允许一个 active task 拥有多个 objective；当前建议首版先冻结为单 active objective。
- 任务状态是否跨 session 持久化；当前建议 `v14` 先维持 session-local runtime。

## Planning Freeze Notes

- `v14` 必须消费 `PRD-0006` 已交付的 `resolved_target + route_result + pin registry` 主链，不允许新开第二套任务导航链。
- `v14` 默认把 GTA5 的 `Map + Brief + Objective` 语义简化为“地图始终可见 + 旁侧 `Tasks` 页签”，而不是 literal 复刻整页暂停菜单。
- `v14` 默认 world 任务圈只显示 `nearby available starts + tracked active objective`。
- `v14` 默认允许玩家步行或驾驶当前车辆触发任务开始；不需要额外交互键。
