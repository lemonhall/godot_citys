# PRD-0002 Pedestrian Crowd Foundation

## Vision

把 `godot_citys` 从“城市骨架已经成立、但街道过于空旷”的状态，推进到“在不打穿 `60 FPS = 16.67ms/frame` 红线的前提下，拥有可信街道人流氛围”的状态。成功标准不是把全城都塞满复杂 NPC，而是让玩家在多个 district 中移动时，能看到与道路、路口、街区形态一致的 sidewalk / crossing pedestrians；只有极少数靠近玩家的个体会升级为更高保真的 reactive agent，其余人流必须建立在可 streaming、可 profiling、可量化预算控制的系统之上。

本 PRD 的目标用户仍然是项目开发者本人及后续协作 agent。核心价值不是先做“玩法型 NPC”，而是为未来的任务、势力、交通、事件和更复杂 AI 打一套不会轻易返工的人群底盘。

## Background

- `PRD-0001` 已完成大城市基础设施与 `v2-v5` 的世界、路网、路面与地形性能底盘。
- `PRD-0001` 明确把“行人社会模拟和群体行为”列为 v2 非目标，因此街道人群需要一个新的 PRD 口径，而不是硬塞进旧范围。
- 研究结论见 [`2026-03-12-open-world-pedestrian-crowd-performance-research.md`](../research/2026-03-12-open-world-pedestrian-crowd-performance-research.md)。
- 当前项目级纪律已将 `60 FPS = 16.67ms/frame` 定义为硬红线，任何新功能不得以“以后再优化”为由突破这条红线。

## Scope

本 PRD 只覆盖“大城市街道人群基础设施 v6”。

包含：

- 确定性的 pedestrian config、archetype、density profile 与 spawn seed 派生规则
- 从 `road_graph` / `block` 数据派生的 `sidewalk/crossing lane graph`
- Tier 0-3 的分层 pedestrian representation、simulation LOD 与 render LOD
- 与现有 chunk streaming 对齐的 spawn / despawn / warm-cache 预算体系
- 玩家附近极小集合的本地 reactive pedestrian 行为
- crowd 相关 debug overlay、minimap 调试层与 profiling 指标
- 面向 `16.67ms/frame` 红线的 crowd lite 默认模式与回归护栏

不包含：

- 全城级 social simulation、完整日程表、职业/家庭系统
- 全体行人的 `NavigationAgent3D + avoidance` 常驻运行
- 商店、对话、任务、警察、犯罪或派系关系
- 车辆与行人的完整让行、碰撞博弈和交通规则
- ragdoll、布料、复杂群体物理、群体挤压求解

## Non-Goals

- 不追求 v6 阶段就做成 GTA / 2077 级完整城市 NPC 生态
- 不追求所有可见行人都能与玩家深度交互
- 不追求在第一轮就支持室内、楼梯塔、地铁和全套高架步行系统
- 不追求把 crowd 问题一次性做到“最终版本”

## Requirements

### REQ-0002-001 行人世界配置与确定性分布

**动机**：没有统一的 pedestrian 配置、spawn seed 和 density profile，后续 streaming、回访一致性、调试和 minimap 都会失去稳定锚点。

**范围**：

- 提供统一的 pedestrian world config
- 定义 district / road class / lane class 到 pedestrian density 的映射
- 定义 `chunk -> lane -> spawn_slot` 的确定性 seed 派生规则
- 提供不依赖场景实例化的 pedestrian query API

**非目标**：

- 不做用户可编辑的 crowd density UI
- 不做白天/夜晚完整 schedule

**验收口径**：

- 固定世界 seed 下，连续两次运行得到完全相同的 lane IDs、spawn slot IDs、density bucket 和 pedestrian roster signatures。
- 自动化测试至少断言一个固定 seed 的 `get_pedestrian_query_for_chunk()` 返回稳定的 lane graph 引用、spawn capacity 和 density profile。
- 反作弊条款：不得用手工摆放的固定 NPC 节点列表冒充“确定性分布系统”。

### REQ-0002-002 从道路图派生的 sidewalk / crossing lane graph

**动机**：如果行人路径不是从同一份 `road_graph` 派生出来，而是每个 chunk 本地随机生成，街道人流一定会再次出现支离破碎和拼接感。

**范围**：

- 从 `road_graph`、道路宽度、路口和 block 边界派生 pedestrian lane graph
- 提供 sidewalk lane、crossing lane 和必要的等待点 / 接驳点
- 保证 pedestrian spawn / route 不落在机动车道路面内部
- 支持按 chunk / rect 查询 lane 子图

**非目标**：

- 不做最终人工编辑器
- 不做全城一张巨型静态 navmesh

**验收口径**：

- 自动化测试至少断言：主要道路两侧存在与道路方向一致的 sidewalk lane，路口存在 crossing connection，且 lane graph 拓扑在 chunk 边界连续。
- 自动化测试至少断言：pedestrian spawn anchors 与机动车路面保持最小缓冲区退距，只允许在 crossing lane 中穿越路面。
- 反作弊条款：不得保留“每 chunk 随机散点摆人”作为主要行人分布来源。

### REQ-0002-003 分层 pedestrian representation 与 continuity

**动机**：如果所有可见行人都以完整节点和完整行为常驻，项目会在“看起来有人了”的同时立即失去性能边界。

**范围**：

- 建立 Tier 0-3 的 pedestrian 分层表示：
  - Tier 0：数据层 occupancy / reservation
  - Tier 1：中远景 batched ambient visuals
  - Tier 2：近景 lightweight local agents
  - Tier 3：近场 reactive agents
- tier 切换必须保持同一 pedestrian identity / route continuity
- Tier 1 必须优先使用 batched representation，而不是大量独立节点

**非目标**：

- 不做所有 tier 的完整骨骼动画
- 不做所有 tier 的物理碰撞

**验收口径**：

- 默认 `lite` 预设下，运行时 Tier 1 可见实例总数不得超过 `768`，Tier 2 不得超过 `96`，Tier 3 不得超过 `24`。
- 自动化测试至少断言：同一 pedestrian 在 tier 升降级前后的 `pedestrian_id`、route signature 和 archetype signature 一致。
- 自动化测试至少断言：Tier 1 使用 `MultiMesh` 或等价 batched representation，而不是把每个行人单独实例化为节点树。
- 反作弊条款：不得通过把 density 直接设为 `0` 来宣称 tier 切换与性能达标。

### REQ-0002-004 Streaming-aware spawn / despawn 与预算约束

**动机**：大城市 crowd 的关键不是总量，而是“当前窗口内高成本集合的数量必须可控”。

**范围**：

- pedestrian 系统必须对齐现有 `5x5` active chunk window
- 允许 cold / warm / active 多级状态，而不是所有人一卸就空
- 提供 chunk / lane page 级的 crowd cache 或等价复用机制
- 支持玩家移动时的稳定 promotion / demotion / despawn

**非目标**：

- 不做全城实时常驻 agent
- 不做多人同步

**验收口径**：

- 任意时刻高成本 Tier 2 + Tier 3 的总量不得突破配置上限。
- 玩家跨越至少 `8` 个 chunk 的自动化 travel 测试中，不允许出现 crowd count leak、重复加载同一 pedestrian page 或明显的 spawn storm。
- 自动化测试至少断言：回访已访问区域时，crowd query / lane page 存在 cache hit 或等价复用证据。
- 反作弊条款：不得通过“离开一个 chunk 就把全部 ped 清零、回到原地再全部重掷”来伪造 streaming。

### REQ-0002-005 玩家附近的有限 reactive pedestrian 行为

**动机**：纯背景板式行人可以提供氛围，但完全没有近场反应会削弱城市的临场感；同时反应层又必须严格受限，不能扩散成全城 AI。

**范围**：

- Tier 3 pedestrian 可在玩家附近执行有限的等待、让路、sidestep、panic / flee 反应
- 允许对枪火、子弹近掠、爆炸或玩家高速接近作出反应
- 只在极小集合中允许局部 steering / avoidance 或等价近场避让

**非目标**：

- 不做 combat NPC
- 不做武器系统之外的复杂情绪与社交关系

**验收口径**：

- 自动化测试至少断言：玩家靠近、开火或投掷爆炸物时，附近 pedestrian 会在配置半径内切换到 reaction state。
- Tier 3 reactive pedestrian 数量必须持续 `<= 24`，且离开近场后会自动降级回较低 tier。
- 反作弊条款：不得通过“反应 = 立即删除行人”冒充 reactive behavior。

### REQ-0002-006 运行时观测、调试与地图投影

**动机**：没有 crowd 观测面板和调试图层，就无法判断“街上为什么没人”“为什么都挤在一起”“为什么帧耗突然上涨”。

**范围**：

- 提供 crowd 相关 debug overlay / log 字段
- 提供默认折叠、可展开的 crowd 调试面板
- 提供全局 crowd 可见性调试开关：按下 `小键盘 *` 时，可在“全部显示 / 全部隐藏”之间切换行人可见性
- 提供全局 FPS 调试开关：按下 `小键盘 -` 时，在画面右上角显示/隐藏 FPS
- 暴露当前各 tier 数量、spawn / despawn 统计、lane graph page 命中、crowd update 耗时
- minimap 至少提供 crowd density 或 pedestrian debug markers 的调试图层

**非目标**：

- 不做最终用户地图 UI
- 不做完整 crowd profiler 替代品

**验收口径**：

- 自动化测试或脚本输出中必须能读取 `ped_tier0_count`、`ped_tier1_count`、`ped_tier2_count`、`ped_tier3_count`、`crowd_update_avg_usec` 和至少一个 crowd page/cache 指标。
- 自动化测试至少断言：按下 `小键盘 *` 后，行人可见性会在“全部显示 / 全部隐藏”之间切换，再次按下可恢复。
- 自动化测试至少断言：按下 `小键盘 -` 后，右上角 FPS 文本会显示/隐藏；FPS `< 30` 为红色，`30-50` 为黄色，`> 50` 为绿色。
- 自动化测试至少断言：minimap crowd debug layer 使用与 3D crowd 同源的 lane / density 数据，而不是另一份独立随机示意图。
- 反作弊条款：不得只在文档中写 crowd 预算数字而没有实际运行时输出。

### REQ-0002-007 Crowd 性能红线与端到端验证

**动机**：当前项目的世界底盘刚守住 `16.67ms/frame` 红线；如果 v6 没有把 crowd 的性能验收写死，前面几轮专项会被很快抵消。

**范围**：

- crowd 默认模式必须是 `pedestrian_mode = lite`
- crowd 相关里程碑每完成一个 `M` 都必须重新跑 fresh profiling
- 扩展 runtime profile 与 E2E travel/profile 测试，覆盖“有人流时”的真实链路
- crowd profile 必须拆出 update / spawn / render commit 等分项

**非目标**：

- 不要求 v6 第一轮就交付 `full` crowd 模式
- 不要求在本阶段下沉到 C++ / GDExtension

**验收口径**：

- 在 `pedestrian_mode = lite` 且固定 density 预设下，fresh warm traversal 与 first-visit traversal 的 `wall_frame_avg_usec` 都必须 `<= 16667`。
- 自动化 profiling 输出必须新增 `crowd_update_avg_usec`、`crowd_spawn_avg_usec`、`crowd_render_commit_avg_usec` 与各 tier 计数。
- 反作弊条款：不得通过 profiling 时临时关闭 pedestrians、把 density 改成 `0` 或仅渲染空壳占位来宣称达标。

## Open Questions

- `v6` 的默认 density 预设最终应按 district class 做多大差异，还需要在 M1 后结合人工试玩与 profiling 微调。
- 是否需要在 `v6` 预留“路边等待点 / 斑马线信号相位”字段，目前看建议预留数据槽位，但不把完整信号系统纳入范围。

这些问题当前不阻塞 `v6` 开工，暂不单独开 ECN。
