# PRD-0002 Pedestrian Crowd Foundation

## Vision

把 `godot_citys` 从“城市骨架已经成立、但街道过于空旷”的状态，推进到“在不打穿 `60 FPS = 16.67ms/frame` 红线的前提下，拥有可信街道人流氛围”的状态。成功标准不是把全城都塞满复杂 NPC，而是让玩家在多个 district 中移动时，能看到与道路、路口、街区形态一致的 sidewalk / crossing pedestrians；只有极少数靠近玩家的个体会升级为更高保真的 reactive agent，其余人流必须建立在可 streaming、可 profiling、可量化预算控制的系统之上。

本 PRD 的目标用户仍然是项目开发者本人及后续协作 agent。核心价值不是先做“玩法型 NPC”，而是为未来的任务、势力、交通、事件和更复杂 AI 打一套不会轻易返工的人群底盘。

## Background

- `PRD-0001` 已完成大城市基础设施与 `v2-v5` 的世界、路网、路面与地形性能底盘。
- `PRD-0001` 明确把“行人社会模拟和群体行为”列为 v2 非目标，因此街道人群需要一个新的 PRD 口径，而不是硬塞进旧范围。
- 研究结论见 [`2026-03-12-open-world-pedestrian-crowd-performance-research.md`](../research/2026-03-12-open-world-pedestrian-crowd-performance-research.md)。
- 高密度 crowd 架构恢复专项研究见 [`2026-03-13-high-density-pedestrian-crowd-architecture-research.md`](../research/2026-03-13-high-density-pedestrian-crowd-architecture-research.md)。
- 当前项目级纪律已将 `60 FPS = 16.67ms/frame` 定义为硬红线，任何新功能不得以“以后再优化”为由突破这条红线。

## Scope

本 PRD 只覆盖“大城市街道人群基础设施 v6”。

包含：

- 确定性的 pedestrian config、archetype、density profile 与 spawn seed 派生规则
- 从 `road_graph` / `block` 数据派生的 `sidewalk/crossing lane graph`
- Tier 0-3 的分层 pedestrian representation、simulation LOD 与 render LOD
- 与现有 chunk streaming 对齐的 spawn / despawn / warm-cache 预算体系
- 玩家附近极小集合的本地 reactive pedestrian 行为
- 运行期 pedestrian 贴地与真实 chunk 地表口径一致
- 玩家暴力触发的 direct-hit / explosion casualty 与周边逃散响应
- 玩家暴力事件引发的 witness-level 局部恐慌扩散与四散逃离
- 提升 `pedestrian_mode = lite` 下的默认 crowd density，使主街与核心区不再显得过度稀疏
- 近景 civilian 模型的视觉尺度必须对齐 player 参考圆柱体，并对 manifest / 导入尺度异常保持鲁棒
- 连续枪击 / 爆炸威胁下的 pedestrian reaction / locomotion 状态机必须稳定，不得抖回 ambient walk
- `C` 切出的 inspection 模式只改变玩家移动模式，不得把“仅靠近玩家”误广播成 panic / flee threat
- casualty death visual 必须在 tier 切换、live roster 移除与 chunk 回访路径中保持稳定可见
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
- [已由 ECN-0013 补充] 自动化测试至少断言：Tier 1 的 batched representation 具备 page-local 或 chunk-local 的可复用实例槽位合同，稳定帧下不得继续把整个 active crowd window 的 Tier 1 render state 全量重写一遍。
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
- [已由 ECN-0013 补充] 自动化测试至少断言：page runtime / chunk snapshot 在无结构变化时保持可复用，不允许继续依赖“每帧清空后重建全部 active chunk crowd snapshot”这一类全量式运行时模式。
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
- [已由 ECN-0013 补充] 自动化测试或脚本输出中还必须能读取 `crowd_active_state_count`、`crowd_step_usec`、`crowd_reaction_usec`、`crowd_rank_usec`、`crowd_snapshot_rebuild_usec`、`crowd_chunk_commit_usec`、`crowd_tier1_transform_writes` 或等价 breakdown 字段，用于证明 crowd 热点已经从全量 rebuild 路径中被拆开。
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
- [已由 ECN-0013 补充] 自动化 profiling 输出必须能把 crowd update 再拆到至少 `step / reaction / rank / snapshot rebuild / chunk commit / tier1 transform writes` 级别，用于证明红线恢复来自运行时结构改造，而不是巧合。
- [已由 ECN-0013 补充] 对 `REQ-0002-016` 的 warm `540` / first-visit `600` 数量级 uplift，必须与本条红线在同一工作区、同一默认 `lite` 配置下同时成立；不得接受“density 绿但 profile 红”或“profile 绿但 density 红”的分裂状态。
- 反作弊条款：不得通过 profiling 时临时关闭 pedestrians、把 density 改成 `0` 或仅渲染空壳占位来宣称达标。

### REQ-0002-008 运行期贴地一致性（新增，见 ECN-0009）

**动机**：如果 pedestrian 只在 spawn 时落地正确，但运行期行走仍沿用固定 `y` 或基础噪声地形高度，那么在 roadbed、坡地和局部地形过渡上就会继续出现“被地形吞没 / 浮在地表上方”的产品级穿帮。

**范围**：

- active pedestrian 的 `world_position.y` 必须使用与真实 chunk 地表一致的采样口径，而不是只读基础噪声高度
- 贴地必须覆盖 spawn、运行期 step、tier 升降级与 chunk 回访后的重建
- 允许通过 chunk/profile-aware sampler、缓存过的 ground context 或等价机制实现

**非目标**：

- 不做 foot IK
- 不做室内、楼梯塔或多层步行桥系统

**验收口径**：

- 自动化测试至少断言：active pedestrian 在 spawn 后和运行期移动后，其 `world_position.y` 与对应 runtime ground surface 的误差持续 `<= 0.05m`，并覆盖至少一个坡地 lane 与一个受 roadbed 影响的 lane。
- 自动化测试至少断言：同一次运行中，位于不同地表高度的 pedestrian 不会继续共享单一固定 `y` 契约。
- 反作弊条款：不得通过冻结 `y` 更新、施加全局常数偏移或只在测试数据中避开问题 lane 来冒充“贴地一致性已成立”。

### REQ-0002-009 玩家暴力触发的 civilian casualty 与逃散（新增，见 ECN-0009）

**动机**：如果玩家开枪、直接命中或投掷手雷后，街道人群只会做非致命 reaction 而不会结算死亡与周边逃散，那么 crowd 会继续停留在“背景板”层，无法提供可信的城市暴力反馈。

**范围**：

- 玩家 projectile 的 direct hit 必须能杀死被命中的 pedestrian
- 爆炸必须对 lethal radius 内 pedestrian 结算死亡，对外圈 threat radius 内 pedestrian 触发 `panic / flee`
- casualty / flee 结算必须继续建立在 budgeted、event-driven crowd runtime 上，而不是把所有 pedestrian 升级为常驻 combat NPC

**非目标**：

- 不做警察 / wanted system
- 不做 ragdoll、持久尸体物理或 civilian 反击战斗

**验收口径**：

- 自动化测试至少断言：player projectile 的 direct hit 会杀死目标 pedestrian，并使其从 live crowd roster 或 active render set 中移除。
- 自动化测试至少断言：grenade / explosion 对 lethal radius 内 pedestrian 结算死亡，对 threat radius 内但 lethal radius 外 pedestrian 切换到 `panic` 或 `flee`。
- 自动化测试至少断言：threat radius 外 pedestrian 保持存活并继续 ambient 行为，不发生全图级 panic。
- 自动化测试至少断言：重复 fire / explosion 事件后，nearfield / Tier 3 预算仍受控，不出现 count leak。
- 反作弊条款：不得通过“只播 reaction、不结算死亡”“战斗时直接隐藏全部 pedestrian”或“爆炸半径内无差别全删”来宣称需求完成。

### REQ-0002-010 目击暴力后的局部恐慌扩散（新增，见 ECN-0010）

**动机**：即便 direct victim 已经会死亡，如果枪杀、连发枪声或手雷爆炸发生后，周围存活 pedestrian 仍继续按 ambient 状态行走，不形成玩家可感知的四散逃离，那么 crowd 仍然会显得像“只对受害者本身生效”的脚本，而不是可信城市人群。

**范围**：

- player gunfire、direct-hit casualty、grenade / explosion 必须产生 `500m` audible / witness threat event，而不是只影响 direct victim 或 lethal ring
- 位于 `500m` 半径内、且仍然存活的 pedestrian，即使没有被直接命中或处于 lethal radius 内，也必须能切换到 `panic` 或 `flee`
- witness selection / promotion 必须继续服从 `nearfield` / Tier 3 预算约束，可通过事件优先级、lane corridor、chunk-local query 或等价机制选择最相关 witness；不得把半径内所有 pedestrian 升级为常驻高成本 agent
- flee response 必须在真实运行期可见：进入 `panic / flee` 的 pedestrian 以至少 `4x base speed` 逃散，并且单次逃散位移必须 `>= 500m`

**非目标**：

- 不做全图级 rumor / panic propagation
- 不做警察、wanted、广播链或长期记忆系统
- 不做 civilian 结伴、呼救、掩体搜索等更复杂战术行为

**验收口径**：

- 自动化测试至少断言：automatic rifle 或等价连续枪击的 gunshot 声本身，就会让 `500m` 内、至少 `2` 名未被直接命中的存活 witness pedestrian 在 `0.5s` 内切换到 `panic` 或 `flee`。
- 自动化测试至少断言：grenade / explosion 或 casualty 发生后，位于 `500m` witness radius 内的存活 pedestrian 会切换到 `panic` 或 `flee`，而不是只有直接受害者状态改变。
- 自动化测试至少断言：进入 `panic / flee` 的 pedestrian 以至少 `4x base speed` 逃散，并且不会在跑满 `500m` 前提前停止。
- 自动化测试至少断言：`>500m` 的 pedestrian 保持 ambient 行为，不发生全图级 panic。
- 自动化测试至少断言：重复 gunfire / explosion 事件后，Tier 3 仍持续 `<= 24`，`nearfield` 总量仍持续受控，不出现 witness count leak。
- 反作弊条款：不得通过“所有 pedestrian 一起全局切 flee”“只让 direct victim 或 lethal survivor 改状态”“把 witness 直接删掉”或“让 flee 用短倒计时提前结束”来宣称需求完成。

### REQ-0002-011 Lite 模式下的人流密度抬升（新增，见 ECN-0010）

**动机**：如果 `pedestrian_mode = lite` 虽然守住了性能红线，但街道主观感知仍然过于空旷，那么 crowd 系统就只完成了“能跑”，没有完成“像一座有人活动的城市”。

**范围**：

- 上调默认 `district_class_density` 与 `road_class_density`，优先提升 core / mixed / 主街路段的人流存在感
- 视需要同步调整 deterministic spawn-slot 分配阈值或等价 lane occupancy 规则，但必须保持 deterministic query 契约
- density uplift 必须优先吃掉当前远未用满的 Tier 1 headroom，而不是先把 Tier 2 / Tier 3 高成本预算继续抬高
- uplift 后仍需保留 district / road class 之间的层次差异，不能把全城抹平成同一密度

**非目标**：

- 不做 `full` crowd 模式
- 不做“所有区域都像 downtown 一样满”的统一饱和填充
- 不做用重复静止假人、纯 billboard 占位或关闭 continuity 的方式伪造高密度

**验收口径**：

- 自动化测试至少断言：`pedestrian_mode = lite` 默认配置下，`core >= 0.78`、`mixed >= 0.62`、`residential >= 0.46`、`industrial >= 0.30`、`periphery >= 0.16`，且保持 `core > mixed > residential > industrial > periphery`。
- 自动化测试至少断言：`pedestrian_mode = lite` 默认配置下，`arterial >= 0.45`、`secondary >= 0.32`、`collector >= 0.20`、`local >= 0.12`，且保持 `arterial > secondary > collector > local > expressway_elevated`。
- 自动化 profiling 至少断言：沿当前固定 warm/first-visit profiling 路线，`ped_tier1_count` 至少达到 warm `>= 24`、first-visit `>= 52`，不得继续回到 M6 的稀疏基线。
- fresh isolated `tests/e2e/test_city_pedestrian_performance_profile.gd` 与 `tests/e2e/test_city_runtime_performance_profile.gd` 必须继续 `PASS`，且 `wall_frame_avg_usec <= 16667`。
- 反作弊条款：不得通过提高 Tier 2 / Tier 3 hard cap、复制同一 pedestrian visual、关闭 identity continuity 或把所有 district 强行拉到同一高密度来宣称需求完成。

### REQ-0002-012 近景真实路人模型替换（新增，见 ECN-0011）

**动机**：如果 `Tier2 + Tier3` 的 pedestrian 长期仍是盒子/竖棍占位，那么即便 crowd 行为和预算已经成立，玩家看到的也仍然是“抽象标记在移动”，而不是可信的街头行人。

**范围**：

- 用户提供的 civilian `glb` 必须归档到项目内正式资产目录，并具有稳定、可引用的 manifest
- manifest 必须为每个模型显式记录逐模型归一化口径，至少包括 `source_height_m` 与 `source_ground_offset_m`，使不同 `glb` 能统一映射到 pedestrian `height_m` / 贴地契约；其中 `source_height_m` 必须按 locomotion clip 启动后的 live skeleton 高度标定，不能直接信任原始 `MeshInstance` AABB
- `Tier2 + Tier3` 必须从当前 `BoxMesh` 占位切换到真实 civilian character model
- ambient locomotion 至少要能播放 `walk` 动画；`panic / flee` 优先播放 `run` 或等价加速 locomotion 动画
- 已被 projectile / explosion 判定为死亡的近景 pedestrian，如模型自带 `death/dead` clip，必须通过短暂的 death visual 播放该动画，而不是继续保持“命中即消失”的抽象切除
- `Tier1` 本轮继续保持轻量 batched representation；除非另开 ECN，不在本需求里重写远景 crowd 表示层

**非目标**：

- 不做 `Tier1` 全动画骨骼 crowd
- 不做完整动画状态机、IK、ragdoll 或复杂 blend tree
- 不做重新设计 pedestrian archetype 行为层；本需求只负责近景视觉替换

**验收口径**：

- 自动化测试至少断言：civilian model 资产不再散落在仓库根目录，而是统一归档到项目内 pedestrian asset 目录；manifest 覆盖全部导入模型、对应 `walk / run / death` 动画名，以及逐模型 `source_height_m / source_ground_offset_m` 归一化字段。
- 自动化测试至少断言：`Tier2 + Tier3` 不再创建当前 `BoxMesh` 占位 pedestrian，而是实例化真实 model scene，并可访问 `AnimationPlayer` 或等价动画入口。
- 自动化测试至少断言：ambient pedestrian 至少播放 `walk` 动画；`panic / flee` 至少播放 `run` 或等价加速 locomotion 动画；已死亡的近景 pedestrian 如存在 `death/dead` clip，则必须播放 transient death visual。
- 自动化测试至少断言：`Tier1` 继续保持轻量批渲染或等价低成本表示，不因本轮近景视觉替换而升级成高成本骨骼实例海。
- fresh isolated `tests/e2e/test_city_pedestrian_performance_profile.gd` 与 `tests/e2e/test_city_runtime_performance_profile.gd` 必须继续 `PASS`，且 `wall_frame_avg_usec <= 16667`。
- 反作弊条款：不得通过“只给单个 demo ped 换模型”“保留盒子但改材质”“只在测试场景手工摆真实模型”或“击杀后直接瞬移删除近景行人”来宣称需求完成。

### REQ-0002-013 近景模型尺度校准与归一化鲁棒性（新增，见 ECN-0012）

**动机**：`M8` 已把近景 civilian `glb` 接进运行期，但手玩反馈继续暴露出两类产品级差异：一是至少有一个模型会被放大成“女巨人”，二是其余模型虽然按现有公式归一化了，体感上仍明显小于 player 圆柱参考体。说明当前 `source_height_m -> pedestrian height_m` 的单一路径还不够，既没有挡住 manifest 中的异常量纲，也没有把“视觉上该有多大”锚到玩家实际参考体上。

**范围**：

- 近景 civilian manifest 必须对每个模型建立更鲁棒的尺度合同，至少能区分“正常原始高度”与“导入/根节点缩放异常导致的离群值”；`source_height_m` 必须以 live skeleton 高度而非静态 mesh AABB 为准
- 近景 visual scaling 必须以 player standing cylinder / capsule 或等价运行期参考体为视觉锚点，而不是只盯着 simulation `height_m`
- 允许通过逐模型 `visual_height_scale`、`target_visual_height_m` 或等价字段做校准，但必须保持 deterministic、可测试、可追溯
- 7 个 civilian model 的最终 rendered height spread 必须收敛到合理范围，不允许再出现单模型极端放大或大面积“矮人化”

**非目标**：

- 不做儿童、老人、超大体型等有意设计的体型谱系扩展
- 不做高模换装、复杂 body-shape 自定义或完整 character creator
- 不做 foot IK、骨骼 retargeting 大重构

**验收口径**：

- 自动化测试至少断言：在平地、默认 `alive + ambient` 状态下，7 个 civilian model 的最终 live 可见全身高度都 `>= 3.0m`，并维持稳定的统一体型区间；该口径以 `2026-03-13` 的用户手玩指令为准，允许其显著高于 player 参考体。
- 自动化测试至少断言：7 个 civilian model 中“最高 / 最矮”的最终 rendered height 比值 `<= 1.25`，不允许再出现单个离群巨人。
- 自动化测试至少断言：manifest / 运行期校准链路不能再让类似 `0.053m` 这类明显离群的原始高度在未被修正的情况下直接进入最终缩放公式。
- 自动化测试至少断言：近景 visual height 校准不会破坏脚底贴地契约，`source_ground_offset_m` 或等价字段仍然成立。
- 反作弊条款：不得通过单独跳过某个模型、只在测试里换参考体、把 player 圆柱临时缩小，或仅对单场景硬编码缩放来宣称需求完成。

### REQ-0002-014 暴力状态机连续性与 inspection 模式隔离（新增，见 ECN-0012）

**动机**：如果 automatic rifle 连发期间 pedestrian 会从 `run / flee` 抖回 `walk`，或者仅仅因为玩家按下 `C` 切到 inspection 模式、靠近行人就触发 `panic / flee`，那么 crowd 虽然“有状态机”，但并不可信，反而会比简单脚本更穿帮。

**范围**：

- 连续枪击、连续 casualty 与连续 explosion 构成的重叠 threat event，必须提供稳定的 violent-state hold window，不能让 ambient locomotion 提前夺回主导权
- `panic / flee`、`yield / sidestep` 与 ambient locomotion 必须有明确优先级与回落条件；回落只能发生在 threat quiet window 之后
- `C` 切出的 inspection mode 只代表玩家控制模式切换，不得被 pedestrian runtime 误识别为 violent threat 或 wide-area panic trigger
- inspection mode 下真实 gunfire / explosion / casualty 仍必须维持与普通 player mode 相同的 threat broadcast 能力，不能因为修隔离而把真威胁一起屏蔽掉

**非目标**：

- 不做完整行为树、BT/GOAP、社交记忆或长期仇恨系统
- 不做 civilian 反击、求援或掩体搜索
- 不把所有近场反应都升级成常驻 Tier 3 高成本 agent

**验收口径**：

- 自动化测试至少断言：automatic rifle 或等价 burst fire 持续 `0.5s` 以上时，位于 threat/witness 半径内的存活 pedestrian 在 quiet window 结束前不得出现 `run -> walk -> run` 的抖动回退。
- 自动化测试至少断言：同一名 witness 在连续 violent event 重叠期间，`reaction_state` 只能保持或升级，不得在仍有 threat 输入时提前清空回 ambient。
- 自动化测试至少断言：inspection mode + 仅靠近玩家时，pedestrian 最多进入 `yield / sidestep`，不得误切到 `panic / flee`。
- 自动化测试至少断言：inspection mode 下真实开枪 / 爆炸 / casualty 仍会正常触发 `panic / flee`，不得因为隔离 `C` 而屏蔽真实 threat。
- 反作弊条款：不得通过简单延长所有 animation timer、把 inspection mode 完全禁用 pedestrian reaction、或把 `panic/flee` 全局改成 `yield` 来宣称需求完成。

### REQ-0002-015 死亡动画可见性与延迟移除合同（新增，见 ECN-0012）

**动机**：如果 casualty 在某些路径上仍会“命中即无”，而不是留下可见的 `death/dead` 动画窗口，那么 `M8` 的真实模型和 death clip 接入就只是在理想路径上成立，实际手玩里仍然会被 tier 移除、chunk 回访或状态切换吃掉。

**范围**：

- death visual 必须从 live crowd roster / tier membership 的即时移除时序中解耦，成为独立、短生命周期但稳定可见的 transient visual contract
- projectile kill、burst fire casualty、explosion casualty、tier demotion、chunk 边界回访等路径都必须复用同一套 death visual 生命周期，而不是各自藏不同删节点时序
- 如模型存在 `death/dead` clip，runtime 必须优先播放该 clip；如不存在，才允许走显式 fallback
- death visual 的可见时长必须有明确最短窗口，不能因为同帧 snapshot rebuild 或 chunk remount 被提前抹掉

**非目标**：

- 不做 ragdoll、持久尸体、loot corpse 或长期尸体堆积系统
- 不做复杂受击 blend tree、倒地方向校正或命中部位特化
- 不把 death visual 扩展成新的常驻 AI agent

**验收口径**：

- 自动化测试至少断言：凡是模型提供 `death/dead` clip 的 casualty 路径，在命中后都必须留下至少 `0.75s` 的可见 death visual 窗口，而不是同帧消失。
- 自动化测试至少断言：Tier 2、Tier 3、chunk remount / demotion 路径下的 casualty 都会稳定进入同一 death visual 合同，不允许某些路径继续“命中即无”。
- 自动化测试至少断言：death visual 播放期间，live crowd roster 可被移除，但视觉节点不得被重复 mount/update 逻辑提前清空。
- 自动化测试至少断言：death visual 生命周期结束后会自动释放，不引入新的长驻节点泄漏。
- 反作弊条款：不得通过延迟真正死亡判定、假装目标仍存活、或只在单测场景手工保留一个假 death node 来宣称需求完成。

### REQ-0002-016 Lite 模式下的人流数量级抬升（新增，见 ECN-0012）

**动机**：`M7` 的密度 uplift 虽然把系统从 `M6` 的稀疏基线拉起来了，但最新手玩反馈仍然认为“这个城市简直空旷无比”。既然用户明确要求至少 `10x` 的人口存在感，就不能再把 `54 / 60` 级别的 Tier 1 可见人数当作收口标准。

**范围**：

- 默认 `pedestrian_mode = lite` 的 deterministic spawn / occupancy contract 必须再上一个数量级，优先扩容 `Tier0 + Tier1` 的低成本存在感，而不是继续先抬 Tier 2 / Tier 3 hard cap
- district / road class 的层次差异必须保留，不能通过把全城抹平成同一密度来伪造“人多了”
- 如现有 per-chunk slot contract 无法承载 `10x` 目标，必须重构 query / spawn-slot / low-cost render 表达；不允许自行打折到“小幅增加”
- 所有人流提升都必须继续服从 streaming continuity、identity continuity 与 `16.67ms/frame` 红线

**非目标**：

- 不做 `full` crowd 模式
- 不做把 Tier 2 / Tier 3 海量骨骼实例硬堆到全城
- 不做用纯静态假人、重复 billboard 或关闭 continuity 的方式伪造“有人”

**验收口径**：

- 自动化测试至少断言：以 `2026-03-13` 的 `M8` 基线为参照，默认 `lite` 下 warm traversal 的 `tier1_count` 至少达到 `540`，first-visit traversal 的 `tier1_count` 至少达到 `600`。
- 自动化测试至少断言：达到上述 `10x` 量级 uplift 后，district / road class 的密度排序仍保持 `core > mixed > residential > industrial > periphery` 与 `arterial > secondary > collector > local > expressway_elevated`。
- 自动化测试至少断言：M9 仍然不通过继续抬高 `tier2_budget` / `tier3_budget` 作为主要解法；除非另开 ECN，否则其 hard cap 继续维持当前口径。
- fresh isolated `tests/e2e/test_city_pedestrian_performance_profile.gd` 与 `tests/e2e/test_city_runtime_performance_profile.gd` 必须继续 `PASS`，且 `wall_frame_avg_usec <= 16667`。
- [已由 ECN-0013 补充] 如现有 runtime 无法同时承载本条与 `REQ-0002-007`，必须升级 crowd runtime 架构；不得通过把 `max_spawn_slots_per_chunk`、`lane_slot_budget` 或等价密度参数回退到 `54 / 60` 级别的旧基线来伪造“性能恢复”。
- 反作弊条款：不得通过只改测试阈值、只改 debug 路线、把大量 pedestrian 塞进不可见 tier、临时关闭真实 visual/update 成本，或维持“密度和红线不能同时成立”的双配置分裂状态来宣称需求完成。

## Open Questions

- `M7` 已把默认 `lite` density uplift 列为正式需求并完成第一轮收口；当前默认 crowd baseline 已不再沿用 M6 的偏稀疏口径，但 district class 之间的最终差异系数仍可继续通过 profiling 与手玩反馈微调。
- 是否需要在 `v6` 预留“路边等待点 / 斑马线信号相位”字段，目前看建议预留数据槽位，但不把完整信号系统纳入范围。

这些问题当前不阻塞 `v6` 开工，暂不单独开 ECN。
