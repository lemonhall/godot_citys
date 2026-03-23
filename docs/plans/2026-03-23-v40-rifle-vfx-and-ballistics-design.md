# V40 Rifle VFX And Ballistics Design

## Summary

`v40` 采用“保留 live projectile 主链，只替换 rifle 的视觉反馈与 ballistic profile”的方案。实现上不把步枪切成瞬时 hitscan，而是继续让 `CityProjectile` 负责真实飞行与 raycast 命中；玩家开火时由 `PlayerController` 播放短促 muzzle flash，`CityPrototype` 与 `SpiderCrawlerLab` 在 spawn projectile 的同时生成一个极短寿命的 smoke tracer node。这样做的好处是：主世界和蜘蛛 lab 可以共用同一条实现；原有 `get_active_projectile_count()`、live projectile node、combat root 等合同不需要推倒重来；用户最在意的“蓝色糖丸”“射速慢”“射程短”也能在最小架构风险下被一起解决。

## Options

### Option A: 保留 live projectile，新增短寿命 smoke tracer node

推荐方案。

- `CityProjectile` 保留命中与生命周期职责
- 玩家 rifle projectile 切换到 `body_visible = false`
- 每次 fire 额外生成一个短寿命 `CityProjectileTracer`
- `PlayerController` 自己维护 muzzle flash 状态

优点：

- 与现有战斗测试最兼容
- Spider lab 与主世界容易共线
- tracer 可 deterministic 地通过 node count 和 debug state 验证
- 不依赖 renderer-specific particle trail 特性

缺点：

- 需要多一个 runtime node 和 shader

### Option B: 直接切成 hitscan，只保留可视特效

不推荐。

优点：

- 玩家感知最“瞬时”

缺点：

- 会打碎现有 projectile 节点合同
- 需要重写多条测试和战斗消费口径
- Spider lab 也要同步跟着改

### Option C: 完全用 `GPUParticles3D + RibbonTrailMesh`

本轮不采用。

原因：

- Godot 官方粒子 trail 需要 `trail_enabled` 和 `BaseMaterial3D.use_particle_trails` 同时开启，且 trail 只在 `Forward+ / Mobile` 渲染器支持，不支持 `Compatibility` [1][2][3]
- `RibbonTrailMesh` / `TubeTrailMesh` 更适合持续粒子尾迹，而不是步枪这种每发一闪而过的微短轨迹 [2][4]
- 对本仓库的 headless contract tests 来说，独立 tracer node 更容易稳定验证

## Frozen Design

- 正式 rifle projectile profile：
  - `speed_mps = 920`
  - `max_distance_m = 960`
  - `max_lifetime_sec = 1.25`
  - `visual_profile = "rifle_smoke_trace"`
  - `body_visible = false`
- 正式 rifle aim trace distance：`960m`
- 正式 muzzle flash contract：
  - getter：`get_rifle_visual_state()`
  - state：`fire_fx_active`、`fire_count`、`last_muzzle_world_position`
- 正式 tracer contract：
  - runtime：`CityProjectileTracer`
  - root：`CombatRoot/ProjectileTracers`
  - getter：`get_active_projectile_tracer_count()`
- `SpiderCrawlerLab` 与主世界必须复用同一组 rifle constants 与 tracer runtime

## Data Flow

`PlayerController.request_primary_fire()`
-> `_play_rifle_fire_fx()`
-> `primary_fire_requested`
-> `CityPrototype._spawn_projectile()` or `SpiderCrawlerLab._spawn_projectile()`
-> `CityProjectile(body hidden, long-range ballistic profile)`
-> `CityProjectileTracer(short-lived smoke streak)`
-> `CityProjectile` 继续用 `PhysicsRayQueryParameters3D.create(...) + intersect_ray(...)` 命中 [5][6]

## Test Strategy

- focused tests 先锁定：
  - muzzle flash getter
  - tracer root / count / debug state
  - hidden projectile body
  - faster / longer ballistic profile
  - spider lab shared consumer
- 再回归：
  - `test_city_player_combat.gd`
  - `test_city_combat_crosshair.gd`
  - `test_city_player_grenade.gd`
  - `test_city_player_laser_designator.gd`
  - `test_city_player_missile_launcher.gd`
  - `test_spider_crawler_lab_combat_contract.gd`
  - `test_spider_crawler_lab_combat_flow.gd`

## Sources

[1] Godot Engine stable docs, `GPUParticles3D`: particle trails require `trail_enabled` and are designed to work with `RibbonTrailMesh` / `TubeTrailMesh`. https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html

[2] Godot Engine stable docs, `3D Particle trails`: ribbon trails require `RibbonTrailMesh` draw passes plus `Use Particle Trails`, and `Cross` shape uses two perpendicular quads. https://docs.godotengine.org/en/stable/tutorials/3d/particles/trails.html

[3] Godot Engine stable docs, `3D Particle trails`: particle trails are only supported in `Forward+` and `Mobile`, not `Compatibility`. https://docs.godotengine.org/en/stable/tutorials/3d/particles/trails.html

[4] Godot Engine stable docs, `RibbonTrailMesh`: ribbon trail meshes are straight ribbon-shaped meshes typically used for particle trails. https://docs.godotengine.org/en/stable/classes/class_ribbontrailmesh.html

[5] Godot Engine stable docs, `PhysicsRayQueryParameters3D.create(...)`: provides a fast preconfigured ray query object. https://docs.godotengine.org/en/stable/classes/class_physicsrayqueryparameters3d.html

[6] Godot Engine stable docs, `PhysicsDirectSpaceState3D.intersect_ray(...)`: executes the actual ray intersection query from the prepared parameters. https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html
