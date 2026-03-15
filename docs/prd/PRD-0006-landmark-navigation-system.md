# PRD-0006 Landmark Navigation System

## Vision

把 `godot_citys` 从“已经有世界道路骨架、小地图和粗粒度 route overlay”推进到“拥有正式地标/地址系统、可查询的道路与建筑名字、全屏地图、Task 图钉、lane-based 驾驶导航、HUD 转向提示、瞬移与自动驾驶消费链”的状态。成功标准不是给 minimap 多画几层线，而是建立一条稳定、可缓存、可搜索、可复用的位置语义链：

`road_graph + block_layout + vehicle lane graph -> place index -> target resolution -> route contract -> minimap / full map / HUD / task pins / teleport / auto-drive`

本 PRD 的目标用户仍然是项目开发者本人及后续协作 agent。核心价值是把“城市里每个重要地点都可被名字、地址或图钉定位，并能驱动正式导航消费链”做成正式 contract，同时继续守住 deterministic 与 `60 FPS = 16.67ms/frame` 的硬红线。

## Background

- `PRD-0001` 与 `v3` 已经建立 shared `road_graph`、2D minimap 投影和基础 route overlay。
- `v7` 已把道路语义和交叉口拓扑收口为正式 contract。
- `PRD-0003` 与 `v8` 已生成 `vehicle lane graph` 和 `intersection turn contract`，但当前没有正式玩家导航 consumer。
- `PRD-0004` 与 `v9` 已让玩家能 hijack 并驾驶车辆，因此 HUD 导航、瞬移和自动驾驶已经有明确消费对象。
- 当前默认 seed `424242` 下，世界已有 `31,860` 条 road edge、`10,621` 个 intersection、`89,679` 条 vehicle lane、`300,304` 个 block、`1,201,216` 个 parcel，但还没有正式 `Place Index`、正式地址系统和全屏地图。
- 当前 `CityMacroRouteGraph` 仍是 chunk-level Manhattan route，不足以支撑正式 turn-by-turn、地标检索和自动驾驶。

## Scope

本 PRD 覆盖 `v12 landmark + navigation` 大版本。

包含：

- 对道路、交叉口、建筑地址、地标的正式命名与检索
- 正式 `Place Index` 与 `Route Contract`
- lane-based 导航求解、偏航重算和 turn/maneuver 输出
- minimap 路线高亮与驾驶 HUD 导航提示
- `M` 全屏地图、世界暂停、任意地点选点设目的地
- 面向未来 Task 系统的泛型 pin overlay contract
- 一键瞬移到目标地点
- 玩家当前控制车辆的基础自动驾驶到目标地点

不包含：

- 不做 online/多人同步地图
- 不做语音播报
- 不做完整警察/任务/经济系统
- 不做 ambient traffic 的全局自动驾驶 AI 重构
- 不做真实邮政/现实城市一比一拟真

## Non-Goals

- 不追求把 `v12` 做成独立地图软件
- 不追求每个 building 都有 proper name
- 不追求自动驾驶在 `v12` 阶段具备复杂交通礼让、超车、事故恢复和全规则驾驶
- 不追求通过做第二套简化 road graph 或静态地图贴图来“假装完成”

## Requirements

### REQ-0006-001 世界必须生成正式 `Place Index`

**动机**：如果 road/building/landmark 名字只在 chunk mount 现场临时拼装，搜索、Task 图钉、HUD、瞬移和自动驾驶都不会有稳定上游。

**范围**：

- 在 world generation 阶段生成正式 `place_index / place_query / route_target_index`
- 至少覆盖 `road_cluster`、`intersection`、`addressable_building`、`landmark`
- place 数据必须可缓存、可重复生成、可脱离 chunk 生命周期工作

**非目标**：

- 不做外部数据库服务
- 不做只存在于 UI 层的临时 pin 名字表

**验收口径**：

- 自动化测试至少断言：`world_data` 暴露正式 `place_query` 或等价对象，而不是只有 minimap 绘制快照。
- 自动化测试至少断言：相同 seed 下 `place_id`、`display_name`、`routable_anchor` 可重复生成。
- 自动化测试至少断言：chunk 卸载后依然可以按名字查询 place。
- 反作弊条款：不得通过把名字临时塞进 HUD、把路线目标写死在测试里、或仅对已加载 chunk 生效来宣称完成。

### REQ-0006-002 道路和建筑地址必须遵守稳定命名/编号语法

**动机**：如果路名和门牌完全随机、没有语法，搜索与 HUD 文案都会退化成不可记忆的噪声。

**范围**：

- 道路名按 canonical `street cluster` 命名，不按 raw road edge 命名
- 建筑地址采用稳定的 block-based 编号规则
- 地址必须至少包含 `house_number + road_name`
- 交叉口支持合成式命名，如 `Jefferson Road & Atlas Avenue`

**非目标**：

- 不要求模拟现实 USPS 的全部细节
- 不要求每个 building 都有独立 proper name

**验收口径**：

- 自动化测试至少断言：同一 `street cluster` 下多段 road edge 共享 canonical road name。
- 自动化测试至少断言：地址编号保持 deterministic，且左右两侧奇偶分离。
- 自动化测试至少断言：同一 place 的 `display_name` 与 `normalized_name` 规则稳定，不因 chunk streaming 改变。
- 反作弊条款：不得通过给每条 edge 单独起名、给所有 building 只返回技术 ID、或把完整地址硬编码为不可解析字符串来宣称完成。

### REQ-0006-003 系统必须支持“名字/地址/图钉 -> 坐标/目标点”解析

**动机**：没有正式 target resolution，地图 UI、Task 图钉、瞬移和自动驾驶都会各做一套半成品入口。

**范围**：

- 支持按 road name、landmark name、full address、intersection name 解析目标
- 支持把 `task_pin` 或任意地图点击转换为 `resolved_target`
- 解析结果必须同时包含 `world_anchor` 和 `routable_anchor`

**非目标**：

- 不做模糊搜索排名的复杂机器学习
- 不做联网 geocoding

**验收口径**：

- 自动化测试至少断言：给定正式地址可以解析到稳定目标点。
- 自动化测试至少断言：给定路名或地标名会返回一致的 `resolved_target`，而不是随机最近点。
- 自动化测试至少断言：地图任意点击既可以保留 raw point，也可以解析出 nearest routable target。
- 反作弊条款：不得通过“名字只查字符串，不返回坐标”“只支持测试里那几个例子”“所有点击都强制传送到玩家附近”来宣称完成。

### REQ-0006-004 驾驶导航必须建立在正式 lane-based route contract 上

**动机**：chunk Manhattan 路线不足以支撑 road name、turn maneuver、偏航重算和自动驾驶。

**范围**：

- route planner 必须以 `vehicle lane graph + intersection turn contract` 或等价 driving graph 为上游
- route result 至少输出 `polyline`、`steps`、`maneuvers`、`snapped_origin`、`snapped_destination`
- 偏航后支持正式 reroute

**非目标**：

- 不要求 `v12` 就做多候选路线 UI
- 不要求路径求解同时支持 pedestrians 与 vehicles 两套模式

**验收口径**：

- 自动化测试至少断言：正式 route 不再只是 chunk 级 Manhattan 目标串。
- 自动化测试至少断言：route result 至少有一个带 turn type 和 road name 的 maneuver step。
- 自动化测试至少断言：车辆偏离路线后能得到新一代 route result，而不是继续沿旧折线死走。
- 反作弊条款：不得通过继续复用旧 `CityMacroRouteGraph`、只画直线、或 HUD 现场猜左右转来宣称完成。

### REQ-0006-005 minimap 与 HUD 必须消费同一份 route result

**动机**：如果 minimap、HUD、自动驾驶分别消费不同路线或不同目标解析，用户体验一定断裂。

**范围**：

- minimap route overlay 使用正式 route result
- 驾驶态 HUD 使用正式 maneuver steps 输出左转/右转/直行提示
- manual driving 时 route overlay 支持周期性更新

**非目标**：

- 不做语音导航
- 不做完整车道级图形指引

**验收口径**：

- 自动化测试至少断言：minimap、HUD 来自同一份 route result generation。
- 自动化测试至少断言：驾驶中移动位置后，路线会按配置频率更新而非永久静态。
- 自动化测试至少断言：HUD 至少能输出 `left/right/straight/u-turn` 中的一类正式 turn type。
- 反作弊条款：不得通过 minimap 用真实路线、HUD 用另一套硬编码文本来宣称完成。

### REQ-0006-006 `M` 全屏地图必须暂停世界并支持 destination select 与 pin overlay

**动机**：全屏地图是 GTA 式导航体验的正式入口，不是 minimap 放大镜。

**范围**：

- 按下 `M` 打开全城市地图
- 打开地图时，游戏世界暂停，地图 UI 仍可交互
- 地图支持任意地点选点设为当前 destination
- 地图支持泛型 pin overlay，未来 Task 系统可直接接入

**非目标**：

- 不做在线协作地图
- 不做完整任务系统本体

**验收口径**：

- 自动化测试至少断言：打开地图后世界 simulation 暂停，但地图 UI 仍可处理输入。
- 自动化测试至少断言：地图点击会生成正式 destination，而不是只在本地 UI 记一个临时点。
- 自动化测试至少断言：至少两类 pin 可同时渲染且可区分，例如 landmark pin 与 task/debug pin。
- 反作弊条款：不得通过“暂停整个树导致地图也不能操作”“地图只显示当前 chunk”“pin 只是贴图背景的一部分”来宣称完成。

### REQ-0006-007 同一目标必须支持瞬移和自动驾驶两种消费方式

**动机**：你明确要求一键瞬移到目标地点，也要求最终能自动开过去；这两者都必须基于同一套目标与路线语义。

**范围**：

- 任意 `resolved_target` 都可触发 fast travel 到安全落点
- 玩家当前控制车辆可触发基础 auto-drive，沿 route result 开往目标
- auto-drive 只针对玩家当前车辆，不扩展为全城 ambient traffic 控制系统

**非目标**：

- 不做 taxi service 玩法包装
- 不做复杂交通礼让、事故恢复、警察追逐

**验收口径**：

- 自动化测试至少断言：fast travel 消费同一 `resolved_target`，落点稳定且不落入无效地形。
- 自动化测试至少断言：auto-drive 使用正式 route steps，而不是重新走一套 chunk target 或直线追点。
- 自动化测试至少断言：玩家可中断 auto-drive，控制权明确返回。
- 反作弊条款：不得通过“瞬移直接忽略 target parser”“自动驾驶用直线朝目的地冲”“另起一套只给自动驾驶用的隐藏路线”来宣称完成。

### REQ-0006-008 `v12` 不得破坏 deterministic、cache 和性能红线

**动机**：地标与导航属于基础世界资产，不能以牺牲 shared graph / page cache / runtime redline 为代价实现。

**范围**：

- place index、route graph、map overlay 必须保持 deterministic
- cache 必须正式化，避免每次进图重算所有名字
- route 与地图系统加入后，性能三件套仍需复验

**非目标**：

- 不要求 `v12` 重写全部 profiling 基础设施
- 不要求 `v12` 一次性做完所有 POI 分类体系

**验收口径**：

- 自动化测试至少断言：相同 seed 下 `place_index` 和 route query 稳定。
- 自动化测试至少断言：place / route cache 正常命中，不因 UI 打开频繁重复构建整张世界元数据。
- `test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 必须继续通过。
- 反作弊条款：不得通过关闭 minimap、关闭 HUD、降低 traffic/crowd、或把地图系统做成 profiling 专用低配模式来宣称过线。

## Open Questions

- 命名风格默认是“完全虚构但沿用美式英语地址语法”，还是中英混合；当前默认按前者起草。
- `auto-drive` 在 `v12` 是否只做 player-only 基础跟路线控制，还是额外承担复杂交通礼让；当前默认前者。
- off-road 任意点击地图时，导航应默认 snap 到 nearest routable point，还是允许直接 raw-point teleport；当前建议两者并存，但 UI 默认导航走 snap。
