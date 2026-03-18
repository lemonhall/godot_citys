# PRD-0017 Soccer 5v5 Match

## Vision

把 `godot_citys` 从“只有自由踢球的足球场馆”推进到“球场上真的能开赛的一套 5v5 足球对抗玩法”。`v27` 的目标不是把 `v26` 推成完整职业足球模拟，而是在现有 `scene_minigame_venue` 与同一颗 `v25` 足球之上，正式补出一层“比赛态”：球场上出现两支各 `5` 人的小队，红队与蓝队各有 `1` 名守门员与 `4` 名场上球员；比赛开始前所有人站位并播放 Idle；玩家走进记分牌旁的开赛圈后，比赛正式开始，HUD 显示 `5:00` 倒计时，球员开始按简单 AI 对抗，把球踢向对方球门；时间归零后按比分结算胜负；若玩家离开足球场冻结/释放圈，整场比赛立刻归位，比分与倒计时清零，球与球员全部回到初始站位。

`v27` 的成功标准不是“球场上多摆了 10 个会动的人”，也不是“用脚本把球随机推向某个门”。它必须同时满足六件事。第一，用户提供的 `Animated Human.glb` 必须被正式归置到足球比赛专用资产域，不能进入 `city_game/assets/pedestrians/civilians/` 或任何 ambient pedestrian manifest，可避免素体模型被刷到街道上。第二，`v26` 的足球场场馆必须增加一个正式的开赛 contract：记分牌旁存在一个复用 shared world ring 家族语义的 start ring，玩家进入后启动比赛，而不是自动开赛或靠调试命令开赛。第三，场上必须稳定存在红蓝两队共 `10` 名球员，且每队角色语义明确为 `goalkeeper + field_players`，未开赛与结算后播放 Idle，比赛中播放 locomotion 动画。第四，比赛启动后，HUD 必须显示正式 `5:00` 倒计时；时间归零时立即停止比赛并结算胜负。第五，AI 球员必须围绕同一颗正式足球运行，形成最小但真实的“站位 -> 追球 -> 触球 -> 朝对方球门踢 -> 守门员防守”的对抗闭环，而不是再生成第二颗隐藏比赛球，也不是按键直接改比分。第六，玩家若离开 `v26` 已冻结的足球场冻结/释放圈，整场比赛必须复位到 `0:0 / 5:00 / 中圈开球 / 双方回站位`，不允许把旧比分、旧倒计时或旧球员位置残留在世界里。

## Background

- `PRD-0015` 与 `v25` 已冻结同一颗正式足球 `prop:v25:soccer_ball:chunk_129_139` 的 interactive prop 身份、`E` 键踢球链与真实物理 impulse contract。
- `PRD-0016` 与 `v26` 已冻结足球场馆 `venue:v26:soccer_pitch:chunk_129_139`、两侧球门、goal detection、比分与 reset loop、大型场边计分板，以及 `ambient_simulation_freeze` 主链。
- `v26` 差异列表已明确：门将、队友、对手、比赛倒计时与完整比赛态不在 `v26` 范围内，属于后续版本。
- 用户已为 `v27` 明确补充以下口径：
  - 球场上要变成 `5v5`
  - 每队 `5` 人，其中 `1` 人守门员
  - 用户提供的白色男性素体模型用于统一球队视觉与着色
  - 一队红色、一队蓝色
  - 开赛前球员 Idle
  - 记分牌旁边存在“Task 的圈”式开赛圈
  - 玩家一旦站上去，比赛开始
  - 比赛采用 `5:00` 倒计时
  - 如果 Player 走出冻结圈，一切归位，比分归 `0`
  - 终场后球员停在赛场上 Idle 或 work；`v27` 首版冻结为 Idle
- 用户还明确否决了把该素体模型放到 `city_game/assets/pedestrians/civilians/` 的方案，因为这会让它进入街道行人资产池，违反“素体模型不能上街”的口径。

## Scope

本 PRD 只覆盖 `v27 soccer 5v5 match`。

包含：

- 把用户提供的 `Animated Human.glb` 归置到足球比赛专用资产路径
- 为足球比赛新增与 ambient pedestrians 隔离的球员视觉封装
- 在现有 `v26` 足球场馆中 author `5v5` 球队站位、角色与开赛圈
- 比赛启动前的 Idle 阶段、比赛中的简单移动/追球/踢球 AI、终场后的 Idle 停留
- HUD `5:00` 倒计时
- 终场胜负判定与记分牌胜方高亮
- 玩家离开冻结/释放圈时的整场复位
- 补齐 `asset / start ring / countdown / roster / reset / final result / e2e` 回归测试

不包含：

- 不做 `11v11`、替补席、换人、阵型编辑、战术面板
- 不做越位、犯规、裁判、角球、任意球、点球、红黄牌
- 不做专门踢腿动画、射门动画或脚部 IK
- 不做观众、解说、欢呼音效、联网或本地多人
- 不做把比赛接入任务系统、full map pin 或 minimap pin
- 不做把该素体加入 ambient pedestrian manifest
- 不做复杂球员碰撞博弈或物理抢断系统

## Non-Goals

- 不追求把 `v27` 做成完整职业足球模拟
- 不追求为了“看起来热闹”把素体模型塞进街道行人池
- 不追求通过直接改比分、瞬移球或隐藏第二颗球来冒充 AI 对抗
- 不追求复用 task runtime 本身来承载比赛，只复用开赛圈的 shared world ring 视觉 family
- 不追求把比赛状态散落进 `CityPrototype.gd` 的更多特判

## Requirements

### REQ-0017-001 用户提供的素体模型必须被正式归置到足球比赛专用资产域，且不得进入街道行人资产池

**动机**：用户已经明确否决把该模型放入 `civilians`，因为那会把素体误用到街道行人系统。

**范围**：

- 根目录 `Animated Human.glb` 必须迁移到正式项目资产路径
- 该路径不得位于 `city_game/assets/pedestrians/civilians/`
- 该模型不得被加入 `city_game/assets/pedestrians/civilians/pedestrian_model_manifest.json`
- 足球比赛必须通过单独的 player scene / wrapper 使用该模型，而不是复用 ambient pedestrian model catalog
- 足球比赛 consumer 的最小资产 contract 至少冻结：
  - `source_model_path`
  - `team_color_id`
  - `idle_animation_name`
  - `run_animation_name`

**非目标**：

- 不要求 `v27` 首版让该模型被其他场馆或任务系统复用
- 不要求 `v27` 首版把该模型抽成全局 playable humanoid 标准资产

**验收口径**：

- 自动化测试至少断言：根目录 `Animated Human.glb` 不再作为正式运行时资产入口。
- 自动化测试至少断言：正式足球比赛资产路径不位于 `city_game/assets/pedestrians/civilians/`。
- 自动化测试至少断言：`pedestrian_model_manifest.json` 不包含该模型。
- 自动化测试至少断言：足球比赛球员 scene 通过独立 wrapper 使用该模型，并暴露 team color / animation contract。
- 反作弊条款：不得把模型移进 `civilians` 后再靠“测试时不抽到它”来宣称隔离完成；不得继续直接引用根目录 `glb` 作为正式运行时入口。

### REQ-0017-002 足球场馆必须提供正式可触发的开赛圈与 `5:00` 倒计时比赛启动 contract

**动机**：用户明确要求“记分牌旁边设置 Task 的圈，Player 一旦站上去就开赛”，并要求正式 `5:00` 倒计时。

**范围**：

- `v26` 足球场馆必须新增一个开赛圈
- 开赛圈必须位于记分牌旁边的稳定可达位置
- 开赛圈必须复用 shared world ring marker family 的视觉语义，而不是另做第三套圈效果
- 比赛最小状态冻结为：
  - `idle`
  - `countdown_ready`
  - `in_progress`
  - `final`
  - `resetting`
- 玩家进入开赛圈时，比赛进入 `countdown_ready` 或直接 `in_progress`；`v27` 冻结为直接 `in_progress`
- 比赛启动后，HUD 必须显示 `5:00` 倒计时，并按真实时间递减
- 倒计时归零时，比赛必须立即进入 `final`

**非目标**：

- 不要求 `v27` 首版做中场休息、上下半场或补时
- 不要求 `v27` 首版做发令哨音或开赛动画

**验收口径**：

- 自动化测试至少断言：mounted venue 暴露 start ring contract，且其世界位置邻近记分牌。
- 自动化测试至少断言：Player 进入 start ring 后，比赛状态切到 `in_progress`，而不是停留在 `idle`。
- 自动化测试至少断言：比赛启动后 HUD 状态中存在 `05:00` 初始倒计时。
- 自动化测试至少断言：随着 runtime 推进，倒计时会递减；归零时比赛状态切到 `final`。
- 反作弊条款：不得把“开赛”实现成调试命令专用入口；不得只在记分牌 world label 更新倒计时、却让 HUD 没有正式时间限制视图。

### REQ-0017-003 场馆必须稳定呈现红蓝两队各 5 人的正式阵容与角色 contract

**动机**：用户要的是“球场上有一支红队和一支蓝队在打比赛”，不是几个匿名 dummy 在乱跑。

**范围**：

- 场馆内必须正式生成两队：
  - `home_team` / `red`
  - `away_team` / `blue`
- 每队必须恰好 `5` 人：
  - `1` 名 `goalkeeper`
  - `4` 名 `field_player`
- 每个球员至少暴露以下 contract：
  - `player_id`
  - `team_id`
  - `role_id`
  - `home_anchor`
  - `world_position`
  - `animation_state`
  - `tint_color`
- 未开赛时全队站在冻结站位并播放 Idle
- 比赛结束后全队停在球场上并播放 Idle
- 红蓝两队必须可从视觉上一眼区分

**非目标**：

- 不要求 `v27` 首版做不同身高、不同体型或不同装备
- 不要求 `v27` 首版做球衣纹理、号码、名字或守门员特殊服装

**验收口径**：

- 自动化测试至少断言：mounted venue 中存在 `10` 名正式球员节点。
- 自动化测试至少断言：每队人数都是 `5`，且各自包含恰好 `1` 名 `goalkeeper`。
- 自动化测试至少断言：未开赛时全部球员处于 Idle 动画状态。
- 自动化测试至少断言：红队与蓝队的 tint color contract 稳定存在且互不相同。
- 反作弊条款：不得只在测试里伪造 `roster_state` 字典却不真正生成球员节点；不得让 `goalkeeper` 只是名字里带“keeper”的普通球员。

### REQ-0017-004 比赛中的 10 名球员必须围绕同一颗正式足球运行简单对抗 AI，并通过真实 kick impulse 影响比赛

**动机**：用户要的是“互相对抗将足球踢进对方门框里”，不是观赏型站桩摆拍。

**范围**：

- 所有 AI 必须围绕 `prop:v25:soccer_ball:chunk_129_139` 这一颗正式足球运行
- 最小 AI 语义冻结为：
  - 场上球员会回到本方基础站位
  - 距球最近或被选中的球员会追球
  - 贴近足球后会朝对方球门施加 kick impulse
  - 守门员会优先守住本方门前区域并拦截接近球门的球
- 比赛 AI 至少需要输出：
  - `intent_kind`
  - `move_target`
  - `kick_requested`
  - `look_target`
- AI 触球不得通过直接改比分实现
- AI 进球与失球必须继续复用 `v26` 的 goal detection / scoreboard / reset loop

**非目标**：

- 不要求 `v27` 首版做传球战术、抢断、铲球、门将扑救动画或复杂队形算法
- 不要求 `v27` 首版让 AI 识别越位、犯规或界外球规则

**验收口径**：

- 自动化测试至少断言：比赛开始后，至少有球员会从初始站位切到 locomotion 动画并接近足球。
- 自动化测试至少断言：AI 对足球的有效触球会改变同一颗正式足球的线速度或轨迹。
- 自动化测试至少断言：守门员的 home zone 靠近本方球门，而不是和普通场上球员完全等价。
- 自动化测试至少断言：AI 进球后，`v26` 既有比分/重置链仍然工作。
- 反作弊条款：不得生成第二颗隐藏比赛球；不得把 AI 进球实现成直接改 `home_score/away_score`；不得只播放跑步动画而没有任何可观测的追球/踢球决策。

### REQ-0017-005 终场与出圈必须形成正式的结算/复位闭环

**动机**：用户明确要求“如果 Player 走出冻结圈，一切归位，比分归 0”，并询问了正式赛制与终场表现。

**范围**：

- 比赛赛制冻结为：
  - `5:00` 倒计时
  - 时间归零时，进球数高的一方获胜
  - 若双方同分，则为 `draw`
- 终场后：
  - 比赛停止
  - 计分牌保留最终比分
  - 胜方比分上显示红圈高亮；平局不高亮
  - 球员停在球场上 Idle
- 玩家若离开足球场的冻结/释放圈：
  - 比赛立即进入 `resetting`
  - 比分清零
  - 倒计时恢复 `5:00`
  - 球回到 kickoff
  - 10 名球员回到初始站位并转为 Idle

**非目标**：

- 不要求 `v27` 首版保留历史赛果或跨 session 战绩
- 不要求 `v27` 首版做胜利庆祝、失败沮丧或平局鼓掌动作

**验收口径**：

- 自动化测试至少断言：当倒计时归零且一方领先时，比赛状态切到 `final` 且 winner side 正确。
- 自动化测试至少断言：胜方比分高亮 contract 会同步到 world scoreboard。
- 自动化测试至少断言：若比分相同，比赛状态显示 `draw`，双方不高亮。
- 自动化测试至少断言：玩家离开冻结/释放圈后，比分归 `0`、倒计时恢复 `05:00`、球与球员全部回初始站位。
- 反作弊条款：不得只重置 HUD 数字却保留旧球员位置；不得只清零比分却保留已运行的终场状态。

### REQ-0017-006 `v27` 不得破坏现有 `v25/v26` 足球与场馆主链，也不得误伤 ambient freeze / radio / streaming 纪律

**动机**：比赛层是叠加在 `v26` 之上的，不允许为了做 5v5 把场馆基础版、收音机或 streaming 主链再打坏一次。

**范围**：

- `v25` 足球 `E` 键交互与正式 physics kick 继续成立
- `v26` goal detection / scoreboard / reset / ambient freeze 继续成立
- `ambient_simulation_freeze` 继续只冻结 crowd / ambient vehicles，不得波及 radio
- `scene_minigame_venue` 仍走既有 registry -> manifest -> mount 主链
- 如改动触及 HUD、runtime tick、chunk mount 或 renderer sync，必须接受相关 guard 验证

**非目标**：

- 不要求 `v27` 首版关闭 ambient freeze 再做独立 bubble 系统
- 不要求 `v27` 首版解决仓库里其他非足球历史 debt

**验收口径**：

- 受影响的 `v25` 足球 interaction tests 必须继续通过。
- 受影响的 `v26` 足球场 tests 必须继续通过。
- 新增 `v27` tests 与至少一条 e2e 流程必须通过。
- 如触及 mount / tick / HUD / renderer sync，fresh closeout 仍需串行跑 profiling 三件套。
- 反作弊条款：不得通过关闭旧足球交互、关闭 ambient freeze、关闭场馆 runtime 或停掉 radio 来换取 `v27` 表面通过。

## Open Questions

- 红圈高亮是否后续替换成更复杂的胜利动画。当前答案：`v27` 首版不做，先冻结成静态红圈。
- 球员是否需要和 Player 发生完整实体碰撞。当前答案：允许作为实现细节渐进增强，但 `v27` 验收先看 AI 追球/踢球/守门与可视闭环，不强行冻结完整身体对抗。
- 终场后球员是否切换成 `work` 动画。当前答案：`v27` 首版冻结为 Idle，避免引入额外动画依赖。

## Future Direction

- `v28` 可继续把 `v27` 的 5v5 基础版扩成更像正式比赛的小队足球，包括更细的队形、传球、门将扑救和更稳定的射门选择。
- 如果未来需要把开赛圈接到任务系统或地图入口，应单独立项，而不是把 `v27` 的自由开赛 contract 回写成任务主链。
- 更复杂的规则、观众、多人联机或比赛历史系统都应单独立项，不允许反向污染 `v27` 的极简比赛态。
