# PRD-0001 Large City Foundation

## Vision

把 `godot_citys` 从“一个可运行的小型 3D 城市原型”推进到“可承载 `70km x 70km` 城市骨架的底盘”。成功的标准不是单纯把地图地板做大，而是让项目具备稳定的世界数据模型、分块流式加载、分块渲染降级、连续可 traversable 的 chunk 地表、分块导航、稳定的运行时证据输出和开发态巡检能力，使后续的车辆、NPC、任务、存档和 AI 系统都能建立在同一套世界基础设施之上。

本 PRD 对应的目标用户是项目开发者本人和后续协作 agent。核心价值不是立即交付完整玩法，而是先建立一套不需要返工的大城市场景底座。

## Background

- v1 已完成可运行的 `CityPrototype.tscn` 和基础 smoke test。
- 研究结论见 `docs/research/2026-03-11-large-city-procgen-research.md`。
- 架构决策见 `docs/plans/2026-03-11-large-city-architecture-design.md`。

## Scope

本 PRD 只覆盖“大体量城市基础设施 v2”。

包含：

- 确定性世界坐标与城市数据模型
- `70km x 70km` 级城市骨架生成（[已由 ECN-0001 变更](../ecn/ECN-0001-large-city-scale-and-inspection.md)）
- `256m x 256m` chunk 流式加载底盘
- chunk-local 实例化渲染、远景代理、遮挡体和占位地表碰撞壳（[已由 ECN-0001 变更](../ecn/ECN-0001-large-city-scale-and-inspection.md)）
- 低成本天空氛围、同轮廓 LOD 与确定性视觉变体（[已由 ECN-0003 变更](../ecn/ECN-0003-visual-continuity-and-atmosphere.md)）
- world-space 连续道路骨架、轻量地形高差与近景建筑碰撞（[已由 ECN-0004 变更](../ecn/ECN-0004-road-network-terrain-and-collision.md)）
- 更自然的本地道路场、道路缓冲区避让、多 archetype 占位建筑、折叠巡检 UI 与少量桥梁占位（[已由 ECN-0005 变更](../ecn/ECN-0005-organic-road-density-and-inspection-ui.md)）
- 参考式连续道路图、共享 2D 城市投影、小地图与导航路径可视化（[已由 ECN-0006 变更](../ecn/ECN-0006-reference-roadgraph-and-minimap.md)）
- 多中心城市总体形态、卫星城连接干道、沿街建筑布局与 deterministic overview PNG 验收输出（[已由 ECN-0019 变更](../ecn/ECN-0019-city-morphology-and-png-acceptance.md)）
- 面向 `60 FPS = 16.67ms/frame` 红线的道路表面性能专项：缓存、分层、异步准备与 surface page 架构预留（[已由 ECN-0007 变更](../ecn/ECN-0007-performance-redline-and-road-surface-pipeline.md)）
- 面向 `60 FPS = 16.67ms/frame` 红线的 terrain streaming 性能专项：共享规则网格、height/normal page cache、异步准备与 terrain LOD/clipmap-lite 预留（[已由 ECN-0008 变更](../ecn/ECN-0008-terrain-streaming-performance-pipeline.md)）
- 道路语义契约与交叉口拓扑：为 shared road graph、chunk 渲染、lane graph 和后续 signage / vehicle 系统提供同源 section / lane / intersection metadata，且不得退回 per-road runtime node graph（[已由 ECN-0018 变更](../ecn/ECN-0018-road-semantic-runtime-uplift.md)）
- chunk-local 导航与跨 chunk 自动化 travel 流程验证
- 性能与 streaming debug 观测面板
- 开发态高速巡检模式与稳定运行时报告（[已由 ECN-0001 变更](../ecn/ECN-0001-large-city-scale-and-inspection.md)，[已由 ECN-0002 变更](../ecn/ECN-0002-fast-inspection-mode.md)）

不包含：

- 车辆交通仿真
- 行人社会模拟和群体行为
- 商店、任务、战斗、警察系统
- 多层立交、地铁、室内空间
- 双精度 Godot 引擎或 origin shifting

## Non-Goals

- 不追求 v2 阶段的美术完成度
- 不追求“整城所有细节同屏常驻”
- 不追求一次性做完城市最终玩法
- 高速巡检模式不等于交通仿真系统；v2 仍不包含真实车辆 AI、交通规则或碰撞博弈

## Requirements

### REQ-0001-001 世界尺度与确定性种子

**动机**：没有统一的世界尺度、坐标约定和随机种子，后续 chunk、导航、存档和回放都会失去稳定锚点。

**范围**：

- 提供统一的城市世界配置对象
- 定义 `70km x 70km` 城市边界（[已由 ECN-0001 变更](../ecn/ECN-0001-large-city-scale-and-inspection.md)）
- 定义 `256m x 256m` chunk 尺寸
- 定义世界 seed 到 district / chunk / parcel 的确定性派生规则

**非目标**：

- 不做多地图切换
- 不做用户可编辑世界种子 UI

**验收口径**：

- 给定固定 seed，连续两次运行生成的 district / chunk 标识、边界和核心统计完全一致。
- 自动化测试至少断言一个固定 seed 的世界尺寸为 `70000m x 70000m`，主 chunk 尺寸为 `256m x 256m`，chunk 网格数量与配置一致。

### REQ-0001-002 数据先行的城市骨架生成

**动机**：如果没有“数据城市”，运行时只能不断往场景树里堆节点，无法支撑大体量扩展。

**范围**：

- 生成 district graph
- 生成参考式全局 continuous road graph，并为 chunk 渲染、2D 城市投影与道路语义查询同时提供可查询的 world-space 连续道路骨架（[已由 ECN-0004 变更](../ecn/ECN-0004-road-network-terrain-and-collision.md)，[已由 ECN-0005 变更](../ecn/ECN-0005-organic-road-density-and-inspection-ui.md)，[已由 ECN-0006 变更](../ecn/ECN-0006-reference-roadgraph-and-minimap.md)，[已由 ECN-0018 变更](../ecn/ECN-0018-road-semantic-runtime-uplift.md)，[已由 ECN-0019 变更](../ecn/ECN-0019-city-morphology-and-png-acceptance.md)）
- 提供 block / parcel 的确定性、按 chunk 查询的元数据接口（[已由 ECN-0001 变更](../ecn/ECN-0001-large-city-scale-and-inspection.md)）
- 允许 chunk 在没有高模资源时先用占位表现

**非目标**：

- 不做最终建筑立面库
- 不做城市美术风格编辑器

**验收口径**：

- 世界生成 API 能在不实例化整座城市场景节点的前提下，返回完整 district / road 图，以及可按 chunk 查询的 block / parcel 元数据契约。
- 自动化测试至少断言生成结果包含非空 district graph、完整道路边集合、完整 block / parcel 统计，以及 `get_blocks_for_chunk()` 这类惰性查询接口。
- 自动化测试至少断言道路图存在非正交连续段、局部吸附/切分后形成真实交叉连接，而不是仅由规则 district 边与每 chunk 本地补路拼接得出。（[已由 ECN-0006 变更](../ecn/ECN-0006-reference-roadgraph-and-minimap.md)）
- 自动化测试至少断言：整城道路图表现出“主城区 + 卫星城 + 连接干道”的多中心形态，且 edge count 明显低于 full-world district lattice 基线；`district graph` 可以存在，但不得继续作为正式可见道路主骨架。（[已由 ECN-0019 变更](../ecn/ECN-0019-city-morphology-and-png-acceptance.md)）
- 反作弊条款：任何验收都不得仅靠扩大 `CityPrototype.tscn` 中的静态几何来宣称“城市已扩容”。

### REQ-0001-003 受边界约束的 chunk streaming

**动机**：大城市的关键不是地图总面积，而是高成本活跃区必须有上限。

**范围**：

- 基于玩家或开发态高速巡检模式下的玩家位置决定进入/退出的 chunk（[已由 ECN-0001 变更](../ecn/ECN-0001-large-city-scale-and-inspection.md)，[已由 ECN-0002 变更](../ecn/ECN-0002-fast-inspection-mode.md)）
- 高成本活跃窗口固定为玩家周围 `5x5` chunk
- chunk 准备流程支持后台数据准备与主线程挂载
- 静态道路表面数据必须支持可缓存或可复用的准备路径，避免已访问 chunk 在主线程重复全量生成（[已由 ECN-0007 变更](../ecn/ECN-0007-performance-redline-and-road-surface-pipeline.md)）
- 地形高度页、法线页和地形网格数据必须支持 page 级缓存或等价复用路径，避免已访问区域在主线程重复全量采样/重建（[已由 ECN-0008 变更](../ecn/ECN-0008-terrain-streaming-performance-pipeline.md)）
- 提供 warm / cold 元数据层，避免所有内容都被卸空

**非目标**：

- 不做网络同步
- 不做多人世界同步

**验收口径**：

- 任意时刻高成本活跃 chunk 数量不得超过 25。
- 玩家在普通或高速巡检模式下跨越至少 8 个 chunk 的自动化 travel 测试过程中，不允许出现空引用、重复加载同一 chunk ID 或活跃 chunk 上限失控。
- 反作弊条款：不得通过“只加载 1 个 chunk 且禁用移动”来满足上限要求。

### REQ-0001-004 分块渲染降级与实例化

**动机**：几十平方公里级城市的可见内容如果不用实例化和分级可见性，渲染成本会先于世界逻辑崩溃。

**范围**：

- 重复性 props 使用 chunk-local `MultiMeshInstance3D`
- chunk 支持近景实体、中景合批、远景代理
- near / mid / far 必须从同一份 chunk visual profile 派生，保持主轮廓连续（[已由 ECN-0003 变更](../ecn/ECN-0003-visual-continuity-and-atmosphere.md)）
- 邻近 chunk 必须基于 chunk seed 生成确定性视觉变体，避免近景重复（[已由 ECN-0003 变更](../ecn/ECN-0003-visual-continuity-and-atmosphere.md)）
- chunk 可见道路必须由整城 road skeleton 与同源 road semantic contract 驱动，并在 chunk 共享边界上连续衔接，不能出现孤路或断路（[已由 ECN-0004 变更](../ecn/ECN-0004-road-network-terrain-and-collision.md)，[已由 ECN-0018 变更](../ecn/ECN-0018-road-semantic-runtime-uplift.md)）
- chunk 路面必须使用连续 ribbon/strip mesh 或等价连续表面，而不是显著可见的分段盒子拼接（[已由 ECN-0005 变更](../ecn/ECN-0005-organic-road-density-and-inspection-ui.md)）
- 普通地面道路表面必须支持基于距离的细节分层，以及缓存/异步准备的性能化管线，避免每次 chunk mount 在主线程全量重建 surface mask（[已由 ECN-0007 变更](../ecn/ECN-0007-performance-redline-and-road-surface-pipeline.md)）
- chunk ground 几何必须优先复用共享规则网格模板或等价数组契约，并将高度采样限制在唯一顶点级别，不能在 mount 热路径按三角形重复采样同一高度点（[已由 ECN-0008 变更](../ecn/ECN-0008-terrain-streaming-performance-pipeline.md)）
- chunk ground 必须支持 near / mid / far 分辨率差异或等价 terrain LOD/clipmap-lite 机制，在保证轮廓与边界连续的前提下降低远景地形成本（[已由 ECN-0008 变更](../ecn/ECN-0008-terrain-streaming-performance-pipeline.md)）
- chunk ground、道路 y 值和建筑基座必须共享同一套连续高度采样，避免整城纯平面（[已由 ECN-0004 变更](../ecn/ECN-0004-road-network-terrain-and-collision.md)）
- 近景建筑必须提供可启停碰撞壳；mid/far LOD 不得保留不可见碰撞（[已由 ECN-0004 变更](../ecn/ECN-0004-road-network-terrain-and-collision.md)）
- 建筑与 roadside props 都必须满足道路缓冲区避让，不得长在路面上；chunk 建筑体量需要达到更高密度并提供多 archetype 变体（[已由 ECN-0005 变更](../ecn/ECN-0005-organic-road-density-and-inspection-ui.md)）
- chunk 建筑布局必须以沿街 frontage / streetfront candidate 为正式上游，而不是继续以 chunk-local 均匀候选格点为主、只把离路远近当作评分项。（[已由 ECN-0019 变更](../ecn/ECN-0019-city-morphology-and-png-acceptance.md)）
- 在 `v13` 当前阶段，`no-road chunk` 不得再生成 fallback building；无路区建筑/山地木屋等属于后续版本能力。（[已由 ECN-0019 变更](../ecn/ECN-0019-city-morphology-and-png-acceptance.md)）
- block 自动生成基础遮挡体或 `ArrayOccluder3D`
- chunk 必须提供占位地表与碰撞壳，保证离开中心原型区后仍可连续步行/高速巡检（[已由 ECN-0001 变更](../ecn/ECN-0001-large-city-scale-and-inspection.md)，[已由 ECN-0002 变更](../ecn/ECN-0002-fast-inspection-mode.md)）
- `WorldEnvironment` 必须提供低成本 sky/fog 氛围，避免城市漂浮在单色背景前（[已由 ECN-0003 变更](../ecn/ECN-0003-visual-continuity-and-atmosphere.md)）
- 地形高差应达到人工巡检可感知的坡度级别，并允许少量 arterial bridge / overpass 占位打破纯平体验（[已由 ECN-0005 变更](../ecn/ECN-0005-organic-road-density-and-inspection-ui.md)）
- 提供 debug 统计，显示每个 chunk 的实例数与降级状态

**非目标**：

- 不做最终材质和美术打光
- 不做 Nanite 类超细节远景

**验收口径**：

- 至少一种重复类资产必须通过 `MultiMeshInstance3D` 渲染，而不是逐个 `MeshInstance3D`。
- 自动化测试和 debug 证据必须能证明近/中/远至少三档表现存在。
- 自动化测试至少断言：mid/far 代理保留与 near 一致的主轮廓签名，不能用完全无关的蓝色盒子替代近景建筑。
- 自动化测试至少断言：不同 chunk 产生不同的确定性视觉变体，而同一 chunk 多次生成签名一致。
- 自动化测试至少断言：相邻 chunk 的道路连接点在共享边界上连续，且可见道路存在曲率变化，不是 per-chunk 随机孤路。
- 自动化测试至少断言：chunk 道路包含显著非正交方向，并使用连续路面表达，而不是大量分段盒子贴片。
- 自动化测试至少断言：chunk ground 使用共享规则网格模板或等价数组契约，且同一地形 tile 的高度采样 duplication ratio 低于约定阈值。
- 自动化测试至少断言：terrain near / mid / far 至少存在两档不同分辨率或等价 LOD 表现，且跨 chunk / page 边界保持连续。
- 自动化测试至少断言：近景建筑提供可启停碰撞壳，mid/far LOD 时不可见碰撞会停用。
- 自动化测试至少断言：建筑与 roadside props 对道路保持最小缓冲区退距，且中心 chunk 建筑数量与 archetype 数量达到约定阈值。
- 自动化测试至少断言：building layout 输出正式的 streetfront / frontage 统计，且主体 building 与最近道路保持沿街关系，而不是均匀散点噪声。（[已由 ECN-0019 变更](../ecn/ECN-0019-city-morphology-and-png-acceptance.md)）
- 自动化测试至少断言：`no-road chunk => building_count == 0`，不得继续在无路区域伪造 fallback infill 建筑。（[已由 ECN-0019 变更](../ecn/ECN-0019-city-morphology-and-png-acceptance.md)）
- 自动化测试至少断言：chunk 地表存在可见高差，而不是整块纯平面。
- 自动化测试至少断言：至少存在少量桥梁/高架占位。
- 自动化测试至少断言：演员离开中心起始区后，仍能落在 streamed chunk 的占位地表上，而不是掉穿世界。
- 场景中不得再保留与 chunk 地表重叠的 legacy `Ground` 节点作为承托面。（[已由 ECN-0002 变更](../ecn/ECN-0002-fast-inspection-mode.md)）
- 反作弊条款：远景代理不得与近景使用同一份完整高细节节点树。

### REQ-0001-005 分块导航与宏观路由

**动机**：整城一张 navmesh 无法长期维持可维护性和性能。

**范围**：

- 近距离使用 chunk-local nav source / navmesh
- 远距离使用 district / road graph 宏观路由
- chunk 边界导航信息可拼接

**非目标**：

- 不做群体避障
- 不做车辆 lane-level 交通 AI

**验收口径**：

- 自动化测试至少断言：角色可从一个 chunk 进入相邻 chunk，并保持路径连续。
- 工程中不得存在“覆盖整个 `7km x 7km` 世界的一张静态 navmesh 文件”作为 v2 验收方案。

### REQ-0001-006 运行时观测与性能护栏

**动机**：没有观测面板和性能护栏，就很容易重新滑回“单场景硬撑”的假象。

**范围**：

- 提供开发态 overlay 或日志输出
- 提供默认折叠、可展开的巡检面板，整合状态与调试信息（[已由 ECN-0005 变更](../ecn/ECN-0005-organic-road-density-and-inspection-ui.md)）
- 展示玩家当前 chunk、活跃 chunk 数、最近 chunk 生成耗时、当前 chunk 的实例统计
- 展示当前 chunk 的 visual variant 标识，便于人工检查重复度（[已由 ECN-0003 变更](../ecn/ECN-0003-visual-continuity-and-atmosphere.md)）
- 为主要 E2E 测试输出稳定可解析的 debug 文本
- 为主要 E2E 测试输出稳定可解析的运行时报告，至少包含 `final_position` 与 `transition_count`（[已由 ECN-0001 变更](../ecn/ECN-0001-large-city-scale-and-inspection.md)）
- 提供 deterministic world overview evidence 输出，至少包含 PNG 与 sidecar metadata，用于人工验收整城 morphology。（[已由 ECN-0019 变更](../ecn/ECN-0019-city-morphology-and-png-acceptance.md)）
- 将 `60 FPS = 16.67ms/frame` 作为项目级性能红线，在达线前对 rendering/streaming 相关改动持续保留 profiling 证据与回归护栏（[已由 ECN-0007 变更](../ecn/ECN-0007-performance-redline-and-road-surface-pipeline.md)）
- terrain streaming 相关 profiling 必须额外输出 `ground_mesh_usec`、`terrain_prepare_usec`、`terrain_commit_usec`、`duplication_ratio` 或等价字段，避免热点迁移后观测面板失真（[已由 ECN-0008 变更](../ecn/ECN-0008-terrain-streaming-performance-pipeline.md)）

**非目标**：

- 不做最终用户设置面板
- 不做完整 profiler 替代品

**验收口径**：

- 自动化测试或脚本输出中必须能读取 `current_chunk_id`、`active_chunk_count`、至少一个 streaming 耗时指标，以及 `transition_count` / `final_position`。
- terrain profiling 自动化输出中必须能读取 `ground_mesh_usec` 与至少一个 terrain prepare/commit/cache 指标。
- world overview evidence 输出中必须能读取 `road_edge_count`、`population_center_count`、`corridor_count`、`building_footprint_count` 与 PNG 产物路径。
- 反作弊条款：不得只在文档中写目标数字而没有实际运行时输出。

### REQ-0001-010 道路表面性能红线与专项治理

**动机**：当前项目是 low poly 大世界，如果普通地面道路仍以“每个 chunk mount 现场重建表面数据”的方式存在，运行期帧耗会持续高于可接受范围，后续新功能也将建立在错误的性能底座之上。

**范围**：

- 将 `60 FPS = 16.67ms/frame` 明确为项目级性能红线；
- 对普通地面道路表面引入缓存、距离分层、异步数据准备；
- 为未来 surface page / RVT-lite / clipmap 风格的分页表面体系预留稳定 contract；
- 将 fresh profiling 结果纳入每轮性能专项的验收证据。

**非目标**：

- 不要求 v4 一次性做完完整 RVT 或 clipmap 系统；
- 不要求用 GPU 计算着色器重写全部道路表面生成；
- 不做与性能专项无关的新玩法扩展。

**验收口径**：

- fresh runtime profiling 必须持续输出 `wall_frame_avg_usec`、`update_streaming_avg_usec`、`streaming_mount_setup_avg_usec` 等核心指标；
- 已访问静态 chunk 的普通道路表面数据不得在主线程重复全量生成；
- `mid/far` 路面细节必须较 near 明显降级，但仍保留道路轮廓；
- 异步准备路径不得直接在后台线程操作 scene tree 或 GPU 资源；
- 反作弊条款：不得通过关闭普通地面道路可见性来伪造帧耗下降。

### REQ-0001-011 地形网格与页缓存性能专项

**动机**：当前 road surface pipeline 已经结构化升级，但 fresh profiling 显示 `ground_mesh` 已成为新的第一热点。如果 terrain 仍沿用 per-chunk 重复采样和热路径法线重建，项目将无法守住 `16.67ms/frame` 红线。

**范围**：

- 建立共享规则网格模板或等价数组契约，避免每个 chunk 重复构造独立三角形拓扑；
- 建立 page 级高度/法线缓存或等价共享数据页，允许相邻 chunk 复用边界采样结果；
- 将地形高度采样限制为唯一顶点级别，避免在 mount 热路径按三角形重复查询同一高度点；
- 将 terrain prepare 与 terrain commit 分离，后台线程只做数据准备，主线程只做资源提交；
- 建立 near / mid / far 地形分辨率或等价 clipmap-lite 机制，并与道路表面覆盖保持连续。

**非目标**：

- 不要求 v5 一次性做完完整 GPU clipmap 或完整 virtual texturing；
- 不要求重写全部道路表面体系；
- 不要求在本阶段完成 C++/GDExtension 下沉。

**验收口径**：

- 自动化诊断测试必须输出 `current_vertex_sample_count`、`unique_vertex_sample_count` 与 `duplication_ratio`，并断言地形网格热路径的 `duplication_ratio <= 1.2`；
- 自动化测试至少断言：相邻 chunk / page 的 terrain page key、边界高度和法线签名连续，不会因为缓存/分页而重新出现地表接缝；
- 自动化测试至少断言：terrain prepare 与 terrain commit 被显式拆分，并且后台线程不得直接操作 scene tree 或 GPU 资源；
- 自动化测试至少断言：terrain near / mid / far 至少存在两档不同分辨率或等价分层，同时道路覆盖与可行走地表连续；
- fresh runtime profiling 必须持续输出 terrain 相关指标，并以 `16.67ms/frame` 红线为最终验收约束。

### REQ-0001-012 道路语义契约与交叉口拓扑

**动机**：当前 shared road graph 已经解决了“哪里有路”，但 lane / section / intersection 语义仍然偏薄，导致 chunk 渲染、pedestrian lane graph 与未来 signage / vehicle 系统不得不重复从几何端点临时猜测。如果直接把参考项目的 node-driven runtime 搬进来，又会把 streaming 和性能重新拉回错误架构。

**范围**：

- 在 shared `road_graph` / template catalog 中显式记录 road section semantic contract，至少包括 `template_id`、directional lane schema、marking profile、shoulder / median / edge offset profile 或等价字段。
- 在 intersection data 中显式记录 ordered branches、intersection type、branch connection semantics，以及可供 chunk layout / lane graph 查询的拓扑 contract。
- 允许 chunk road layout、road surface、bridge mesh、pedestrian lane graph 和后续 signage / vehicle 系统从同一 contract 取数。
- 语义 contract 必须可脱离 scene node 查询，并保持 fixed seed 下 deterministic。
- 实现路径必须继续复用当前 `road_graph -> chunk road layout -> surface page / bridge mesh` 管线（[已由 ECN-0018 变更](../ecn/ECN-0018-road-semantic-runtime-uplift.md)）

**非目标**：

- 不引入 `RoadManager`、`RoadContainer`、`RoadPoint`、`RoadSegment`、`RoadIntersection`、`RoadLane` 风格的运行时节点树
- 不引入 `Path3D` lane runtime、per-segment `MeshInstance3D` 道路 scene graph 或 editor plugin 工作流
- 不在 v7 直接做车辆交通仿真、道路编辑器或最终 signage 系统

**验收口径**：

- 自动化测试至少断言：固定 seed 下 road edge / intersection semantic contract 稳定，section / lane / intersection metadata 可重复查询。
- 自动化测试至少断言：intersection ordered branches 与 type / connection semantics 成立，不再完全依赖 endpoint cluster 临时猜测。
- 自动化测试至少断言：chunk layout / surface / bridge 至少有一条正式 consumer 链消费 semantic contract。
- fresh runtime / first-visit / chunk setup profiling 继续守住 `16.67ms/frame` 红线及本轮计划阈值。
- 反作弊条款：不得通过把道路重新拆成 per-road / per-lane scene node、`Path3D` 树或大量独立 `MeshInstance3D` 来实现语义升级。

### REQ-0001-013 城市总体形态与 PNG 验收输出

**动机**：当前 shared road graph 即使能通过连续性、语义和性能测试，也仍可能在整城层面退化成 world-filling dense grid。没有世界级 morphology 证据，项目就会在“技术上通过、视觉上失真”的状态里持续漂移。

**范围**：

- world road graph 必须由多中心 density / corridor field 驱动，至少形成 1 个主城区与 2 个以上卫星城或次中心。
- `district graph` 允许继续作为世界索引存在，但不得直接成为正式可见道路主骨架。
- building layout 必须在 overview 层可体现出沿街附着关系，而不是全域均匀散点。
- 提供 deterministic overview exporter，输出与当前 seed 一致的 `PNG + metadata`，直接来源于 `road_graph + building layout`。

**非目标**：

- 不要求 v13 一次性做完最终土地利用模拟或 parcel 级建筑法规。
- 不要求 overview PNG 具备最终游戏内美术风格。
- 不要求在本轮重构 addressable building / place index 主键体系。

**验收口径**：

- 固定 seed 下，自动化测试至少断言：`population_center_count >= 3`、`corridor_count >= 2`，且 `road_edge_count` 明显低于 full-world district lattice 基线。
- 固定 seed 下，自动化测试至少断言：中心城与至少两个卫星窗口存在正式道路查询结果，而不是只有中心城有路、其余世界为空。
- 固定 seed 下，自动化测试至少断言：主城到卫星城的 trunk corridor 沿线采样窗口连续命中正式道路，不得出现“道路只在两头、中间断开”的假连通。
- headless overview exporter 必须稳定输出 `PNG + metadata` 到固定路径；metadata 至少包含 `road_edge_count`、`population_center_count`、`corridor_count`、`building_footprint_count`、`road_pixel_count`、`building_pixel_count`。
- fixed seed 下，overview metadata 的有效城市范围必须覆盖世界级尺度，不能再退化回中心区小补丁图。
- 反作弊条款：不得继续保留 world-filling district lattice 作为正式可见道路主骨架；不得导出静态参考图、手工截图或与当前世界数据脱钩的示意图来冒充 overview evidence。

### REQ-0001-007 端到端 travel 验证

**动机**：只有单元测试无法证明“大城市连续移动”这个核心用户流程真的跑通。

**范围**：

- 构建至少一个自动化 E2E 场景级测试
- 验证玩家穿越多个 chunk、触发 streaming、保持 HUD/debug 输出有效

**非目标**：

- 不做完整任务流程 E2E
- 不做视觉截图比对

**验收口径**：

- 运行一个 headless E2E 测试，自动推动玩家跨越至少 `2048m` 路径，最终输出 `PASS`。
- E2E 日志中必须包含 chunk 迁移证据、最终位置和活跃 chunk 统计，而不是只检查场景能 instantiate。

### REQ-0001-008 开发态高速巡检模式

**动机**：如果 v2 只有 headless 自动测试，没有人工可快速切换的高速巡检入口，就很难快速验证 chunk streaming、地表承托和 debug 观测是否真的成立。

**范围**：

- 在 `CityPrototype.tscn` 中允许玩家切换到高速巡检速度档
- 高速巡检模式接入同一套 streaming / debug 观测链路
- HUD/debug 输出中体现当前 `control_mode`
- 玩家视角应允许更自然的向上观察角度，便于巡检天空与高层轮廓（[已由 ECN-0005 变更](../ecn/ECN-0005-organic-road-density-and-inspection-ui.md)）

**非目标**：

- 不做交通 AI
- 不做车辆碰撞博弈
- 不做车流系统或 lane-level 决策

**验收口径**：

- 自动化测试至少断言：场景中不存在 legacy `Ground` 与 `InspectionCar`，可切换到 `inspection` 模式，且切换后 `active_chunk_count` 仍然 `<= 25`。
- 人工试玩时应能通过高速巡检模式在大城市范围内快速检查 chunk streaming、LOD 与运行时观测。

### REQ-0001-009 2D 小地图与导航投影

**动机**：`70km x 70km` 城市如果没有一张与 3D 世界严格同源的 2D 地图层，人工巡检、路径辨认、道路命名和后续导航 UI 都会失去锚点。

**范围**：

- 基于同一份 world road graph 生成 2D 城市投影；
- 在 HUD 中提供默认折叠的小地图视图；
- 小地图至少显示道路骨架、玩家位置、玩家朝向、当前路径高亮；
- 小地图坐标与 3D 世界坐标之间提供稳定可测的投影接口。

**非目标**：

- 不做最终美术风格地图瓦片
- 不做完整 GPS 语音导航
- 不做全量兴趣点数据库

**验收口径**：

- 自动化测试至少断言：同一 seed 下，小地图道路投影与 world road graph 拓扑一致，不能生成另一份独立随机路网。
- 自动化测试至少断言：给定世界坐标，2D 小地图能稳定投影玩家位置和路线折线。
- 自动化测试至少断言：HUD 小地图默认折叠，可展开，并显示玩家标记与至少一条路径高亮。
- 反作弊条款：不得用静态贴图或与真实道路无关的示意图冒充小地图。

## Open Questions

- v2 是否需要预留驾驶相机高度和更高移动速度的参数空间。
- v2 是否需要在 district graph 中预留“城区风格模板”字段，供 v3 引入 example-based variation。

这些问题当前不阻塞 v2 开工，暂不单独开 ECN。
