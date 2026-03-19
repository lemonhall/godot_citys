# PRD-0019 Missile Command Defense Minigame

## Vision

把 `godot_citys` 从“城市里已经有球类 minigame”推进到“城市里第一次出现正式的防空反应类 minigame”。`v29` 的目标不是做一把新的武器，也不是在天空里随便刷几个目标让玩家打靶，而是在用户指定的 `chunk_183_152` 上 author 一座真正的 `Missile Command` 风格防空电池：玩家走进开赛圈后切到固定炮台玩法态，用左键向准星落点发射拦截弹，靠爆炸圈击毁一波又一波落向城市与发射井的敌方弹头。由于当前项目是第三人称开放世界原型，`v29` 冻结为 **3D arcade defense mode**：场景仍然存在于真实世界里，但玩法逻辑冻结在一张正式的防空平面上，避免为了“看起来更三维”而把拦截、爆炸链和选井语义打散。

`v29` 的成功标准不是“这个位置多了一块军事平台”，也不是“左键时能往天上放一个球”。它必须同时满足六件事。第一，仓库必须正式拥有 `venue:v29:missile_command_battery:chunk_183_152` 这条 authored 入口，并继续走 `scene_minigame_venue` registry -> manifest -> near chunk mount 主链，而不是再发明一条隐藏 family。第二，场馆必须显式暴露防空平面、三座发射井、三座被保护城市、开赛圈、玩法相机与 release bounds 等正式 contract，而不是靠代码里的魔法坐标。第三，玩家进入开赛圈后必须切到正式玩法态：左键发射、右键 zoom、`Q` 切换发射井、`Esc` 退出玩法态；这里不能继续把主动作绑定成“反复按 `E`”。第四，战斗必须保住 `Missile Command` 的最小骨架：敌方弹头成波下落、当前发射井向指定落点发射拦截弹、拦截弹到点生成持续爆炸圈、爆炸圈能链式摧毁敌弹、城市全灭则失败。第五，场馆必须同时提供世界空间记分牌与正式 HUD summary，让玩家始终知道当前波次、剩余城市、当前发射井与弹药。第六，`v29` 不能为了做防空玩法打坏 `v26/v28` 已冻结的足球/网球 minigame 聚合链；`CityPrototype` 需要从“两套 sport runtime 聚合”提升成“三套 minigame runtime 聚合”，而不是让防空玩法绕开正式入口。

## Background

- `PRD-0016` 与 `v26` 已冻结 `scene_minigame_venue` family、registry/runtime、场馆 near mount 与 ambient freeze 聚合主链。
- `PRD-0018` 与 `v28` 已证明 minigame venue 不只能做“走进范围 -> E 交互”的球类玩法，也能承载正式状态机、HUD、世界计分板与 authored actor/camera contract。
- 用户本轮给定的锚点为：
  - `chunk_id = chunk_183_152`
  - `world_position = (11925.63, -4.74, 4126.84)`
  - `surface_normal = (-0.01, 1.00, -0.00)`
- 用户已冻结输入口径：
  - 左键：发射拦截弹
  - 右键：画面放大
  - 单独按键：切换发射井
  - `Esc`：退出玩法态
- 经典 `Missile Command` 的稳定玩法骨架可以概括为：
  - 保护地面城市/基地
  - 敌弹成波下落
  - 当前发射井向指定落点发射拦截弹
  - 爆炸圈链式击毁
  - 城市耗尽即失败

## Scope

本 PRD 只覆盖 `v29 missile command defense minigame`。

包含：

- 新增正式 minigame venue：
  - `venue:v29:missile_command_battery:chunk_183_152`
- 在用户指定锚点 author 一座防空电池场馆
- 三座发射井、三座被保护城市、开赛圈、固定玩法相机、世界记分牌
- 玩家进入开赛圈后自动进入防空玩法态
- 正式 `left click / right click / Q / Esc` 输入合同
- 正式敌弹波次、拦截弹、爆炸圈、链式击毁、城市/发射井毁伤
- HUD / 世界记分牌 / full map pin
- `CityPrototype` 的 minigame runtime / HUD / crosshair / 输入聚合扩展
- 补齐 manifest / venue contract / mode contract / wave contract / e2e 测试

不包含：

- 不做联网排行榜、任务接入、剧情、成就
- 不做真实军事模拟、雷达系统、弹道学细分
- 不做自由步行射击版火箭筒玩法
- 不做独立 UI mini app 或脱离世界的二维全屏游戏
- 不做新的 interactive prop family consumer
- 不做复杂音效系统、BGM、旁白与过场动画

## Non-Goals

- 不追求复刻原街机的全部计分、奖励城市和结束加算细则
- 不追求真正三维球形战场；玩法平面稳定性优先于伪复杂空间感
- 不追求把场景逻辑塞进 `CityPrototype.gd` 巨石
- 不追求把输入继续退化成“站在原地按 E”
- 不追求通过 HUD 假装有敌弹和爆炸，实际没有正式 runtime object

## Requirements

### REQ-0019-001 系统必须在用户给定锚点落成正式的 Missile Command 场馆 authored 入口

**动机**：用户要的是一座正式存在于世界里的 minigame 场馆，不是一段只在运行时临时拼出来的脚本。

**范围**：

- 正式新增 `venue:v29:missile_command_battery:chunk_183_152`
- 继续走 `scene_minigame_venue` registry -> manifest -> near chunk mount 主链
- manifest 最小字段至少包含：
  - `venue_id`
  - `display_name`
  - `feature_kind`
  - `game_kind`
  - `anchor_chunk_id`
  - `anchor_chunk_key`
  - `world_position`
  - `surface_normal`
  - `scene_root_offset`
  - `scene_path`
  - `manifest_path`
  - `full_map_pin`
- `game_kind` 在 `v29` 冻结为 `missile_command_battery`
- full map pin 必须有正式 `icon_id`

**非目标**：

- 不要求 `v29` 首版支持多个防空场馆同时开局

**验收口径**：

- 自动化测试至少断言：registry / manifest / scene path 三者口径一致。
- 自动化测试至少断言：`chunk_183_152` near mount 后能找到正式 venue 节点。
- 自动化测试至少断言：full map pin 能从 scene minigame venue manifest pipeline 暴露出来。
- 反作弊条款：不得把场馆挂成 landmark；不得只在代码里硬编码一个不存在 manifest 的 battery。

### REQ-0019-002 场馆必须暴露正式的防空平面、发射井、城市与玩法相机 contract

**动机**：没有稳定 contract，后续的瞄准、发射、毁伤、相机和测试都会退化成脆弱魔法数字。

**范围**：

- 场馆必须 author：
  - `GameplayPlaneAnchor`
  - `BatteryCameraPivot`
  - `BatteryCamera`
  - `LaunchSiloLeftAnchor`
  - `LaunchSiloCenterAnchor`
  - `LaunchSiloRightAnchor`
  - `CityTargetLeftAnchor`
  - `CityTargetCenterAnchor`
  - `CityTargetRightAnchor`
  - `MatchStartRing`
  - `Scoreboard`
- 最小 battery contract 冻结为：
  - `gameplay_plane_origin`
  - `gameplay_plane_half_width_m`
  - `gameplay_plane_height_m`
  - `camera_world_position`
  - `camera_look_target`
  - `start_ring_world_position`
  - `trigger_radius_m`
  - `release_buffer_m`
  - `silo_ids`
  - `city_ids`
- 场馆必须暴露每个 silo/city 的世界坐标 contract
- 场馆必须能在运行时切换 silo / city 视觉状态，不允许只有数据没有视觉载体

**非目标**：

- 不要求 `v29` 首版使用高模军事资产

**验收口径**：

- 自动化测试至少断言：正式 battery contract 存在且字段齐全。
- 自动化测试至少断言：三座 silo 与三座 city 都有正式 ID 和世界坐标。
- 自动化测试至少断言：场馆暴露玩法相机，而不是复用玩家自由视角强行拼凑。
- 反作弊条款：不得把 gameplay plane / camera / silo / city 坐标只藏在 runtime 常量里。

### REQ-0019-003 玩家进入开赛圈后必须切入正式的炮台防空玩法态

**动机**：这是本轮用户明确冻结的交互边界；如果不切玩法态，左键/右键与第三人称战斗输入会直接冲突。

**范围**：

- 玩家进入 start ring 后自动进入 `battery_mode_active`
- 玩法态期间：
  - 禁用人物移动控制
  - 切换到场馆 `BatteryCamera`
  - 保持鼠标捕获
  - 左键发射拦截弹
  - 右键 hold zoom
  - `Q` 循环切换当前发射井
  - `Esc` 退出玩法态
- 退出玩法态后：
  - 恢复玩家控制
  - 恢复玩家 camera
  - 隐藏 missile HUD
- 必须存在 formal request API 供 headless 测试触发同一条输入链：
  - `request_missile_command_primary_fire()`
  - `request_missile_command_fire_at_world_position(world_position)`
  - `cycle_missile_command_silo()`
  - `set_missile_command_zoom_active(active)`
  - `exit_missile_command_mode()`

**非目标**：

- 不要求 `v29` 首版支持鼠标自由 UI 光标点选模式

**验收口径**：

- 自动化测试至少断言：进开赛圈会进入正式玩法态。
- 自动化测试至少断言：玩法态期间玩家控制被禁用，退出后恢复。
- 自动化测试至少断言：zoom、切井、退出都走正式 request/input 入口。
- 反作弊条款：不得继续把主动作绑定到 `E`；不得只换个 HUD 文案而实际仍在用玩家武器开火。

### REQ-0019-004 v29 必须提供正式的敌弹波次、拦截弹、爆炸圈与毁伤闭环

**动机**：没有这条闭环，就不是 `Missile Command`，只是一个有相机的场景。

**范围**：

- 首版固定为 deterministic 三波防守
- 每波至少生成多枚敌弹，目标落向 city 或 silo
- 当前选中的 silo 必须拥有独立剩余弹药
- 左键发射时，拦截弹从当前 silo 出发飞向指定落点
- 拦截弹到点后必须生成持续一段时间的爆炸圈
- 敌弹进入爆炸半径必须被摧毁
- 敌弹击中 city 或 silo 时必须产生正式毁伤
- 当全部 city 被毁时，玩法进入 `game_over`
- 当清空最后一波且至少保住一座 city 时，玩法进入 `final`
- 最小 runtime contract 冻结为：
  - `wave_index`
  - `wave_state`
  - `selected_silo_id`
  - `selected_silo_index`
  - `enemy_remaining_count`
  - `interceptor_count`
  - `cities_alive_count`
  - `silo_states`
  - `city_states`
  - `enemy_tracks`
  - `explosion_tracks`
  - `battery_mode_active`

**非目标**：

- 不要求 `v29` 首版做多种特殊弹型

**验收口径**：

- 自动化测试至少断言：至少一枚敌弹能从 spawn lane 落向地面目标。
- 自动化测试至少断言：formal fire request 会从当前 silo 生成拦截弹，而不是从虚空发射。
- 自动化测试至少断言：拦截弹到点后会生成正式爆炸圈，并能摧毁进入半径的敌弹。
- 自动化测试至少断言：敌弹击中 city/silo 会改变对应毁伤状态。
- 自动化测试至少断言：城市全灭进入失败；最终波清空且仍有城市存活进入成功结局。
- 反作弊条款：不得点击即消灭敌弹；不得把“爆炸圈”做成一帧检测后立刻消失的伪体积；不得忽略选井逻辑。

### REQ-0019-005 场馆必须提供正式 HUD、世界记分牌与退出后的 reset contract

**动机**：防空玩法是高节奏反应游戏，没有持续可见状态反馈就不可玩；退出后如果不 reset，也会变成脏 session。

**范围**：

- HUD 与场馆记分牌共享同一份 runtime summary
- 最小 HUD contract 冻结为：
  - `visible`
  - `battery_mode_active`
  - `wave_index`
  - `wave_state`
  - `selected_silo_id`
  - `selected_silo_missiles_remaining`
  - `cities_alive_count`
  - `enemy_remaining_count`
  - `zoom_active`
  - `feedback_event_token`
  - `feedback_event_kind`
  - `feedback_event_text`
- full map pin 若存在，`icon_id = missile_command` 必须能正式渲染
- 退出玩法态或离开场馆 release 语义后，必须 reset 当前 session

**非目标**：

- 不要求 `v29` 首版提供复杂结算页

**验收口径**：

- 自动化测试至少断言：玩法态激活后 HUD 可见，并同步当前波次与当前 silo。
- 自动化测试至少断言：切换 silo 后 HUD 与世界记分牌同步变化。
- 自动化测试至少断言：退出玩法态后 HUD 隐藏、session reset、玩家控制恢复。
- 自动化测试至少断言：full map pin glyph 能从 UI 层正式解析。
- 反作弊条款：不得只改 HUD 不改世界记分牌；不得退出时只关界面不清运行时状态。

### REQ-0019-006 v29 必须沿现有 minigame 聚合链扩展，不得破坏足球/网球主链

**动机**：`v29` 是第三套正式 minigame runtime consumer，不能靠绕路把旧链打坏。

**范围**：

- `CityPrototype` 必须正式聚合 soccer / tennis / missile command 三套 runtime
- ambient freeze 聚合必须把三套玩法统一纳入
- crosshair / HUD / full-map pin 接线必须是扩展而不是替换

**非目标**：

- 不要求这轮顺便重构全部 minigame runtime 共有基类

**验收口径**：

- 自动化测试至少断言：新增 v29 后，受影响 soccer / tennis 关键链仍可访问。
- 如改动触及 HUD / mount / tick，fresh closeout 必须串行跑 profiling 三件套。
- 反作弊条款：不得通过关闭足球或网球功能让 v29 表面通过。

## Success Metrics

- 玩家能在指定 chunk 进入一场正式的防空玩法态。
- 至少一波敌弹可被正式拦截并清空。
- 城市与发射井的存亡对胜负有真实影响。
- 退出玩法态后不留下脏状态。

## Open Follow-Ups

- `v30+` 可扩展特殊弹型、奖励城市、音频节奏与更复杂结算表现。
- `v30+` 可考虑把防空玩法和未来任务系统或事件系统耦合。
