# 2026-03-18 V27 Soccer 5v5 Match Design

## 方案选择

围绕“在 `v26` 球场上做出一套 5v5 足球赛”，这里其实有三条路。方案 A 是把素体模型直接并入 `city_game/assets/pedestrians/civilians/`，然后试图复用 ambient pedestrian renderer 与 tier controller，把路人的人形资产借到球场。它表面上省代码，但用户已经明确否决了这条路，因为 `civilians` 语义就是“可能刷到街上”，而素体模型不能上街。一旦进 manifest，哪怕今天测试没抽到，明天任何 pedestrian seed 变化都可能把它刷进城市。方案 B 是继续沿 `v26` 场馆主链扩展，在足球场馆内部 author 一套足球专用球员 wrapper、match roster 与开赛圈，把模型留在 `soccer/minigame` 独立资产域。方案 C 是再新开一条“比赛 feature family”，把 5v5 作为和场馆并列的新 world feature。综合范围、复用和风险，`v27` 推荐方案 B。它既复用了 `v26` 已经存在的球门、比分、reset 与 ambient freeze 主链，又不会把资产语义搞混，也不至于为了一套 5v5 重新发明第二套 registry family。

## 为什么要继续扩展 `CitySoccerVenueRuntime`

`v26` 已经把足球场馆需要的基础运行时收口在 `CitySoccerVenueRuntime.gd`：同一颗正式足球绑定、goal detection、比分、重置、ambient freeze，以及 score state 到 world scoreboard 的同步。`v27` 增加的比赛态并不是另一个独立小游戏，它恰恰就是这套 runtime 的上层状态机。如果现在另外创建一条 parallel runtime，只负责 `5v5` 的倒计时、AI 和开赛圈，那么比分、球重置和 ambient freeze 就会被拆成两层彼此调用的状态机，很快就会出现“一个 runtime 认为比赛结束，另一个 runtime 认为球还在比赛中”的错位。因此 `v27` 更合理的做法，是继续扩展 `CitySoccerVenueRuntime` 作为唯一比赛真源，再把球员意图计算拆给 helper，比如 `CitySoccerMatchRoster.gd` 或 `CitySoccerMatchPlayerAgent.gd`。这样球门、倒计时、AI、HUD、记分牌和出圈 reset 全部共享一个正式 state snapshot，测试也只需要盯一条主链，而不是在两个 runtime 之间来回猜测谁是真相。

## 球员资产与视觉封装

用户给的 `Animated Human.glb` 是白色男性素体，正好适合作为红蓝两队的统一底模。关键不是“能不能加载”，而是“如何保证它永远不会跑到街道上”。所以 `v27` 推荐把它归到 `city_game/assets/minigames/soccer/players/animated_human.glb` 这种足球专用资产域，再为它建一个独立的 player wrapper scene。这个 wrapper 只服务足球场：它会递归找到动画播放器，暴露 `idle_animation_name` 与 `run_animation_name`，并在运行时对 mesh 实例统一施加 team tint。由于模型本身是全白，红蓝着色不需要复杂贴图系统，直接 material override 就能得到稳定、可测的队伍区分。wrapper scene 还负责把“当前动画状态”标准化成 `idle / run` 两档，避免 AI 侧直接依赖 glb 内部节点名字。这样一来，球员视觉层就只做三件事：挂载模型、播动画、着色；比赛逻辑仍然待在 soccer runtime 里。层次清楚之后，后面不管是换成更好的球员模型，还是给守门员换另一种 tint，都是替换足球专用资产，不会碰 ambient pedestrian catalog。

## 开赛圈与 HUD 倒计时

用户要求“记分牌旁边有个 Task 的圈，Player 站上去就开赛”，这其实已经暗示了实现边界：要复用 shared world ring marker 的视觉 family，但不应该把足球赛伪装成 task。本质上，这个 start ring 只是一个场馆局部 trigger。`v27` 推荐把它做成 venue scene 中的正式 contract：固定在记分牌旁、半径稳定、默认主题使用 `task_available_start`，由 `CitySoccerVenueRuntime` 检测 Player 是否进入。这样玩家会得到和任务起始圈相似的视觉感知，但逻辑上仍然是“足球场开赛圈”，不是 task slot。比赛一旦开始，HUD 就必须出现正式的 match overlay，至少包含：`红队比分`、`蓝队比分` 与 `05:00` 倒计时。这里不建议把时间只塞回记分牌 world label，因为用户明确说“在游戏画面上显示倒计时”，这就是 HUD contract。实现上最好在 `PrototypeHud.gd` 里新增一块 soccer match state，而不是复用短时 `focus_message`。因为倒计时是持续状态，不是 toast。只要 HUD state 与 `CitySoccerVenueRuntime` 使用同一份 `match_clock_text / match_state / winner_side` snapshot，终场时 HUD 与记分牌就不会分叉。

## AI 设计：要像比赛，不要假装比赛

`v27` 首版不需要复杂战术，但也不能只有 10 个会跑步的装饰人。推荐把 AI 冻结成一套明确但简单的职责分层。每队 `1` 名守门员固定守住本方门前区域，优先回防门线与球门中轴；`4` 名场上球员共享“基础站位 + 追球 + 踢球”语义：没有球权时回到本方 home anchor 附近保持队形，离球最近的候选人切成追球者，贴近足球时对着对方球门施加真实 kick impulse。这样比赛的最小视觉闭环就成立了：队伍会铺开、会有人上抢、会有人往球门方向出脚，守门员也会显得和场上球员不一样。更重要的是，这个设计继续复用 `v25/v26` 的同一颗正式足球和 goal detection，不新造隐藏球，也不直接写比分。终场时则把所有 AI 停回 Idle，不做庆祝/懊恼动画，守住 `v27` 的 scope。

## 终场与出圈复位

用户额外给出的“如果 Player 走出冻结圈，一切归位，比分归 0”其实比终场规则更重要，因为它决定了比赛是不是一个稳定、可重复进入的小游戏。`v26` 已经有 `ambient_simulation_freeze` 的双圈层语义，所以 `v27` 最稳妥的做法是直接把“比赛有效归属”建立在这条圈层语义上：Player 仍在冻结/释放圈内，比赛可以继续；一旦完全离开该圈，比赛立即进入 `resetting`，比分清零、倒计时回 `05:00`、球回 kickoff、红蓝双方全部回到初始站位并转回 Idle。这样用户下次走回来，再站上 start ring，就会得到一场完全新的比赛，不会继承上次的脏状态。终场结算也要保持同一套 discipline：倒计时归零时比较 `home_score / away_score`，生成 `winner_side`；若有胜方，就在记分牌对应分数外画红圈；若平局则显示 `DRAW` 且不高亮。球员终场后停在场上 Idle，形成一种“比赛刚刚结束”的稳定场面，而不是立刻清场或继续乱跑。

## 测试策略

`v27` 的测试必须比 `v26` 更讲究状态可重复，因为有倒计时与 AI。第一层是 asset isolation test，直接卡住“素体不能进 `civilians`”。第二层是 roster/start contract，验证 mounted venue 里确实存在 `10` 名球员、红蓝队与守门员语义、以及记分牌旁开赛圈。第三层是 countdown contract，验证 `05:00` 初始 HUD 状态、倒计时递减与归零后的 `final`。第四层是 AI kick contract，不要求 AI 在纯自动条件下稳定踢出漂亮比赛，但必须证明它们真的能对同一颗正式足球施加 kick impulse。第五层是 final/reset contract，验证 winner highlight 与玩家出圈后的全量归位。最后才是 e2e，把“走到开赛圈 -> 比赛进行 -> 倒计时推进 -> 终场或出圈 reset”串成一条自动化流程。所有这些都必须守住 `v25` 足球 interaction 和 `v26` 场馆 tests，不允许为了做 5v5 把既有足球链路打断。
