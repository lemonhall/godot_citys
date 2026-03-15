# V14 GTA5 任务系统与地图联动研究

## Executive Summary

`godot_citys` 已经在 `v12` 建立了 `full map + shared pin registry + destination world marker + route contract` 主链，但当前的 `task_pin` 仍只是 debug 级 pin，不具备正式 `任务定义 / 状态机 / 世界触发 / Brief 页面`。结合 GTA5 可观察到的 `Pause Menu Map/Brief`、`GPS/Quick GPS`、`Radar blip` 与 `corona` 任务触发语义，再对照仓库现有 `CityMapScreen`、`CityMapPinRegistry` 与 `CityDestinationWorldMarker`，`v14` 最合理的目标不是另做一套“任务 UI”，而是把任务系统正式接到现有导航链上：`task definition -> task runtime -> task pin / task brief -> full map / minimap / world ring / route target`。[1][2][3][4][5][6][8][9][10]

一个关键推断需要先写清楚：GTA5 并没有传统 RPG 那种厚重任务日志，而是把“地图、Brief、当前 Objective、blip、world trigger”组织成一个轻量但高频的任务表达系统。因此，`godot_citys` 的 `v14` 不应抄成“几十页 quest journal”，而应采取“地图始终可见 + 旁边放任务页签 + 世界里用共享火焰圈触发”的简化路线。这既更接近 GTA5 的产品语义，也更符合当前仓库已经存在的地图/导航底盘。[2][3][4][5][6][8][9]

## Key Findings

- **GTA5 的任务体验是“Map + Brief + Objective + GPS + World Trigger”的组合，不是单独的任务列表**：暂停菜单明确把 `Map` 和 `Brief` 作为并列入口，而交互菜单又提供 `Objective` 与 `Quick GPS`；这说明任务信息、目的地选择和导航提示在产品层本来就是一组联动能力。[1][2][3][6]
- **世界里的 `corona` 和雷达上的 blip 属于同一任务语义族**：GTA 系列长期用 `corona` 做任务入口/检查点，同时用雷达颜色和图标区分联系人、目标和关键地点；这和用户提出的“地图上有任务图标，世界里有绿/蓝火焰圈”高度一致。[4][5]
- **`godot_citys` 已经具备复用底盘，`v14` 应该是在现有导航 contract 上叠加任务 runtime，而不是新开第二套 marker / map / route 状态**：当前仓库已经有 `CityMapScreen.gd`、`CityMapPinRegistry.gd`、`CityDestinationWorldMarker.gd` 与相关 tests；真正缺的是 `task definition + task state + task trigger + task brief view model`。[8][9][10]
- **“emoji”更适合作为 UI 呈现层策略，而不该进入数据 contract**：任务状态应先冻结为 `status + icon_id + color_theme`，再由 full map / HUD 选择具体 glyph、emoji 或图标贴图。否则以后换字体、换 atlas、换主题会直接打断任务数据层。[4][8][9]
- **世界任务圈不能全城常亮，必须受 streaming / active window 约束**：大地图可以展示全局任务状态，但世界里的 ring marker 只应该对 `active task objective` 与 `nearby available start slots` 生效，否则既会视觉污染，也会破坏当前项目的 runtime budget 纪律。[8][9][10]

## Detailed Analysis

### GTA5 的任务表达不是厚重日志，而是“轻任务账本”

Rockstar 官方 `Grand Theft Auto V: The Manual` 明确把交互地图放在正式产品入口里，而 `Pause Menu` 页面则把 `Map`、`Brief`、`Stats`、`Settings`、`Game` 组织成稳定的暂停菜单结构；其中 `Brief` 负责承载帮助文本、当前任务目标、已播放对话与可回放任务。[1][2] 这说明 GTA5 的“任务页签”并不是独立于地图的另一个系统，而是紧贴地图、暂停和导航入口的一部分。

这对 `godot_citys` 很重要，因为用户并没有要求做一个剧情数据库，而是要求：按 `M` 打开大地图；大地图上看见待完成、进行中的任务；地图旁边有任务页签；走进绿圈或开车穿过绿圈就能开始任务。把这些拆开看，很容易误写成“地图一个功能、任务列表一个功能、世界 marker 又一个功能”；但从 GTA5 的产品语义看，它们其实应该被组织成一个轻任务账本：地图负责空间上下文，任务页签负责状态和摘要，GPS 负责当前追踪目标，world trigger 负责进入任务流程。[1][2][3][6]

这里有一个明确的设计推断：`godot_citys` 的 `v14` 不需要 literal 复刻 GTA5 的暂停菜单整页切换；更合理的做法是保留现有地图画布，让地图始终可见，再在旁边加一个 `Tasks` 页签/面板，承担 GTA5 `Brief + Objective` 的简化职责。这种“地图不消失、任务摘要贴边”的做法，比完全切页更适合当前仓库已有的 `CityMapScreen` 架构，也更贴合用户“地图旁边加一个任务系统页签”的原始要求。[2][6][8]

### GTA5 的地图与导航语义说明：任务必须有稳定状态，不应只是一堆 pin

`GPS` 页面说明，玩家既可以在地图上手动设置 marker，也可以通过快捷入口快速把某类地点设为当前导航目标；而 `Interaction Menu` 里又长期存在 `Quick GPS`、`Objective`、`Brief` 这种高频入口。[3][6] 换句话说，任务系统不是“让地图多画几个点”就结束了，它必须回答三个问题：

1. 当前有哪些可接任务？
2. 当前正在追踪哪个任务？
3. 当前任务的空间目标是什么？

如果把这些状态都塞回 `pin_type == task` 一个字段里，`v14` 最终就会退回到 debug pin。更合理的 contract 应该把任务状态至少冻结为：

- `available`
- `active`
- `completed`

并允许未来扩展：

- `locked`
- `failed`

其中大地图默认显示 `available + active`，`completed` 更适合进 `Tasks` 页签或过滤器，而不是默认铺满地图。这个做法既接近 GTA5 的轻量表达，也能避免满屏噪点。[2][3][4][6]

### Radar blip 与 corona 给出的启发：地图 pin 和世界圈必须共享同一任务身份

`Radar` 页面显示，不同颜色和 blip 被用于联系人、任务点、目标物与特殊地点；`Strangers and Freaks` 页面则进一步说明，地图上会用 `?` 之类的 icon 标识特定任务类别。[4][7] 另一方面，`Corona` 页面显示，这种圆柱/光圈型 marker 会被用于任务入口、检查点和各种需要玩家走进去触发的交互面。[5]

这说明 GTA 风格的任务系统有一条稳定共识：**地图 icon 与世界触发体并不是两套东西，它们共享同一个任务身份，只是展示介质不同。**

因此，对 `godot_citys` 而言，任务 definition 至少需要稳定携带：

- `task_id`
- `slot_id`
- `slot_kind`
- `world_anchor`
- `trigger_radius_m`
- `status`
- `pin_icon_id`
- `marker_theme`

这样一来：

- full map 可把它渲染成任务 pin；
- minimap 可只投影当前追踪任务和附近可接任务；
- world ring runtime 可把它渲染成 green / blue flame ring；
- trigger system 可用同一个 `slot_id` 判断玩家或车辆是否已进入触发区。

用户点名的“和目的地标记可以共用一套模型，但使用绿色或者蓝色，还是火焰圈设定”，本质上就是要求把 `world marker` 做成 parametric consumer，而不是另起一套新模型。这与仓库现有 `CityDestinationWorldMarker.gd` 的动画结构非常匹配。[5][8][9][10]

### 对 `godot_citys` 当前架构的直接含义：v14 应复用现有地图/导航底盘

本地代码已经给出了很清晰的现实边界。`CityPrototype.gd` 当前已经负责：

- `M` 打开/关闭 full map
- `select_map_destination_from_world_point()`
- `register_task_pin()`
- `CityMapScreen` 与 `CityMapPinRegistry` 的同步
- `CityDestinationWorldMarker` 的世界圈呈现

但这里的 `task_pin` 仍是手工注册 pin，缺少正式 runtime；`PrototypeHud.gd` 也还没有真正的任务导航状态面板；现有测试覆盖的是 map pin overlay 和 destination world marker contract，而不是正式任务系统。[8][9][10]

所以 `v14` 最值得做的不是把地图 UI 完全推翻，而是把缺口补在正确层上：

1. 新增 `task definition / slot catalog / task runtime`
2. 让 `task runtime` 产出正式 pin 投影和 brief view model
3. 让 `full map / minimap / world ring / route target` 全都消费同一份任务状态

这条路径与 `v12` 的主链完全一致：

`resolved_target + route_result + pin_registry`

只是 `v14` 要把它扩成：

`task_catalog + task_runtime -> task_pin_projection / task_brief -> full map / minimap / world ring / route target`

如果 `v14` 反而再造一个 `task map state`、`task world marker manager`、`task objective route solver`，那就等于把 `v12` 的导航资产拆回多套 consumer，属于明显回退。[8][9][10]

### 推荐的 v14 任务模型：先把“任务 slot”写硬

用户特别强调“做一个 slot 放在那里就行”，这很关键。对当前项目来说，最自然的任务 authoring 单元不是 cutscene node，也不是复杂脚本图，而是 `task slot`：

- `start slot`
- `objective slot`
- `complete slot`（可与 objective 合并）

首版任务完全可以是“单 start slot + 单 objective slot”的简化模型：

- 玩家/车辆进入绿色 `start slot` -> 任务从 `available` 进入 `active`
- 当前 active objective 变成蓝色 pin / 蓝色 world ring
- 玩家/车辆进入 objective slot -> 任务变成 `completed`

这样 `v14` 就能稳定回答“待完成、进行中、世界里也有标记、任务能开始”这四件最关键的事，同时不被过早拉进剧情树、奖励系统和多阶段导演系统。[4][5][8][9][10]

## Areas of Consensus

- GTA5 风格的任务表达更接近“地图 + Brief + Objective + world trigger”的轻组合，而不是重型 quest journal。[1][2][3][5][6]
- 地图 pin、任务页签、GPS 和世界触发圈必须共享同一份任务身份与状态，不应分别维护私有状态。[3][4][5][8][9]
- `godot_citys` 当前应复用 `CityMapScreen`、`CityMapPinRegistry` 与 `CityDestinationWorldMarker`，而不是另做第二套任务地图/marker 体系。[8][9][10]
- 世界里的任务圈必须受 active chunk / tracked task 限制，不宜把所有任务一股脑常亮到 3D 世界里。[5][8][9][10]

## Areas of Debate

- **emoji 还是 icon atlas**：用户明确接受 emoji 风格，但从工程角度更稳的是冻结 `icon_id`，把 emoji 只当 UI 呈现选择，不写进数据 contract。
- **大地图是否显示全部已完成任务**：研究更倾向“大地图默认显示 `available + active`，`completed` 放任务页签/过滤器”，否则会快速污染视图。
- **任务是否首版就持久化到磁盘**：当前更合理的口径是 `v14` 先做 session-local runtime，等后续有正式 save system 再接持久化。
- **世界里是否显示所有 available 任务圈**：研究结论倾向“只显示附近可接任务圈 + 当前 active objective ring”，而不是全城常亮。

## Sources

[1] Rockstar Games, *Grand Theft Auto V: The Manual* app listing, Google Play. 官方 companion app 入口，说明 GTA V 把交互地图和手册作为正式产品层能力。https://play.google.com/store/apps/details?id=com.rockstargames.gtavmanual

[2] GTA Wiki, *Pause Menu*. 社区整理的 GTA 暂停菜单结构，包含 `Map`、`Brief`、`Replay Mission` 等可观察产品语义。https://gta.fandom.com/wiki/Pause_Menu

[3] GTA Wiki, *GPS*. 社区整理的 GTA 导航行为，覆盖地图 marker、雷达路线与快速设定目的地。https://gta.fandom.com/wiki/GPS

[4] GTA Wiki, *Radar*. 社区整理的雷达颜色、blip 和任务联系人/目标显示规则。https://gta.fandom.com/wiki/Radar

[5] GTA Wiki, *Corona*. 社区整理的世界触发圈/检查点 marker 语义，可作为任务 start/objective 圈设计参考。https://gta.fandom.com/wiki/Corona

[6] GTA Wiki, *Interaction Menu*. 社区整理的 `Objective`、`Brief`、`Quick GPS` 等高频任务/导航入口。https://gta.fandom.com/wiki/Interaction_Menu

[7] GTA Wiki, *Strangers and Freaks*. 社区整理的 GTA V 任务类别与地图图标例子，说明任务可以按类别做 icon 识别。https://gta.fandom.com/wiki/Strangers_and_Freaks

[8] 本地代码证据：[`city_game/scripts/CityPrototype.gd`](../../city_game/scripts/CityPrototype.gd)。用于确认当前已经具备 `M` 全屏地图、destination select、shared pin registry、destination world marker 和 route consumer 同步入口。（项目内一手证据，高可信）

[9] 本地代码证据：[`city_game/ui/CityMapScreen.gd`](../../city_game/ui/CityMapScreen.gd)、[`city_game/world/map/CityMapPinRegistry.gd`](../../city_game/world/map/CityMapPinRegistry.gd)、[`city_game/world/navigation/CityDestinationWorldMarker.gd`](../../city_game/world/navigation/CityDestinationWorldMarker.gd)。用于确认当前地图、pin、火焰圈模型都已经存在且可复用。（项目内一手证据，高可信）

[10] 本地测试证据：[`tests/world/test_city_map_pin_overlay.gd`](../../tests/world/test_city_map_pin_overlay.gd)、[`tests/world/test_city_pin_priority_contract.gd`](../../tests/world/test_city_pin_priority_contract.gd)、[`tests/world/test_city_destination_world_marker_contract.gd`](../../tests/world/test_city_destination_world_marker_contract.gd)。用于确认现有 pin overlay、destination 优先级和世界 marker contract 已被自动化测试锁住。（项目内一手证据，高可信）

## Gaps and Further Research

- 还需要在实现前决定 `v14` 首批任务数量级，以及它们更适合挂在 `landmark`、`addressable_building` 还是固定世界坐标上。
- 还需要确定 UI 是否直接渲染 emoji，还是先落一个小型 icon atlas；当前研究建议 contract 固定为 `icon_id`，呈现层再决定。
- 还需要在实现前写硬 “active objective 是否总是自动变成当前 destination”，当前推荐默认自动追踪，但允许玩家在任务页签里切换。
- 如果后续打算做剧情链、奖励链、失败条件或跨 session 存档，需要在 `v15+` 另开专门 PRD，而不是在 `v14` 混写进去。
