# PRD-0010 NPC Interaction And Dialogue

> 2026-03-16 口径修正：本 PRD 覆盖的是“任何被显式配置为可交互的 NPC”，不是“仅限功能建筑里的 NPC”；咖啡馆服务员只是首个 consumer。

## Vision

把城市里“可交互 NPC”正式收口成一条可复用的近距交互链，而不是每个 NPC 各写一套临时逻辑。玩家接近某个可交互 NPC 到 `5m` 内时，画面上会稳定出现“可以按下 `E` 键交互”的提示；玩家按下 `E` 后，系统进入正式的对话态，并把该 NPC 的对话内容呈现出来。第一批交付的用户价值不是“已经有完整商业系统”，而是先把 `接近 -> 提示 -> 按 E -> 对话` 这条主链在真实城市场景里跑通，并且让未来更多 NPC 直接复用。

`v17` 的成功标准有四条。第一，近距提示是正式 runtime contract，不是只对某一个咖啡馆服务员写死的特判。第二，`E` 键交互必须有明确 ownership，不得和当前车辆 `F` 键交互链打架。第三，对话 runtime 必须是一个正式子系统，至少具备 `idle / active` 状态、speaker 文本与关闭行为。第四，首个 consumer 虽然先挂在 `v16` 导出的咖啡馆服务员身上，但整条 contract 必须从一开始就能服务于未来任意被显式配置为可交互的 NPC。

## Background

- `v16` 已经把功能建筑场景正式挂回城市；咖啡馆服务员现已存在于 `003` 号服务化场景中，可作为 `v17` 的首个 consumer。
- 当前仓库已有成熟的 `PrototypeHud.set_focus_message()` Toast 能力，但还没有“持续显示的近距交互提示”。
- `CityPrototype` 里已经有正式 `_unhandled_input()` 分发链，也已有车辆 `F` 键交互 contract，可作为输入 ownership 参考。
- 当前仓库没有正式的 NPC 交互 runtime，也没有通用对话 runtime；如果继续在某个具体场景里堆临时脚本，后续每个可交互 NPC 都会重新分叉。

## Scope

本 PRD 只覆盖 `v17 NPC interaction and dialogue`。

包含：

- 为任何被显式配置为可交互的 NPC 建立正式 contract
- 玩家距离某个可交互 NPC `5m` 内时显示持续性的 `E` 键交互提示
- 玩家按 `E` 时进入通用对话 runtime
- 首个对话 consumer 为咖啡馆服务员，默认台词为“你想喝点什么？”
- 对话 UI 至少显示：speaker、正文、关闭/继续提示
- 未来任意被显式配置为可交互的 NPC 都可复用同一套交互/对话 contract，而不是只服务于咖啡馆

不包含：

- 不在 `v17` 内交付商品库存、结算、金钱系统
- 不在 `v17` 内交付多轮分支树、任务接取树、语音或 lip-sync
- 不在 `v17` 内交付复杂寻路、排队或 NPC 自主行为
- 不在 `v17` 内交付整城级别的对话内容制作工具

## Non-Goals

- 不追求把 `v17` 做成完整商店系统
- 不追求给所有已有行人立即自动接入交互
- 不追求通过每帧扫描全城 NPC、或把提示硬编码进 HUD 文本来宣称完成
- 不追求把车辆 `F` 键交互退化或挤占成通用交互键

## Requirements

### REQ-0010-001 系统必须为近距可交互 NPC 提供正式的 `5m / E` 提示 contract

**动机**：如果提示链只靠某个场景局部脚本或某条临时文本，未来可交互 NPC 就无法复用。

**范围**：

- 被显式配置为可交互的 NPC 必须具备正式 interaction contract，至少包含：
  - `actor_id`
  - `display_name`
  - `interaction_kind`
  - `interaction_radius_m`
  - `dialogue_id` 或等价对话入口
- 玩家进入 `5m` 内时，HUD 必须显示持续性的“可以按下 `E` 键交互”提示
- 若多个候选同时存在，只允许最近的一个拥有显示权
- 玩家离开范围、打开不兼容 UI、或进入对话态后，提示必须隐藏

**非目标**：

- 不要求当前版本做 LoS 遮挡裁定
- 不要求当前版本支持群体同时提示

**验收口径**：

- 自动化测试至少断言：在 `5m` 外不显示提示，进入 `5m` 内后显示提示。
- 自动化测试至少断言：多个候选同时存在时，只显示最近 actor 的提示。
- 自动化测试至少断言：提示是持续状态，不是一次性 Toast。
- 反作弊条款：不得通过把提示写死在 HUD、无视距离、或只给咖啡馆服务员写专门分支来宣称完成。

### REQ-0010-002 系统必须在 `E` 键下建立正式的 NPC 交互 ownership，并进入通用对话 runtime

**动机**：没有正式 ownership，未来 `E / F / map / dialogue` 一定会互相打架。

**范围**：

- `E` 是 NPC 近距交互正式键位
- 只有当存在当前 active interaction candidate 时，按 `E` 才允许进入对话
- 对话 runtime 至少具备：
  - `idle / active` 状态
  - 当前 actor / speaker 信息
  - 当前正文
  - 关闭或继续输入
- 对话打开后，近距提示必须隐藏，`E` 的所有权转给对话 runtime
- 当前车辆 `F` 键交互 contract 不能回退

**非目标**：

- 不要求 `v17` 现在就做多轮分支或选择后果
- 不要求 `v17` 现在就做完整输入锁与时间暂停

**验收口径**：

- 自动化测试至少断言：无 active NPC candidate 时按 `E` 不会错误打开对话。
- 自动化测试至少断言：有 active NPC candidate 时按 `E` 会进入 `active` 对话态。
- 自动化测试至少断言：对话打开后，HUD 提示隐藏，关闭后才重新回到提示态。
- 自动化测试至少断言：车辆 `F` 键交互链继续成立。
- 反作弊条款：不得通过只弹一个 Toast、只打印日志、或用同步 blocking modal 把世界卡住来宣称完成。

### REQ-0010-003 咖啡馆服务员必须成为首个真实 consumer，并说出“你想喝点什么？”

**动机**：如果没有真实 consumer，通用 runtime 很容易沦为空壳；但首个 consumer 不能反向把整条 contract 收窄成“只给这一个 NPC 用”。

**范围**：

- `v16` 咖啡馆服务员必须挂入正式 interaction contract，作为首个真实 consumer
- 玩家靠近服务员时显示 `E` 提示
- 玩家按 `E` 后，对话 UI 至少显示：
  - speaker 名称
  - 文本 “你想喝点什么？”
  - 关闭/继续提示
- 服务员必须继续保持 idle 待机，不因接入交互而丢失场景表现

**非目标**：

- 不要求当前版本完成点单结果处理
- 不要求当前版本给服务员加入语音或表情动画

**验收口径**：

- 自动化测试至少断言：咖啡馆服务员具备 interaction/dialogue metadata。
- 自动化测试至少断言：进入服务员近距范围后，按 `E` 可以打开对话。
- 自动化测试至少断言：对话正文包含“你想喝点什么”。
- 反作弊条款：不得通过把这句台词写进 world 启动提示、或用无 NPC 绑定的假对话框来宣称完成。

### REQ-0010-004 `v17` 不得破坏现有 v16 服务化场景、车辆交互与性能红线

**动机**：NPC 交互是扩展链路，不是允许回退现有主链的豁免。

**范围**：

- `v16` 咖啡馆场景 contract 继续成立
- 车辆 `F` 键交互 contract 继续成立
- 新增近距候选求解不得退化成每帧全城扫描
- 受影响 profiling guard 仍需串行通过

**非目标**：

- 不要求 `v17` 重写整套 HUD 或 pedestrian runtime
- 不要求 `v17` 给所有近景 pedestrian 自动接交互

**验收口径**：

- 受影响的 `v16` 场景 contract tests 必须继续通过。
- 受影响的车辆交互 tests 必须继续通过。
- 新增 `v17` world/e2e tests 必须通过。
- 串行运行 `test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 仍需过线。
- 反作弊条款：不得通过 profiling 时禁用 NPC 提示扫描、禁用对话 UI、或把近距交互改成手动脚本调用来宣称达标。

## Open Questions

- `v17` 是否要求多轮分支选择。当前答案：不要求，先冻结为单轮 opening line + close。
- `v17` 是否要求对话打开时冻结玩家移动。当前答案：不要求，先只冻结 `E` ownership 与 HUD 提示 ownership。
