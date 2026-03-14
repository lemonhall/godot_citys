# PRD-0003 Vehicle Traffic Foundation

## Vision

把 `godot_citys` 从“道路语义和行人底盘已经成立、但机动车仍完全缺席”的状态，推进到“在不打穿 `60 FPS = 16.67ms/frame` 红线的前提下，城市主干道、次干道和部分本地道路出现可信的 ambient traffic”的状态。成功标准不是第一轮就做出 GTA 级交通系统，而是让玩家在多个 district 穿行时，能够看到与道路等级、交叉口拓扑和世界密度一致的车辆流动；这些车辆必须服从 deterministic query、chunk streaming、runtime budget 和 profile guard，而不是靠散落的手工摆件或海量节点假装“有车了”。

本 PRD 的目标用户仍然是项目开发者本人及后续协作 agent。核心价值不是先做玩家驾驶玩法，而是为未来的交通标识、车辆玩法、事故/犯罪系统和更丰富的人车互动打一套不会轻易返工的 traffic 底盘。

## Background

- `PRD-0001` 已经完成大世界、shared `road_graph`、chunk streaming、terrain/page cache 和 `v7` 的道路语义 contract。
- `PRD-0002` 已经把 pedestrian crowd 做成 `query + layered runtime + renderer + profile guard` 的结构，并在 `ECN-0015` 中明确把人口目标改成 vehicle-aware 口径，为车辆系统保留预算空间。
- `v7` 已将 `section_semantics`、`intersection_type`、`ordered_branches`、`branch_connection_semantics` 上游化，但这些 richer contracts 目前还没有正式落到车辆系统 consumer。
- 2026-03-14 新增的 8 个车辆 `glb` 已经被归档到 `city_game/assets/vehicles/`，并建立了尺度 manifest；说明素材基础已经具备，但运行期系统仍不存在。

## Scope

本 PRD 只覆盖 `ambient traffic foundation v8`。

包含：

- 车辆 `glb` 资产归档、稳定命名、manifest 与现实尺度基线
- 从 shared `road_graph`、`section_semantics`、`intersection topology` 派生的 vehicle lane / turn query
- deterministic 的 vehicle density profile、spawn slot 与 roster signature
- Tier 0-3 的分层交通表示、streaming-aware spawn / despawn / cache
- 基于道路语义的基础跟车、基础 stop / yield、基础交叉口转向
- 与行人系统的最小必要耦合：crossing candidate 上的人车冲突让行护栏
- traffic debug overlay、profile breakdown、runtime node budget guard
- 在默认 `vehicle_mode = lite` 下与现有 crowd / road / terrain 同时守住 `16.67ms/frame`

不包含：

- 玩家驾驶、载具物理、轮胎抓地、漂移、碰撞破坏
- 全城交通信号灯相位系统、停车场系统、泊车、开关车门
- wanted、police chase、事故调查、保险、商业物流经济
- 复杂 lane change 策略、超车博弈、事故避障、紧急车辆全图优先权
- 把所有车辆都做成全时刚体或全时 `CharacterBody3D`

## Non-Goals

- 不追求 `v8` 阶段就做成完整车辆玩法版本
- 不追求所有可见车辆都具备近景物理和高级 AI
- 不追求第一轮就做 traffic signal、停车、鸣笛、事故链、警察执法全套
- 不追求通过“把现有系统关掉一些”给车辆让路

## Requirements

### REQ-0003-001 车辆资产归档与尺寸归一化

**动机**：如果车辆素材继续散落在仓库根目录，且没有统一 manifest、稳定命名和现实尺度口径，后续 visual catalog、runtime scale、profiling 和测试都会失去锚点。

**范围**：

- 把车辆 `glb` 统一归档到项目内正式 asset 目录
- 为每个模型建立 manifest 条目，至少记录 `source_dimensions_m`、`source_ground_offset_m`、`target_length_m`、`runtime_uniform_scale`
- 区分 `civilian / service / commercial` 三类车辆来源

**非目标**：

- 不做完整材质重制、LOD 烘焙或碰撞网格手修
- 不做车辆骨骼、车轮旋转或车门动画

**验收口径**：

- 自动化测试至少断言：仓库根目录不再存在车辆 `glb` 素材；全部模型已归档到正式资产目录，并被 manifest 全覆盖。
- 自动化测试至少断言：manifest 对 8 个模型全部显式记录 `source_dimensions_m`、`source_ground_offset_m`、`target_length_m` 与稳定 `model_id`。
- 反作弊条款：不得通过“只在文档里写目标尺寸”“只归档一部分模型”或“把素材藏进临时目录但不建 manifest”来宣称完成。

### REQ-0003-002 行车世界配置与确定性分布

**动机**：没有统一的 vehicle config、density profile 与 spawn seed，车辆会像旧时代随机道路一样出现 run-to-run 漂移和 chunk 边界断裂。

**范围**：

- 提供统一的 vehicle world config
- 定义 district / road class 到 traffic density 的映射
- 定义 `chunk -> lane -> spawn_slot` 的 deterministic seed 派生规则
- 提供不依赖场景实例化的 `vehicle_query` API

**非目标**：

- 不做动态天气/时段车流调度
- 不做可编辑 traffic density UI

**验收口径**：

- 固定 world seed 下，连续两次运行得到完全相同的 `lane_ids`、`spawn_slot_ids`、density bucket 与 roster signature。
- 自动化测试至少断言：`vehicle_query` 返回的 road-class density 排序稳定，且 `expressway_elevated >= arterial >= local >= service`。
- 反作弊条款：不得通过每次运行临时随机发牌、或只在测试里硬编码少量车辆点位来冒充 deterministic query。

### REQ-0003-003 从 shared road semantics 派生的 vehicle lane / turn graph

**动机**：如果车辆 lane / turn 关系不是从 shared `road_graph` 语义 contract 派生，而是回到 chunk 几何现场临时猜，就会重复道路系统已经吃过的断裂和猜测逻辑。

**范围**：

- 从 `section_semantics.lane_schema` 派生 drivable lane
- 从 `intersection_type`、`ordered_branches`、`branch_connection_semantics` 派生 turn links
- 支持按 chunk / rect 查询 drivable lane 子图与交叉口 turn contract

**非目标**：

- 不做编辑器级人工车道绘制
- 不做全城一张巨型 navmesh

**验收口径**：

- 自动化测试至少断言：主干道、次干道与本地道路都能从 shared road semantics 派生 drivable lane，而不是只剩 section 中线。
- 自动化测试至少断言：交叉口至少暴露 `straight / left_turn / right_turn / u_turn` 这一级合法 turn contract。
- 自动化测试至少断言：vehicle lane graph 在 chunk 边界连续，spawn anchor 不落到 sidewalk / crossing lane 上。
- 反作弊条款：不得保留“按 chunk 现场临时拉几条 spline”作为主要车辆路径来源。

### REQ-0003-004 分层车辆表示与 continuity

**动机**：如果所有车辆都常驻高成本节点或刚体，系统会比行人更快打穿红线；但如果只有 billboard 占位，又无法形成可信交通观感。

**范围**：

- 建立 Tier 0-3 的车辆分层表示：
  - Tier 0：occupancy / reservation / route intent
  - Tier 1：中远景 batched ambient traffic
  - Tier 2：近景 lightweight kinematic vehicles
  - Tier 3：近场 conflict-aware vehicles
- tier 切换保持 `vehicle_id`、route signature 与 archetype continuity

**非目标**：

- 不做所有 tier 的轮胎物理或悬挂
- 不做所有 tier 的完整碰撞体

**验收口径**：

- 默认 `vehicle_mode = lite` 下，Tier 1 可见车辆总数不得超过 `160`，Tier 2 不得超过 `48`，Tier 3 不得超过 `12`。
- 自动化测试至少断言：同一车辆在 tier 升降级前后的 `vehicle_id` 与 route signature 保持一致。
- 自动化测试至少断言：Tier 1 使用 `MultiMesh` 或等价 batched representation，而不是把每台车都实例化为独立复杂节点树。
- 反作弊条款：不得通过把 traffic density 直接设为 `0`、或让 Tier 1 只渲染不可辨认空壳来宣称完成。

### REQ-0003-005 Streaming-aware spawn / despawn 与预算约束

**动机**：大世界车辆系统的关键不是总车数，而是“当前窗口内高成本集合始终可控，并且跨 chunk 不重掷不泄漏”。

**范围**：

- 车辆系统必须对齐现有 `5x5` active chunk window
- 提供 cold / warm / active 的交通页缓存或等价复用机制
- 支持玩家跨 chunk 移动时的稳定 promotion / demotion / despawn

**非目标**：

- 不做全城实时常驻 vehicle AI
- 不做多人同步

**验收口径**：

- 任意时刻 Tier 2 + Tier 3 的总量不得突破配置上限。
- 玩家跨越至少 `8` 个 chunk 的 travel 测试中，不允许出现 traffic count leak、重复加载同一 vehicle page 或明显的 spawn storm。
- 自动化测试至少断言：回访已访问区域时存在 traffic query / lane page cache hit 或等价复用证据。
- 反作弊条款：不得通过“离开一个 chunk 就把全部车清零、回到原地再全部重掷”来伪造 streaming。

### REQ-0003-006 基础交叉口行为与跟车间距

**动机**：只有车辆会动但没有基本头距和交叉口秩序，城市会立刻出现穿帮的追尾、逆行和路口乱串。

**范围**：

- 基础 headway / spacing contract
- 基础 stop / yield / go 逻辑
- 基于 `branch_connection_semantics` 的 turn choice 与 turn execution

**非目标**：

- 不做完整红绿灯相位系统
- 不做高级变道、超车和事故绕行

**验收口径**：

- 自动化测试至少断言：同一 lane 上的车辆保持最小头距，不发生持续重叠穿模。
- 自动化测试至少断言：车辆不会逆向进入与自己 `direction_mode` 冲突的车道。
- 自动化测试至少断言：交叉口车辆可完成 `straight / left_turn / right_turn` 三类基础通行，不需要退回几何猜测。
- 反作弊条款：不得通过把车辆在接近路口时直接瞬移到下一段、或让同 lane 车辆相互穿透来宣称完成。

### REQ-0003-007 行人与车辆的最小必要冲突护栏

**动机**：城市里一旦有车，行人系统就不再是孤立背景层；至少在 crossing candidate 附近必须有人车关系，否则世界会出现“行人和车各跑各的”。

**范围**：

- nearfield 车辆对 occupied crossing candidate 做 stop / yield
- 继续保证 pedestrian spawn / travel 不长在 drivable lane 内
- 保持人车耦合只发生在必要窗口，不把所有 traffic 都升级成高成本 negotiation

**非目标**：

- 不做完整人车博弈、碰撞伤害或交通事故系统
- 不做警察执法、鸣笛驱赶、路怒事件

**验收口径**：

- 自动化测试至少断言：crossing candidate 被行人占用时，nearfield 车辆会减速并停让，而不是直接穿过。
- 自动化测试至少断言：traffic 引入后，pedestrian spawn / lane graph 仍不落在机动车 drivable lane 内。
- 自动化测试至少断言：人车 conflict 处理不会让 Tier 3 车辆数量失控膨胀。
- 反作弊条款：不得通过全局冻结车辆、全局冻结行人、或直接隐藏冲突对象来宣称完成人车耦合。

### REQ-0003-008 运行时观测、调试与 profiling

**动机**：没有 traffic debug overlay 和 breakdown 指标，就无法判断“为什么路上没车”“为什么路口堵死”“为什么 frame time 被 traffic 吃掉了”。

**范围**：

- 提供 traffic 相关 debug overlay / profile 字段
- 暴露各 tier 计数、lane page/cache 命中、intersection queue、traffic update / spawn / render commit usec
- minimap 至少支持 traffic debug layer 或交通 density markers

**非目标**：

- 不做最终用户地图 UI
- 不做复杂交通录播分析器

**验收口径**：

- 自动化测试至少断言：profile 输出中存在 `veh_tier1_count`、`veh_tier2_count`、`veh_tier3_count`、`traffic_update_avg_usec`、`traffic_spawn_avg_usec`、`traffic_render_commit_avg_usec`。
- 自动化测试至少断言：profile 输出中还存在至少一个 queue/cache 指标，例如 `traffic_lane_page_hit_count` 或 `traffic_intersection_wait_count`。
- 自动化测试至少断言：minimap traffic debug layer 使用与 3D traffic 同源的 lane / density 数据，而不是另一套随机示意图。
- 反作弊条款：不得只在文档中写预算数字而没有实际运行时输出。

### REQ-0003-009 Traffic 红线与端到端验证

**动机**：车辆系统如果只看“路上终于有车”，不把同配置红线写死，就会立刻吞掉 `v6` 和 `v7` 刚守住的预算。

**范围**：

- 默认 `vehicle_mode = lite`
- 每个里程碑都必须重新跑 fresh profiling
- 扩展 world / e2e 验证，覆盖“有人、有车”的真实链路

**非目标**：

- 不要求第一轮就交付 `full` traffic 模式
- 不要求本阶段下沉到 C++ / GDExtension

**验收口径**：

- 默认 `vehicle_mode = lite` 且保持现有 pedestrian runtime 打开时，fresh warm / first-visit traversal 的 `wall_frame_avg_usec` 都必须 `<= 16667`。
- 自动化 profiling 至少断言：默认 `vehicle_mode = lite` 下，world contract warm / first-visit `veh_tier1_count >= 64`，isolated e2e runtime warm / first-visit `veh_tier1_count >= 48`。
- 自动化 profiling 输出必须新增 `traffic_update_avg_usec`、`traffic_spawn_avg_usec`、`traffic_render_commit_avg_usec` 与各 tier 计数。
- 反作弊条款：不得通过 profiling 时临时关闭 pedestrians、关闭 vehicles、把 traffic density 改成 `0` 或只在空场景跑 profile 来宣称达标。

## Open Questions

- `v8` 是否需要在第一轮就预留 traffic signal phase 数据槽位。当前建议：预留字段，但不把完整信号系统纳入 `v8` 范围。
- `service/commercial` 车辆是否默认参与 ambient traffic。当前建议：警车默认不参与普通 civilian density，货车低频参与 industrial / arterial 流量。

这些问题当前不阻塞 `v8` 立项，若实现阶段发现 scope 需要调整，应走 ECN。
