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
- 生成 arterial / secondary road graph
- 提供 block / parcel 的确定性、按 chunk 查询的元数据接口（[已由 ECN-0001 变更](../ecn/ECN-0001-large-city-scale-and-inspection.md)）
- 允许 chunk 在没有高模资源时先用占位表现

**非目标**：

- 不做最终建筑立面库
- 不做城市美术风格编辑器

**验收口径**：

- 世界生成 API 能在不实例化整座城市场景节点的前提下，返回完整 district / road 图，以及可按 chunk 查询的 block / parcel 元数据契约。
- 自动化测试至少断言生成结果包含非空 district graph、完整道路边集合、完整 block / parcel 统计，以及 `get_blocks_for_chunk()` 这类惰性查询接口。
- 反作弊条款：任何验收都不得仅靠扩大 `CityPrototype.tscn` 中的静态几何来宣称“城市已扩容”。

### REQ-0001-003 受边界约束的 chunk streaming

**动机**：大城市的关键不是地图总面积，而是高成本活跃区必须有上限。

**范围**：

- 基于玩家或开发态高速巡检模式下的玩家位置决定进入/退出的 chunk（[已由 ECN-0001 变更](../ecn/ECN-0001-large-city-scale-and-inspection.md)，[已由 ECN-0002 变更](../ecn/ECN-0002-fast-inspection-mode.md)）
- 高成本活跃窗口固定为玩家周围 `5x5` chunk
- chunk 准备流程支持后台数据准备与主线程挂载
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
- block 自动生成基础遮挡体或 `ArrayOccluder3D`
- chunk 必须提供占位地表与碰撞壳，保证离开中心原型区后仍可连续步行/高速巡检（[已由 ECN-0001 变更](../ecn/ECN-0001-large-city-scale-and-inspection.md)，[已由 ECN-0002 变更](../ecn/ECN-0002-fast-inspection-mode.md)）
- 提供 debug 统计，显示每个 chunk 的实例数与降级状态

**非目标**：

- 不做最终材质和美术打光
- 不做 Nanite 类超细节远景

**验收口径**：

- 至少一种重复类资产必须通过 `MultiMeshInstance3D` 渲染，而不是逐个 `MeshInstance3D`。
- 自动化测试和 debug 证据必须能证明近/中/远至少三档表现存在。
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
- 展示玩家当前 chunk、活跃 chunk 数、最近 chunk 生成耗时、当前 chunk 的实例统计
- 为主要 E2E 测试输出稳定可解析的 debug 文本
- 为主要 E2E 测试输出稳定可解析的运行时报告，至少包含 `final_position` 与 `transition_count`（[已由 ECN-0001 变更](../ecn/ECN-0001-large-city-scale-and-inspection.md)）

**非目标**：

- 不做最终用户设置面板
- 不做完整 profiler 替代品

**验收口径**：

- 自动化测试或脚本输出中必须能读取 `current_chunk_id`、`active_chunk_count`、至少一个 streaming 耗时指标，以及 `transition_count` / `final_position`。
- 反作弊条款：不得只在文档中写目标数字而没有实际运行时输出。

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

**非目标**：

- 不做交通 AI
- 不做车辆碰撞博弈
- 不做车流系统或 lane-level 决策

**验收口径**：

- 自动化测试至少断言：场景中不存在 legacy `Ground` 与 `InspectionCar`，可切换到 `inspection` 模式，且切换后 `active_chunk_count` 仍然 `<= 25`。
- 人工试玩时应能通过高速巡检模式在大城市范围内快速检查 chunk streaming、LOD 与运行时观测。

## Open Questions

- v2 是否需要预留驾驶相机高度和更高移动速度的参数空间。
- v2 是否需要在 district graph 中预留“城区风格模板”字段，供 v3 引入 example-based variation。

这些问题当前不阻塞 v2 开工，暂不单独开 ECN。
