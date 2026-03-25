# PRD-0029 Artillery Howitzer Scene Foundation

## Summary

在现有 `m777_3_parts.glb` 三段式火炮资产基础上，建立一套正式、可复用、可继续扩展的火炮包装场景与调试 lab。该交付的核心不是“把模型摆进一个预览器”，而是冻结一条未来可接入主世界、音效、控制面、射击逻辑、射击诸元 HUD 与世界 feature 的正式 scene contract：`lower_base` 固定、`upper_carriage` 负责水平回转、`gun_assembly` 负责俯仰；同时把两个关键轴心位置显式 author 成手工可调的锚点，并把“开火瞬间应该携带什么射击诸元 payload”正式合同化。

## Problem

当前仓库只有拆分后的原始 `glb` 资产，没有正式火炮 scene wrapper、没有可复用节点层级、没有锚点 contract，也没有独立 lab 可用来调试俯仰/旋转、控制面与后续音效。直接把 `glb` 塞进主世界会导致：

- yaw / pitch 轴心没有正式口径，只能靠代码硬编码猜位置；
- 后续音效、开火点、乘员位、交互点、任务挂点都没有稳定 scene contract；
- 没有独立 lab，后续调试会把“火炮本体问题”和“主世界接入问题”混在一起。

## Goals

- 建立正式的 `CityM777Howitzer.tscn` 火炮包装场景。
- 把 `m777_3_parts.glb` 收口进稳定的三层 runtime 层级：`lower_base -> yaw -> pitch`。
- 把底盘回转轴与炮身俯仰耳轴做成手工可调 `Marker3D` 锚点。
- 暴露后续可复用的最小 runtime API：设置/读取 yaw、pitch、anchors、debug state。
- 建立独立 `lab` 场景，允许在不接主世界的情况下调试火炮 scene。
- [已由 ECN-0032 变更] 在 `lab` 中建立上下文化操炮交互：靠近火炮约 `7m` 时出现 `按 E 操作炮` 提示，进入操炮态后 HUD 必须持续显示 `J/L`、`I/K` 与 `E` 的控制提示，且只有离炮约 `20m` 后才自动脱离操炮态。
- [已由 ECN-0033 变更] 在正式 `CityM777Howitzer` runtime 中加入可复用的开火演出 contract：`2s` 冷却、炮口火光、烟尘、拉火绳张紧、轻微后坐与正式 weapon fire audio，但不生成炮弹实体。
- [已由 ECN-0034 变更] 建立正式的射击诸元 HUD contract：只在操炮态显示、复用 shared HUD consumer、直接向玩家显示炮口的世界级 bearing 与当前 pitch。
- [已由 ECN-0034 变更] 建立正式的 firing solution payload contract：每次 accepted fire 都能留下结构化快照，供后续 projectile、落点动画、弹道与反炮兵链路复用。
- [已由 ECN-0035 变更] 将 howitzer 正式接入主世界：按下 `KP_8` 后，玩家前方可以直接召唤一门当前 howitzer 实例，并复用 lab 同口径的操炮交互、提示与诸元 HUD。
- [已由 ECN-0035 变更] 在主世界新增 formal artillery shell ballistic runtime：accepted fire 会生成真实 shell，按 firing solution payload 飞行并在世界中产生正式落点/爆炸结果。
- [已由 ECN-0036 变更] 建立正式的 gameplay artillery ballistic solver：冻结当前 howitzer 的有效射程包线为 `1.5km~22.5km`，并提供共享的正向落点解算与反向目标点求诸元能力。
- [已由 ECN-0037 变更] 在 full map 建立右键上下文菜单与单个 active artillery fire mission marker；选中 `炮击标记` 后，系统必须基于 shared ballistic solver 立即给出 bearing / pitch / range / arc 的正式解算结果或明确的超射程原因。
- [已由 ECN-0037 变更] 当玩家先在 full map 规划 fire mission 再按 `KP_8` 召唤火炮时，主世界 howitzer 必须优先复用该 mission 冻结的 battery snapshot，而不是偷偷改到新的随机位置，确保地图阶段抄下来的诸元仍然可用。
- [已由 ECN-0037 变更] 主世界 accepted fire 后必须进入正式 artillery observation closeout：按 actual firing solution 预测落点、预热 impact chunk 周边 page/actor 数据、在炮口演出后切到目标区观察爆炸；即使没有 map mission，free fire 也必须拥有同口径的观察闭环。
- [已由 ECN-0039 变更] 当 `player drone active + FPV ADS active` 时，玩家按 `T` 必须可以直接把无人机准星落点送入同一条 artillery fire mission 主链，形成正式的无人机校炮入口；该入口不得生成第二套 marker / solver / battery snapshot 状态。

## Non-Goals

- [已由 ECN-0037 变更] 不在本轮接入任务系统、多炮队列、battery roster、landmark/task registry 挂接或 full-map 多级目标管理；本轮新增的 full map 范围仅限单个 artillery fire mission context menu / marker / observer closeout。
- [已由 ECN-0031 变更] 不在本轮实现炮弹实体、弹道、落点、爆炸、杀伤判定或火控解算；本轮新增范围仅限正式 howitzer runtime 的开火演出与 lab 内的触发交互。
- [已由 ECN-0030 变更] 不在本轮实现主世界火炮交互 UI、乘员、动画、AI、任务或对话；本轮新增的交互范围仅限 `M777HowitzerLab` 内的近距进入/退出操炮态。
- [已由 ECN-0034 变更] 不在本轮实现 projectile 级弹道积分、落点效果、杀伤判定、反炮兵雷达或整套硬核火控求解；本轮新增范围仅限 formal firing solution HUD 与 payload snapshot contract。
- [已由 ECN-0036 变更] 不在本轮实现气象修正、装药号表、风偏、旋偏、科氏力、mil/mils 火控表、预测落点 HUD 可视化或完整军规级火控流程。
- [已由 ECN-0037 变更] 不在本轮实现自动调炮、自动击发、自动跟踪 shell 的空中弹道摄影机、多人协同观测、弹着修正表或持续驻留的 observer drone。

## User Experience

1. 开发者可以直接打开正式 `CityM777Howitzer.tscn`，看到完整包装好的火炮 scene。
2. 开发者可以在该 scene 中手工微调：
   - `YawPivotAnchor`
   - `PitchPivotAnchor`
3. 打开 `M777HowitzerLab.tscn` 后，可以以正式 `PlayerController` 进入独立地面环境，看见胶囊玩家、火炮实例和可用相机视角。
4. lab 中可以直接驱动 yaw / pitch 调试，不依赖主世界逻辑。
5. 调试完成后，该 howitzer scene 可以作为后续主世界接入与功能扩展的正式基础。
6. [已由 ECN-0032 变更] 玩家在 `lab` 中接近火炮约 `7m` 时，会看到共享 HUD prompt：`按 E 操作炮`。
7. [已由 ECN-0030 变更] 玩家按下 `E` 后进入操炮态，HUD 必须持续显示 `J/L` 调整方位、`I/K` 调整高低、`E` 退出的控制提示；仅当玩家再次按下 `E`，或离炮约 `20m` 后，操炮态才会结束。
8. [已由 ECN-0031 变更] 玩家进入操炮态后，可在 `20m` 保活范围内按下 `Space` 触发 howitzer 的正式开火演出，而不是 lab-only 假按钮。
9. [已由 ECN-0033 变更] 每次 accepted fire 都必须给出明显的火光、烟尘、拉火绳绷紧、轻微后坐与 weapon fire audio 反馈，并进入 `2s` 装填冷却。
10. [已由 ECN-0031 变更] 冷却期间 HUD 必须明确显示 `装填中 X.Xs...`；冷却结束后必须明确显示 `可击发`，而不是让玩家靠猜。
11. [已由 ECN-0034 变更] 玩家进入操炮态后，HUD 右下区域必须出现一组正式“射击诸元”标尺，而不是只剩调试文字。
12. [已由 ECN-0034 变更] 其中 `yaw` 不再显示 howitzer 自身相对回转角，而是直接显示炮口当前在世界坐标系里的 bearing，和 shared north/compass contract 完全同口径。
13. [已由 ECN-0034 变更] 每次 accepted fire 之后，runtime 必须能读回该发 shot 的 firing solution payload；即使当前还没有 projectile / 弹道演出，这份 payload 也必须能作为未来弹道学与落点系统的正式输入。
14. [已由 ECN-0035 变更] 在主世界中，玩家按下 `KP_8` 后，面前会出现一门当前召唤 howitzer；此后靠近它时，必须看到与 lab 完全同口径的 `按 E 操作炮` 提示。
15. [已由 ECN-0035 变更] 玩家在主世界进入操炮态后，`E`、`J/L`、`I/K`、`Space`、20m retention、火绳、冷却文案与诸元 HUD 都必须与 lab 共线，而不是主世界重写另一套手感。
16. [已由 ECN-0035 变更] 主世界 accepted fire 后，玩家必须真的看到 formal artillery shell 飞出去，并在世界某处产生正式落点/爆炸结果，而不是继续只有炮口演出。
17. [已由 ECN-0036 变更] 当前 howitzer 的 gameplay 射程必须冻结为 `1.5km~22.5km`，既不能贴脸直瞄，也不能一发覆盖整张超大地图。
18. [已由 ECN-0036 变更] 系统必须能够根据当前 firing solution 预测“如果这一发真的打出去，理论上会落在哪里”，供后续落点 HUD、炮弹实体和弹道学链路共用。
19. [已由 ECN-0036 变更] 系统必须能够根据“火炮位置 + 目标位置”反向求出世界 bearing 与 pitch；超出 `1.5km~22.5km` 包线时，必须明确拒绝，而不是给玩家一个假的可击中解。
20. [已由 ECN-0037 变更] 玩家打开 full map 后，必须可以在地图画布上右键唤出上下文菜单；当前菜单至少提供一个正式动作：`炮击标记`。
21. [已由 ECN-0037 变更] 选择 `炮击标记` 后，地图上必须出现一个醒目的黄色叉叉 artillery marker，并立刻显示该 target 对应的 bearing / pitch / range / arc；若超出射程，UI 也必须明确说明原因，而不是静默失败。
22. [已由 ECN-0037 变更] 如果玩家是在还未召唤 howitzer 的情况下先做 map planning，系统也必须冻结一份 battery snapshot，确保随后按 `KP_8` 召唤时能把 howitzer 放到与本次 fire mission 共线的位置。
23. [已由 ECN-0037 变更] 玩家记下地图给出的诸元后，仍然通过既有 howitzer 操炮链手动输入 bearing / pitch，并按 `Space` 正式击发；系统不应偷偷代替玩家自动拨炮。
24. [已由 ECN-0037 变更] 开炮后，玩家必须先看到 howitzer 自身的击发演出与短暂飞行 closeout；随后画面切到目标区，观察正式 shell impact 与爆炸结果，而不是永远待在炮位原地。
25. [已由 ECN-0037 变更] 即使玩家没有做 map reverse solve、只是随意打一发，系统也必须仍然给出同口径的炮击观察效果；区别只在于没有预先存在的 fire mission marker 与 map-side 诸元提示。
26. [已由 ECN-0039 变更] 当 `player drone active + FPV ADS active` 时，玩家按 `T` 必须直接创建或更新同一枚黄色炮击黄叉，而不是被迫重新打开 full map 走右键流程。
27. [已由 ECN-0039 变更] 若当前 live howitzer 操炮 active，无人机 `T` 校准后的新 target 必须立即刷新 bearing / pitch；若非无人机 FPV 场景，则 `T` 的既有快捷语义必须保持。

## Requirements

### REQ-0029-001 Formal Scene Wrapper

必须提供正式火炮包装场景 `res://city_game/combat/artillery/CityM777Howitzer.tscn`，并由专用脚本驱动。该 scene 必须包装 `res://city_game/assets/environment/source/artillery/m777/m777_3_parts.glb`，不能退回 root 级散装资产或脚本临时拼装；同时必须把 AI 生成的缩水 source asset 归一化到可进入主世界的真实武器平台量级，不能保持“玩具炮”尺寸。

### REQ-0029-002 Three-Part Runtime Hierarchy

正式 scene 必须把三段模型收口进稳定层级：

- `m777_lower_base`
- `m777_upper_carriage`
- `m777_gun_assembly`

其中：

- `lower_base` 固定在底盘层；
- `upper_carriage` 围绕 yaw 轴旋转；
- `gun_assembly` 围绕 pitch 轴旋转。

### REQ-0029-003 Manual Anchor Contract

正式 scene 必须 author 两个手工可调 `Marker3D` 锚点：

- `Anchors/YawPivotAnchor`
- `Anchors/PitchPivotAnchor`

runtime 必须读取这两个锚点来定位真正的 `YawPivot` 与 `PitchPivot` 节点，而不是把轴心硬编码在脚本常量里。

### REQ-0029-004 Runtime API Contract

火炮 scene root 必须至少暴露以下接口，供 lab / future world integration / focused tests 复用：

- `get_visual_root()`
- `set_yaw_degrees(value: float)`
- `set_pitch_degrees(value: float)`
- `set_axis_angles_degrees(yaw_deg: float, pitch_deg: float)`
- `get_yaw_degrees()`
- `get_pitch_degrees()`
- `get_anchor_state()`
- `get_debug_state()`

其中 `pitch` 的对外语义冻结为“校准后的真实仰角”：

- 炮口视觉放平时为 `0°`
- 正值表示抬高炮口，负向不对外暴露
- 当前模型允许保留一个内部零位校准偏置量
- 对外 `pitch` 必须被限制在 `0-71°`
- 对外 `yaw` 必须归一到 `0-360°` 圆周内；跨过整圈后回卷，不继续暴露累计转圈数
- `get_pitch_degrees()`、`set_pitch_degrees()`、`set_axis_angles_degrees()` 与 lab HUD 都必须共享同一口径，而不是一边显示模型内部角、一边显示真实仰角

### REQ-0029-005 Lab Scene Contract

必须提供独立 lab 场景 `res://city_game/scenes/labs/M777HowitzerLab.tscn`，它要挂载正式火炮 scene，而不是直接挂 `glb`。该 lab 必须具备基础地面、光照、正式 `PlayerController` 玩家、当前可用的玩家相机，以及最小调试 UI / 状态输出，用于后续继续调控制面与音效。

### REQ-0029-006 Lab Control Contract

lab 必须允许直接驱动火炮 yaw / pitch，并暴露最小查询/重置接口，确保未来调试不依赖主世界。具体输入映射可以简化，但必须有稳定可复用的脚本 API，而不是只能靠编辑器手动拧 Inspector。

### REQ-0029-007 Lab Operation Interaction Contract

[由 ECN-0030 新增，ECN-0032 变更] `M777HowitzerLab` 必须把键盘操炮从“全局热键”收口为“近距上下文交互”：

- 玩家只有在接近火炮约 `7m` 时，HUD 才能出现 `按 E 操作炮` 提示；
- 按下 `E` 后进入操炮态，再次按下 `E` 可手动退出；
- 进入操炮态后，HUD 必须持续显示 `按 E 退出操炮  J/L 方位  I/K 高低  R 复位`；
- 只有在操炮态激活时，`J/L` 才能控制火炮 yaw，`I/K` 才能控制 pitch；
- 进入操炮态后，玩家离开 `7m` 进入半径但仍处于约 `20m` 的保活半径内时，操炮态必须继续保持；
- 只有手动退出，或离炮约 `20m` 之后，操炮态与 `J/L/I/K` 所有权才会被释放；
- `lab` 的 prompt 必须复用主世界既有的 HUD prompt contract，而不是再造第三套提示协议。

### REQ-0029-008 Formal Fire Presentation Contract

[由 ECN-0031 新增] 正式 `CityM777Howitzer` runtime 必须内建一条可复用、可测试、非 lab 私货的开火演出 contract：

- scene 必须正式 author 至少两枚开火演出锚点：
  - `Anchors/MuzzleFxAnchor`
  - `Anchors/LanyardAnchor`
- runtime root 必须至少暴露以下 fire API：
  - `can_fire()`
  - `request_fire()`
  - `get_fire_state()`
- accepted fire 的冻结语义：
- 默认冷却为 `2.0s`
  - 触发炮口火光
  - 触发短寿命炮口烟尘
  - 触发拉火绳从“略松”到“瞬间绷紧”的演出
  - 触发轻微炮身后坐
  - 触发正式 weapon fire audio
- 拉火绳 baseline 与操炮态 rope 必须在 gameplay camera 距离下表现为稳定的连续曲线，不得因为 howitzer 包装 scene 的父级缩放而塌成贴地折线
- rejected fire 的冻结语义：
  - 冷却期间再次请求必须被拒绝，并暴露明确 cooldown state
- 反作弊条款：
  - 不允许通过 runtime 临时生成 projectile / grenade / missile 节点来伪装“开火已实现”
  - 不允许把上述演出只写在 `M777HowitzerLab` 脚本里，正式 howitzer scene runtime 必须是唯一真源
- `get_fire_state()` / `get_debug_state()` 必须显式暴露冷却、火光、烟尘、拉绳、后坐与 weapon fire audio 的 runtime 状态，便于 focused tests 回归

### REQ-0029-009 Artillery Firing Solution HUD Contract

[由 ECN-0034 新增] howitzer 系统必须提供一条正式、可复用、非 lab-only 的“射击诸元 HUD”消费链，供 `M777HowitzerLab` 与未来主世界 howitzer 接入复用。该 contract 必须满足：

- HUD 真源必须挂在 `res://city_game/ui/PrototypeHud.gd`，不能把诸元尺做成 `M777HowitzerLab.gd` 私有控件；
- HUD 必须至少暴露：
  - `set_artillery_solution_state(state: Dictionary)`
  - `get_artillery_solution_state()`
- HUD 的显示所有权冻结为：
  - 只有在 howitzer 操炮态激活时可见；
  - 未进入操炮态时必须完全隐藏；
- HUD 至少显示两条射击诸元标尺：
  - `yaw`：炮口在世界坐标系里的 bearing，必须共享 `PRD-0030 / REQ-0030-001` 的 north/bearing 口径，而不是 howitzer 自身相对 yaw；
  - `pitch`：当前已校准的真实仰角，必须继续共享 `REQ-0029-004` 的 `0-71°` 语义；
- `yaw` 的世界 bearing 语义冻结为：由 howitzer 当前炮口朝向在世界空间中的真实向量解出，不允许偷回退成“相对初始炮口偏航角”；
- 射击诸元 HUD 的视觉风格必须显式复用现有 compass strip 的语言族，而不是临时再造一套完全不同的 UI 美术口径。

### REQ-0029-010 Firing Solution Payload Contract

[由 ECN-0034 新增] 正式 `CityM777Howitzer` runtime 必须把“开火瞬间的射击诸元”合同化为结构化 payload，并允许 lab / future world / projectile systems 读取。该 contract 必须至少满足：

- root 至少暴露：
  - `get_firing_solution_snapshot()`
  - `get_last_fired_solution()`
- accepted `request_fire()` 必须返回并落存本次 shot 的 firing solution payload；
- payload 至少包括：
  - 发射 origin 的世界坐标
  - howitzer 平台世界坐标
  - 炮口世界方向向量
  - 炮口世界 bearing
  - 当前 pitch
  - `shell_type_id`
  - `muzzle_velocity_mps`
- payload 必须正式保留 `chunk` 级上下文口径，至少允许读到当前 shot 对应的 `chunk_key` / `chunk_id` 或等价 chunk metadata；如果某 host 暂时无法补足更丰富上下文，也不能让字段定义消失；
- payload 的目标不是本轮直接做 projectile，而是为后续弹道积分、落点效果、弹种分化与反炮兵链路提供稳定输入；因此不得把这份数据只塞进 debug 文本里，必须提供正式 API。

### REQ-0029-011 Main-World Howitzer Summon Contract

[由 ECN-0035 新增] howitzer 系统必须正式接入 `CityPrototype` 主世界，并满足：

- `CityPrototype` 必须把 `KP_8` 绑定为 debug summon 入口；
- 按下 `KP_8` 后，必须在玩家当前朝向前方生成一门正式 `CityM777Howitzer.tscn`；
- 召唤位置必须落在地表，而不是悬空、埋地或停在玩家胶囊体中心；
- 同一时刻只允许存在一门当前召唤 howitzer；
- 再次按下 `KP_8` 时，旧 howitzer 必须被替换或重定位，而不是无限累积多个实例；
- 主世界必须至少暴露：
  - `get_active_world_howitzer()`
  - `get_world_howitzer_operation_state()`
  - `get_active_artillery_shell_count()`
  - `get_last_artillery_shell_explosion_result()`

### REQ-0029-012 Shared Howitzer Operation Runtime Contract

[由 ECN-0035 新增] `M777HowitzerLab` 与 `CityPrototype` 主世界 howitzer 必须共享同一条正式操炮 runtime/controller，而不是各写一套私有输入逻辑。该 contract 至少包括：

- `E` 进入/退出操炮；
- `J/L` 调整 yaw；
- `I/K` 调整 pitch；
- `Space` 击发；
- 约 `7m` 交互半径与约 `20m` retention 半径；
- shared HUD prompt 与 artillery solution HUD 可见性；
- player `Space` 击发时必须继续复用 jump suppression，避免操炮时角色起跳。

### REQ-0029-013 Artillery Shell Ballistics Contract

[由 ECN-0035 新增] 主世界 accepted fire 必须生成正式 `artillery shell` runtime，而不是继续停留在 muzzle flash / smoke / cooldown 层。该 contract 至少满足：

- shell runtime 只能由 howitzer accepted fire 驱动生成；
- shell 的 launch state 必须直接来源于 howitzer `firing_solution` payload；
- shell 必须至少暴露：
  - `configure_from_firing_solution(firing_solution: Dictionary, owner_node: Node, player_target: Node)`
  - `get_debug_state()`
  - `get_last_explosion_result()`
- shell 必须按重力进行正式飞行积分，并在 impact 或寿命截止时给出结构化 explosion result；
- shell 允许使用显式 gameplay time-compression 来缩短超远程 flight 的等待时间，但该参数必须是 formal runtime 配置，而不是偷偷改写 payload 的 `muzzle_velocity_mps`；
- impact result 至少包括：
  - `trigger_kind`
  - `world_position`
  - `radius_m`
  - `flight_time_sec`
  - `distance_travelled_m`
  - `firing_solution`
  - `pedestrian_result`
  - `vehicle_result`
- impact 必须正式接入主世界已有的行人、车辆、建筑和敌对目标爆炸消费链；
- 反作弊条款：
- 不允许把 howitzer shot 偷换成 `CityGrenade` 或 `CityMissile`
- 不允许只创建远处爆炸特效而没有 live shell flight runtime
- 不允许主世界 howitzer 再写一套与 lab 分叉的 prompt / HUD / ownership 逻辑

### REQ-0029-014 Gameplay Artillery Ammo Profile Contract

[由 ECN-0036 新增] howitzer 系统必须正式冻结一套 gameplay 级弹种/弹道 profile contract，而不是继续让 `shell_type_id` 只停留在字符串占位。当前默认弹型必须至少满足：

- `shell_type_id = "m795_he"`
- `display_name`
- `min_range_m = 1500.0`
- `max_range_m = 22500.0`
- `reference_muzzle_velocity_mps`：允许保留公开资料里的参考口径
- `solver_muzzle_velocity_mps`：供当前 gameplay solver / live shell runtime 使用的正式求解速度
- `pitch_min_deg`
- `pitch_max_deg`

当前 howitzer 的 firing solution payload 必须显式绑定该 profile，后续允许扩展更多弹种，但不允许让 solver / shell runtime / future HUD 各自私下猜测射程与速度。

### REQ-0029-015 Forward Ballistic Prediction Contract

[由 ECN-0036 新增] 系统必须提供正式的正向弹道解算接口：给定 `firing_solution`，能够使用共享 gameplay ballistic model 预测该 shot 的理论落点，并至少返回：

- `valid`
- `shell_type_id`
- `impact_world_position`
- `horizontal_distance_m`
- `slant_distance_m`
- `flight_time_sec`
- `launch_velocity_world`
- `range_state`

该接口的冻结语义为：

- 当前采用 gameplay 级简化 point-mass / no-wind model；
- 当前 howitzer 的射程 envelope 冻结为 `1.5km~22.5km`；
- 同一套 model 必须同时服务 future HUD 预测、target solve 验算与 live shell runtime；
- 不允许 HUD/solver/shell 各自维护不同的 ballistic math。

### REQ-0029-016 Inverse Fire Solution To Target Contract

[由 ECN-0036 新增] 系统必须提供正式的反向求解接口：给定 howitzer 发射点世界坐标与目标点世界坐标，解出当前弹型下可用的世界 bearing 与 pitch。该接口至少满足：

- 超出 `1.5km~22.5km` 水平射程 envelope 时，必须返回明确的 `out_of_range`；
- 有解时，必须返回：
  - `world_bearing_deg`
  - `pitch_deg`
  - `arc_kind`
  - `predicted_impact_world_position`
  - `flight_time_sec`
- `pitch_deg` 仍必须遵守 howitzer `0-71°` 的正式口径；
- 接口必须允许 `prefer_high_arc` / `prefer_low_arc` 这类 gameplay 级偏好，但不能返回超出射界或超出 envelope 的伪解。

### REQ-0029-017 Shared Ballistic Model Contract

[由 ECN-0036 新增] howitzer firing solution、forward prediction、inverse solve 与 live shell runtime 必须共享同一套 formal gameplay ballistic model。该 contract 至少包括：

- `CityM777Howitzer.gd` 生成的 firing solution payload 必须显式带出当前 shell profile / solver velocity；
- `CityArtilleryShell.gd` 的 launch velocity 与 flight integration 必须由共享 ballistic utility 推导，而不是继续直接把旧 payload 当作另一套私有 physics 参数；
- target solve 的结果必须可被 forward prediction 反算回目标附近，作为正式 round-trip 验算；
- 不允许出现：
  - target solve 一套 math
  - HUD prediction 一套 math
  - live shell runtime 又一套 math

### REQ-0029-018 Full-Map Artillery Context Menu Contract

[由 ECN-0037 新增] `CityMapScreen` 必须为 full map 提供正式右键上下文菜单 contract，而不是继续只支持左键目的地选点。该 contract 至少满足：

- 只有当 right-click 落在 map canvas 内时，才允许弹出上下文菜单；
- 当前菜单至少包含一个动作：
  - `artillery_fire_mission`
  - 文案为 `炮击标记`
- left-click 目的地导航链必须保持不变，不能因为引入 right-click 而退化；
- `CityMapScreen.get_render_state()` 必须显式暴露 context menu 的可见性、锚点与 action 列表，便于 focused tests 回归；
- full map 关闭时，上下文菜单必须自动隐藏，不得把陈旧菜单状态带回正常 gameplay。

### REQ-0029-019 Artillery Fire Mission Marker Contract

[由 ECN-0037 新增] 系统必须提供正式 `artillery fire mission` 地图标记 contract。该 contract 至少满足：

- 同一时刻只允许存在一个 active fire mission marker；
- marker 必须落在 full map 上被选择的世界坐标；
- marker 视觉口径冻结为：
  - 黄色/金色
  - 叉叉 / cross
- marker 必须显式保留：
  - `mission_id`
  - `target_world_position`
  - `target_chunk_key`
  - `target_chunk_id`
  - `battery_origin_world_position`
  - `solution_state`
- 重复设置新的 fire mission 时，旧 marker 必须被替换，而不是无限累积多个炮击点；
- 该 marker 可以进入 `CityMapPinRegistry` 统一 pin 栈，但不允许绕开 pin 主链另起一套 full-map-only 隐藏列表。

### REQ-0029-020 Map-Side Fire Solution Presentation Contract

[由 ECN-0037 新增] full map 上的 artillery fire mission 必须直接消费 shared ballistic solver，并向玩家显示正式诸元。该 contract 至少满足：

- solver 真源必须继续是 `CityArtilleryBallistics.solve_firing_solution_to_target()`；
- 优先使用当前 active world howitzer 的 battery origin；若当前还没有 howitzer，则必须使用与 `KP_8` summon 共线的 virtual battery snapshot；
- in-range 时必须至少显示：
  - `world_bearing_deg`
  - `pitch_deg`
  - `horizontal_distance_m`
  - `arc_kind`
- out-of-range 时必须显式显示 formal `range_state` / `reason`，例如 `below_min_range` 或 `above_max_range`；
- map-side 诸元展示必须与 howitzer HUD 共用 north/bearing / pitch 口径，不允许地图一套角度、操炮 HUD 又一套角度。

### REQ-0029-021 Planned Battery Snapshot And Summon Contract

[由 ECN-0037 新增] 当玩家在尚未召唤 howitzer 时先从地图创建 fire mission，系统必须冻结一份 formal battery snapshot，确保随后召唤 howitzer 时仍与 mission 共线。该 contract 至少包括：

- snapshot 至少保留：
  - `spawn_root_world_position`
  - `spawn_forward_world`
  - `platform_world_position`
  - `chunk_key`
  - `chunk_id`
- active fire mission 存在且当前 world howitzer 不存在时，按 `KP_8` 召唤 howitzer 必须优先使用该 snapshot；
- 该 snapshot 的目标是让玩家先记诸元再召唤也能成立，而不是要求用户必须先召唤实体炮再看地图；
- 这条 contract 不代表本轮要做自动调炮或自动击发；玩家仍需手动输入 bearing / pitch。

### REQ-0029-022 Artillery Observation Closeout Contract

[由 ECN-0037 新增] 主世界 accepted fire 后必须建立正式 artillery observation closeout，而不是只在炮位原地结束。该 contract 至少满足：

- closeout 必须直接基于 actual firing solution 预测理论 impact world position；
- 击发瞬间必须预热 impact chunk 周边的 chunk page / actor page，而不是等切镜时再同步冷加载；
- 若当前同时满足 `howitzer 操炮 active` 与 `player drone active`，则本条 closeout 必须显式跳过；此时 accepted fire 仍要保留炮口演出、shell 生成与 impact 结果，但不能抢走无人机观察视角；
- 若当前同时满足 `howitzer 操炮 active` 与 `player drone active`，则 `E` 不得再退出 howitzer 操炮态；该键位必须让给 active drone 的上升输入，直到玩家先收回无人机或以其他正式方式结束复合态；
- closeout 至少分为两个阶段：
  - `muzzle_stage`：保留 howitzer 自身击发演出与短暂飞行等待；
  - `impact_stage`：切到目标区 observer camera 观察 impact / explosion result；
- observer camera 必须在 closeout 完成后归还玩家摄像机 ownership；
- closeout runtime 必须暴露正式 debug/introspection state，便于验证：
  - 当前 phase
  - predicted impact world position
  - prewarm target chunk
  - camera owner
  - active / completed 状态。

### REQ-0029-023 Free-Fire Observation Compatibility Contract

[由 ECN-0037 新增] artillery observation closeout 不能只服务“先在地图上做 reverse solve”的标准流程。该 contract 至少满足：

- 只要主世界 howitzer accepted fire，系统就必须根据 actual firing solution 启动 observation closeout；
- 即使没有 active fire mission marker，也必须依旧能：
  - 预测 actual impact
  - 预热 target chunk
  - 切到目标区观察爆炸
- 唯一例外是“player drone active + howitzer 操炮 active”的复合模式；该模式下 free fire 也必须跳过 observer closeout，保留玩家对无人机观察链的连续控制；
- active fire mission 只负责提供 map-side marker / solution / planned battery snapshot，不拥有击发链路的唯一所有权。

### REQ-0029-024 Drone Crosshair Fire Mission Calibration Contract

[由 ECN-0039 新增] 系统必须提供正式的“无人机准星校炮”入口，把 drone FPV world target 接入现有 artillery fire mission 主链。该 contract 至少满足：

- 当且仅当 `player drone active + FPV ADS active` 时，按 `T` 才切换为 artillery fire mission calibration 语义；
- 该入口必须复用正式 `request_artillery_fire_mission_from_world_point()` 或等价的单一 host 真源，不允许复制第二套 planner / marker / solver state；
- 首次按 `T` 时：
  - 若当前没有 active fire mission
  - 必须创建正式 single active yellow cross；
- 再次按 `T` 时：
  - 若当前已有 active fire mission
  - 必须更新同一份 formal mission target，而不是累积多个黄叉；
- 若当前 live howitzer 操炮 active，则新的 target 必须立刻刷新 solved bearing / pitch / range；
- 若当前 howitzer 尚未操炮，则新的 target 必须继续保持 `requires_live_howitzer_operation` pending 口径；
- full map render state、pin registry、focus message 必须继续消费同一份 fire mission state；不允许新增 drone-only 黄叉或 drone-only 解算面板；
- 本轮不要求按 `T` 时自动打开 full map，也不要求自动拨炮或自动击发。

## Acceptance

1. 自动化测试必须证明：`CityM777Howitzer.tscn` 与对应脚本存在，并且场景文本直接引用正式 `m777_3_parts.glb`。
2. 自动化测试必须证明：火炮 scene runtime 层级里存在 `ModelRoot/YawPivot/PitchPivot` 以及两枚正式锚点 `Anchors/YawPivotAnchor`、`Anchors/PitchPivotAnchor`。
3. 自动化测试必须证明：`m777_lower_base`、`m777_upper_carriage`、`m777_gun_assembly` 在 runtime 中分别处于固定层、yaw 层、pitch 层，而不是重新塌回单层根节点。
4. 自动化测试必须证明：火炮 scene root 暴露 `REQ-0029-004` 约定的最小 API。
5. 自动化测试必须证明：调用 yaw / pitch API 会分别改变 `YawPivot` 与 `PitchPivot` 的角度，不会把两级旋转混成单轴。
6. 自动化测试必须证明：`yaw` API 对外暴露的是归一化圆周角，而不是超过 `360°` 的累计转圈数；整圈必须回到 `0°`。
7. 自动化测试必须证明：`pitch` API 对外暴露的是校准后的真实仰角；炮口放平时 `pitch=0°`，正值表示抬高炮口，而不是继续暴露模型内部偏置角或把方向写反。
8. 自动化测试必须证明：`pitch` 被限制在 `0-71°` 射界之内，不能继续无限上抬或下压。
9. 自动化测试必须证明：`M777HowitzerLab.tscn` 存在，并且挂载正式火炮 scene，而不是直接实例化 `glb`。
10. 自动化测试必须证明：lab scene 暴露最小 howitzer 获取 / 状态读取 / 重置接口，并能驱动 yaw / pitch 调试链。
11. 自动化测试必须证明：lab scene 启动时存在正式 `PlayerController` 玩家节点与当前玩家相机，而不是只剩一个静态观察相机。
12. 自动化测试必须证明：正式 howitzer scene 的最终可见包围尺寸已经脱离 `1m` 级缩水资产，达到正式武器平台的最低 world-scale 量级。
13. [由 ECN-0032 变更] 自动化测试必须证明：只有当玩家进入火炮 `7m` 交互半径时，HUD 才出现 `按 E 操作炮` 提示；进入操炮态后 HUD 会持续显示 `J/L`、`I/K` 与 `E` 的控制提示；`J/L/I/K` 仅在操炮态内生效；离开 `7m` 但未超过约 `20m` 时仍保持操炮态；只有再次按 `E` 或离炮约 `20m` 后才释放操炮态。
14. [由 ECN-0031 新增] 自动化测试必须证明：正式 howitzer scene author 了 `MuzzleFxAnchor` 与 `LanyardAnchor`，并且 root 暴露 `can_fire()`、`request_fire()` 与 `get_fire_state()`。
15. [由 ECN-0033 变更] 自动化测试必须证明：accepted fire 会触发正式 runtime 的火光、烟尘、拉火绳张紧、后坐与 weapon fire audio，同时进入默认 `2.0s` 冷却；无论 idle baseline 还是操炮态 operator rope，火绳都必须以稳定连续曲线呈现，不得塌成贴地折线；冷却期间重复 fire 请求会被拒绝。
16. [由 ECN-0031 新增] 自动化测试必须证明：lab 中只有进入操炮态后，`Space` 才能触发正式 howitzer fire API；HUD 会显示 `Space` 提示、冷却中的 `装填中 X.Xs...` 与冷却完成后的 `可击发`。
17. [由 ECN-0031 新增] 自动化测试必须证明：本轮 fire presentation 不会生成任何 projectile / grenade / missile 运行时节点，不把“演出反馈”偷换成“弹道链已实现”。
18. [由 ECN-0034 新增] 自动化测试必须证明：`PrototypeHud` 已挂接正式 artillery solution HUD consumer，且该 consumer 只有在 howitzer 操炮态激活时可见；退出操炮态后必须隐藏。
19. [由 ECN-0034 新增] 自动化测试必须证明：射击诸元 HUD 中的 `yaw` 显示的是炮口世界 bearing，而不是 howitzer 相对 yaw；当整门炮在世界里整体转向时，HUD yaw 也必须随之变化。
20. [由 ECN-0034 新增] 自动化测试必须证明：正式 howitzer runtime 暴露 `get_firing_solution_snapshot()` / `get_last_fired_solution()`，且 accepted fire 后留下的 payload 至少包含发射世界坐标、chunk metadata、世界 bearing、pitch、shell type 与 muzzle velocity。
21. [由 ECN-0035 新增] 自动化测试必须证明：`CityPrototype` 支持按 `KP_8` 在玩家前方召唤正式 howitzer，且同一时刻只维护一个当前实例。
22. [由 ECN-0035 新增] 自动化测试必须证明：主世界 howitzer 的 prompt、`E` 进退操炮、`J/L`、`I/K`、`Space`、20m retention 与 artillery solution HUD 语义与 lab 共线，而不是另一套私有主世界实现。
23. [由 ECN-0035 新增] 自动化测试必须证明：主世界 accepted fire 会生成 live artillery shell runtime，shell 的 launch payload 来源于正式 `firing_solution`，并以重力积分方式飞行到 impact。
24. [由 ECN-0035 新增] 自动化测试必须证明：shell impact 会留下正式 explosion result，并接入主世界的行人/车辆/建筑或敌对目标爆炸消费链，而不是只有一个孤立特效。
25. [由 ECN-0035 新增] 自动化测试必须证明：howitzer shell 不是 `CityGrenade` / `CityMissile` 的参数换皮，且 world howitzer 不会回退成 lab-only 开火演出。
26. [由 ECN-0036 新增] 自动化测试必须证明：系统暴露正式 artillery ammo profile contract，且当前默认弹型明确冻结为 `1.5km~22.5km` gameplay envelope，而不是继续让最小/最大射程散落在 magic number 中。
27. [由 ECN-0036 新增] 自动化测试必须证明：forward ballistic prediction 会基于当前 firing solution 给出结构化 predicted impact result，且 `45°` 附近 shot 的理论极限射程与 `22.5km` envelope 保持一致。
28. [由 ECN-0036 新增] 自动化测试必须证明：inverse target solve 在目标位于合法 envelope 内时能解出 bearing 与 pitch，在目标位于 `1.5km` 内或 `22.5km` 外时会明确返回 `out_of_range`，而不是给出伪解。
29. [由 ECN-0036 新增] 自动化测试必须证明：同一 ballistic model 下，`target -> solve -> predict` 的 round-trip 误差被正式限制在可接受阈值内，不能出现解算出诸元却反推不到原目标的分叉。
30. [由 ECN-0036 新增] 自动化测试必须证明：live artillery shell runtime 使用的 launch velocity / flight model 与 shared ballistic utility 同口径，而不是继续保留旧的私有 `827m/s + gravity` 路径。
31. [由 ECN-0037 新增] 自动化测试必须证明：full map 支持正式 right-click context menu；地图画布内右键会显示 `炮击标记` 动作，而关闭地图时上下文菜单会被清理。
32. [由 ECN-0037 新增] 自动化测试必须证明：选择 `炮击标记` 后，系统会留下正式 active fire mission marker，且地图 render state / pin state 能读到黄色 cross 语义、target chunk metadata 与单实例替换策略。
33. [由 ECN-0037 新增] 自动化测试必须证明：map-side fire mission 会立即调用 shared ballistic solver，并给出 bearing / pitch / range / arc；超出射程时会暴露 formal `reason` 而不是沉默失败。
34. [由 ECN-0037 新增] 自动化测试必须证明：在“先地图规划、后 `KP_8` 召唤”的流程里，world howitzer 会优先复用本次 fire mission 的 planned battery snapshot，而不是在新的玩家前方随机生成导致诸元失效。
35. [由 ECN-0037 新增] 自动化测试必须证明：主世界 accepted fire 会启动 observation closeout，留下 predicted impact、prewarm chunk 与 camera ownership 的正式 runtime state，并在 closeout 结束后恢复玩家 camera。
36. [由 ECN-0037 新增] 自动化测试必须证明：即使没有 active fire mission marker，free fire 也会照样触发同口径的 observation closeout，而不是只剩旧的“炮口响一下”链路。
37. [由 ECN-0038 新增] 自动化测试必须证明：当 `player drone active + howitzer 操炮 active` 同时成立时，accepted fire 不会启动 observer closeout；shell 与 impact 仍然存在，但 camera ownership 不得被 observer runtime 抢走。
38. [由 ECN-0038 新增] 自动化测试必须证明：当 `player drone active + howitzer 操炮 active` 同时成立时，按下 `E` 不会退出 howitzer 操炮态；该输入必须继续归 active drone 的上升控制所有。
39. [由 ECN-0039 新增] 自动化测试必须证明：`player drone active + FPV ADS active` 下按 `T` 会创建或更新正式 artillery fire mission，且 `target_world_position` 与无人机准星 `world_target` 对齐，而不是落入另一套私有 target state。
40. [由 ECN-0039 新增] 自动化测试必须证明：重复按 `T` 只会更新单个 active yellow-cross fire mission；若当前 live howitzer 操炮 active，则 solved bearing / pitch 会随新 target 刷新；非无人机 FPV 场景下，`T` 的既有快捷语义不回退。
