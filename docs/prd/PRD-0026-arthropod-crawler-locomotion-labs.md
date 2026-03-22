# PRD-0026 Arthropod Crawler Locomotion Labs

## Vision

`godot_citys` 目前已经有成熟的 `lab-first -> main-world port` 方法论，也已经有玩家、战斗、湖区、场馆、小地图和任务等正式主链，但还没有一条真正可复用的“多足生物程序化爬行”运行时。`PRD-0026` 的目标不是仓促往主世界里塞一只会抖腿的怪物，而是先建立一条 **可独立 lab 调试、可被 contract test 锁定、未来可移植回主世界的 arthropod locomotion spine**，然后按明确顺序交付两种生物：先蜘蛛，再龙虾。

这次的成功标准不是“屏幕上出现一只像蜘蛛的模型”或“仓库里多了一个龙虾场景”，而是同时满足六件事。第一，仓库必须正式落成一条共享的 arthropod locomotion spine，至少覆盖 `per-leg state / foothold search / body solver / gait scheduler / debug state / reset contract`，而不是给蜘蛛和龙虾各写一套脚本。[研究入口：`docs/research/2026-03-23-spider-lobster-procedural-gait-research.md`] 第二，首个正式 consumer 必须是独立 `SpiderCrawlerLab`，用低干扰环境把 8 腿 gait、落脚点锁定、地形跟随与 reset 整链跑顺。第三，龙虾必须作为同一 shared runtime 的第二个 species profile 落地到独立 `LobsterCrawlerLab`，其 gait 明确冻结为更接近后向前传播的 metachronal wave，而不是沿用蜘蛛的 tetrapod 假装换皮。第四，`v39` 这轮只交付两座独立 lab 和 future port hooks，不直接接入主世界，但必须把未来接回主世界的 wrapper/anchor/ground resolver 口径提前冻结，避免日后重写。第五，当前仓库已有 `lobster_02.glb` 资产，但没有现成蜘蛛资产，因此蜘蛛首版必须允许 proxy/blockout rig 先跑通 gait，再替换正式视觉。第六，本轮不得为了“看起来更像”而先做 wall-walking、倒挂、失败态、任务接入、完整生态系统或水下流体模拟；这些都只能在 shared spine 稳定之后进入后续版本。

## Background

- 本仓库已经验证了多条正式 `lab-first` 工作流：
  - `v33` / `BuildingCollapseLab`
  - `v37` / `HelicopterGunshipLab`
  - `v38` / `LakeFishingLab`
- 仓库当前独立 lab 目录在：
  - `res://city_game/scenes/labs/`
- 当前 creature 资产现实：
  - 已存在：`res://city_game/assets/environment/source/creatures/lobster_02.glb`
  - 未发现正式蜘蛛模型资产
- 研究结论已经表明：
  - 蜘蛛更适合作为 shared arthropod locomotion spine 的第一只正式生物
  - 龙虾适合作为第二只 profile consumer，而不是第二套系统
- 用户已经冻结了这轮的开发顺序与边界：
  - 先蜘蛛
  - 再龙虾
  - 两者都先做独立 lab
  - 暂不接入主世界
  - 但必须考虑未来可接入主世界

## Scope

本 PRD 只覆盖 `arthropod crawler locomotion labs`。

包含：

- 新增 shared arthropod locomotion spine
- 新增 `SpiderCrawlerLab.tscn`
- 新增 `LobsterCrawlerLab.tscn`
- 新增正式蜘蛛 species wrapper/runtime
- 新增正式龙虾 species wrapper/runtime
- 独立 lab HUD、debug state、reset contract
- 面向 future main-world port 的 wrapper / anchor / ground resolver 契约冻结
- 研究文档、计划文档、版本索引与 traceability
- headless world tests + lab e2e / focused verification 规划

不包含：

- 不做主世界正式接入
- 不做 task / pin / world ring / route / map 接入
- 不做 wall-walking / ceiling-walking 首版
- 不做蜘蛛吐丝、跳扑、攻击或敌对 AI
- 不做龙虾水下推进、尾部爆发逃逸或复杂流体模拟
- 不做生态系统、繁殖、觅食、捕猎与跨 session 持久化

## Non-Goals

- 不追求首版就做“主世界里会满城乱跑的多足生物”
- 不追求用手工动画 clip 冒充程序化爬行
- 不追求为蜘蛛和龙虾并行造两套 runtime
- 不追求把龙虾做成 sideways crab
- 不追求在没有 shared debug contract 的情况下直接调外观

## Requirements

### REQ-0026-001 系统必须先提供 shared arthropod locomotion spine

**动机**：这轮真正要沉淀的资产不是“蜘蛛脚本”或“龙虾脚本”，而是未来所有多足生物都能复用的 locomotion spine。

**范围**：

- 新增 shared runtime，最小 contract 至少包括：
  - `ArthropodLocomotionProfile`
  - `ArthropodLegRuntime`
  - `ArthropodFootholdResolver`
  - `ArthropodBodySolver`
  - `ArthropodDebugState`
- shared runtime 必须显式暴露：
  - gait phase
  - per-leg state
  - locked foothold
  - desired foothold
  - body target transform
  - failed foothold replans
- shared runtime 不得写死成蜘蛛专用路径或 8 腿专用常量；腿数量、相位表和步态参数必须由 profile 提供

**验收口径**：

- 自动化测试至少断言：shared locomotion spine 可在不依赖 species scene 的情况下实例化 profile 和 debug state。
- 自动化测试至少断言：profile 切换能改变 gait phase 口径，而不是 species 代码里偷偷写死。
- 反作弊条款：不得把 shared runtime 只写成一个空壳，再把所有逻辑塞回蜘蛛/龙虾 wrapper。

### REQ-0026-002 首个正式 consumer 必须是独立的 SpiderCrawlerLab

**动机**：蜘蛛是这轮 research / engineering / open-source reference 三者交集最大的物种，适合作为第一条正式落地链。

**范围**：

- 新增独立 lab 场景：
  - `res://city_game/scenes/labs/SpiderCrawlerLab.tscn`
- lab 场景至少 author：
  - 平地
  - 坡面
  - 低台阶
  - 窄梁或不连续落脚区
  - 玩家观察相机或等价 debug 视角
- 蜘蛛首版允许使用 proxy/blockout rig，只要 gait contract 成立
- Spider lab 必须复用 shared locomotion spine，不允许写 lab-only gait

**验收口径**：

- 自动化测试至少断言：Spider lab 能正常加载 scene root、crawler root、terrain fixtures、HUD/debug root。
- 自动化测试至少断言：lab 内 reset 后能恢复初始身体和脚点状态。
- 反作弊条款：不得只让身体在地上滑行，再用腿部循环动画伪装爬行。

### REQ-0026-003 蜘蛛必须先跑通正式 gait / foothold / terrain-follow contract

**动机**：蜘蛛之所以先做，不是因为模型名字叫 spider，而是因为它应当成为第一条真正可被测试锁住的多足 gait 主链。

**范围**：

- 首版蜘蛛 gait 冻结为：
  - 地面/坡面/低障碍 crawling
  - 不做 wall / ceiling inversion
- 每条腿最小状态冻结为：
  - `stance`
  - `lift`
  - `swing`
  - `plant`
- 首版必须实现：
  - stance 锁脚
  - 伸展阈值触发 replanning
  - foothold raycast 解析
  - body height / pitch / roll 补偿
  - limited concurrent swing legs
- 首版允许速度很慢，但不得退回纯根节点平移

**验收口径**：

- 自动化测试至少断言：蜘蛛在平地上能维持连续 gait，不会每帧所有脚一起换位。
- 自动化测试至少断言：蜘蛛经过坡面或低台阶时，至少部分 stance 脚点会跟随地形法线更新。
- 自动化测试至少断言：当单条腿找不到落脚点时，系统会做局部恢复而不是整体硬 reset。

### REQ-0026-004 龙虾必须作为同一 shared spine 的第二个 species profile 落地

**动机**：龙虾是本轮第二个明确目标，但它的价值恰恰在于验证 shared spine 真的可复用，而不是只能服务于蜘蛛。

**范围**：

- 新增独立 lab 场景：
  - `res://city_game/scenes/labs/LobsterCrawlerLab.tscn`
- 龙虾首版视觉优先复用：
  - `res://city_game/assets/environment/source/creatures/lobster_02.glb`
- 龙虾 gait 冻结为：
  - forward crawler
  - metachronal wave preference
  - 更低 body clearance
  - 更短 step height
- 螯足首版以姿态/轻量支撑为主，不承担主要推进职责

**验收口径**：

- 自动化测试至少断言：龙虾实例走的是 shared locomotion spine，而不是 `LobsterCrawlerLab.gd` 内部自写 gait。
- 自动化测试至少断言：龙虾 gait ordering 与蜘蛛不相同。
- 自动化测试至少断言：龙虾身体高度和步高 profile 明显低于蜘蛛。

### REQ-0026-005 `v39` 不接入主世界，但必须冻结 future main-world portability hooks

**动机**：如果现在不冻结 wrapper 口径，后续一旦接回主世界，极易再发明一套与 lab 不同的行为逻辑。

**范围**：

- 本轮文档必须明确 future port 最小契约：
  - world anchor
  - ground resolver
  - activation radius / chunk awareness
  - spawn / despawn policy
  - debug state passthrough
- 禁止把 future main-world consumer 设计成“直接加载整个 lab 场景”
- 禁止让主世界日后另起一套 locomotion runtime

**验收口径**：

- 计划文档和版本索引必须显式写出 `lab runtime == future main-world runtime` 的冻结条款。
- 自动化测试命名与 wrapper 规划中必须出现独立的 portability contract，而不是等主世界阶段再临时想。

### REQ-0026-006 必须同时具备 focused tests、debug state 与最小性能意识

**动机**：程序化多足 locomotion 非常容易在“看起来好像能动”阶段掩盖热路径问题。

**范围**：

- 至少规划以下 focused tests：
  - shared spine contract
  - spider lab scene contract
  - spider gait contract
  - spider terrain follow contract
  - lobster lab scene contract
  - lobster metachronal gait contract
  - portability contract
- 必须暴露只读 debug state，供测试直接断言
- 如果后续实现触及每帧多射线 / IK / body solve，必须为 lab 场景补 profiling 入口

**验收口径**：

- 不接受只靠手感或录屏宣称“步态成立”
- 不接受没有 debug state 的黑盒测试
- 不接受把性能问题推迟到主世界阶段再看
