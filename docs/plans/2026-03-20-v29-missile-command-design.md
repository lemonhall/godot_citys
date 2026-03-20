# V29 Missile Command Design

## Overview

`v29` 采用 `scene_minigame_venue` 主链，不新增 `interactive_prop` consumer。原因很直接：这轮玩家不是去“摸一个正式物件”，而是在一个作者化场馆内切入完整玩法态。`CityPrototype` 负责把场馆 runtime 聚合进现有 minigame 更新链、HUD 链和输入分发链；具体规则则放进新的 `CityMissileCommandVenueRuntime.gd`。场馆本体通过 `MissileCommandMinigameVenue.gd` 暴露稳定 contract，包括开赛圈、游戏平面、发射井、城市、防空相机和世界记分牌。静态位置全部 scene-owned，动态弹道、爆炸、波次、毁伤和玩法态由 runtime 控制。

核心设计选择是把 `Missile Command` 的二维玩法抽象成一个 **固定纵向 gameplay plane**。也就是：敌方弹头、拦截弹和爆炸都在场馆前方的一张垂直平面里运行，只是通过作者化相机以三维透视方式观看。这样既能保住原版“指定拦截点”的玩法语义，又能避免把准星投射、轨迹判定和爆炸链做成真正三维体积搜索后失控。场馆 scene 内会 author `GameplayPlaneAnchor`、`BatteryCameraPivot`、`BatteryCamera`、`LaunchSilo*Anchor`、`CityTarget*Anchor` 和 `EnemySpawnLane*Anchor`；runtime 只从这些锚点读取 contract，不再在代码里硬写静态 transform。

## Runtime

`CityMissileCommandVenueRuntime.gd` 会按 `CitySoccerVenueRuntime` / `CityTennisVenueRuntime` 的方式接进 `CityPrototype._update_minigame_venue_runtimes()`。它的职责是：

- 根据 `game_kind = missile_command_battery` 过滤 minigame venue entries
- 在玩家接近场馆时解析 mounted venue
- 在玩家进入 start ring 后自动进入 `battery_mode_active`
- 玩法态期间冻结 ambient simulation，但不使用 `world_simulation_pause`
- 管理 `idle -> briefing -> in_wave -> wave_clear -> final / game_over -> exit` 状态机
- 维护 `silo_states / city_states / enemy_tracks / interceptor_tracks / explosion_tracks`
- 维护 `selected_silo_index / zoom_active / reticle_world_position`
- 通过 formal request API 接收“发射 / 切井 / zoom / exit”请求

输入层不再复用 `E`。`CityPrototype._unhandled_input()` 在 `missile command` 玩法态活跃时优先把事件转给 runtime。运行时会处理：

- `InputEventMouseMotion`：旋转 battery camera pivot
- `MOUSE_BUTTON_LEFT`：对当前 reticle 落点发射拦截弹
- `MOUSE_BUTTON_RIGHT`：切 zoom active
- `KEY_Q`：轮换发射井
- `ui_cancel / Esc`：退出玩法态

为 headless 测试保留 formal request API：

- `request_missile_command_primary_fire()`
- `request_missile_command_fire_at_world_position(world_position)`
- `cycle_missile_command_silo()`
- `set_missile_command_zoom_active(active)`
- `exit_missile_command_mode()`

## Combat / HUD / Tests

波次脚本首版固定为 deterministic 三波防守。每波按预设节奏从 `EnemySpawnLane` 顶部生成若干 enemy tracks，目标只允许从城市集合里按稳定脚本挑选，不打我方发射井。敌方弹头抵达目标即结算毁伤；拦截弹从当前 silo 以恒定速度飞向指定落点，抵达后生成扩张爆炸圈；任一敌方轨迹进入爆炸半径则被击毁。这样能把原版最重要的“指定落点 + 爆炸链”落到正式 contract，而不是偷换成自动锁定导弹。

HUD 层新增 `missile command` block，最小显示 contract 冻结为：

- `visible`
- `battery_mode_active`
- `wave_index`
- `wave_state`
- `selected_silo_id`
- `cities_alive_count`
- `enemy_remaining_count`
- `interceptor_count`
- `zoom_active`
- `feedback_event_token / kind / text`

世界空间记分牌与 HUD 共享同一份 runtime summary。受影响的自动化测试按三层组织：

1. world contract：registry/manifest、venue contract、玩法态切换、波次与毁伤 contract
2. map/UI contract：full map pin glyph、HUD state、crosshair/zoom state
3. e2e：进圈进入玩法态 -> 发射至少一枚拦截弹 -> 击毁至少一个敌方弹头 -> 波次推进 -> Esc 退出 -> 玩家控制恢复

这里的反作弊红线也一并冻结：不能把敌方弹头做成纯 HUD 标记；不能无视选井逻辑从“虚空导弹池”发射；不能把命中判定偷换成点击即消失；不能只切 HUD 文案而没有真实敌我弹道与爆炸圈。
