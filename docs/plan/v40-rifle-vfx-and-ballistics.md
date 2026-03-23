# V40 Rifle VFX And Ballistics

## Goal

交付正式的 `rifle` 视觉/弹道升级，让玩家在主世界和 `SpiderCrawlerLab` 中开火时都拥有更可信的射击反馈：开枪有短促枪口火光，子弹本体不可见，只留下短寿命烟尘轨迹；同时把步枪速度、射程和瞄准 trace 从旧版的“近距离慢弹丸”提升到正式长射程步枪口径，并保持现有 `CityProjectile` live projectile 主链与命中合同不被打碎。

## Dependencies

- 依赖现有 `PlayerController -> CityPrototype -> CityProjectile` 玩家步枪主链
- 依赖 `SpiderCrawlerLab -> CityProjectile` 的 lab combat 复用链
- 依赖 `v39` 已正式冻结的 spider lab 作为 rifle feedback consumer

## Contract Freeze

- 正式 muzzle flash getter：`PlayerController.get_rifle_visual_state()`
- 正式 smoke tracer root：`CombatRoot/ProjectileTracers`
- 正式 smoke tracer runtime：`CityProjectileTracer`
- 正式 rifle projectile profile：
  - `visual_profile = "rifle_smoke_trace"`
  - `body_visible = false`
  - `speed_mps = 920`
  - `max_distance_m = 960`
  - `max_lifetime_sec = 1.25`
- 正式 rifle aim trace distance：`960m`
- `SpiderCrawlerLab` 与主世界必须共用同一 rifle projectile / tracer profile

## Scope

做什么：

- 为 `PlayerController` 增加 rifle muzzle flash runtime 与 formal visual getter
- 为 `CityProjectile` 增加无弹丸体 visual contract
- 新增 `CityProjectileTracer.gd` + smoke tracer shader
- 在 `CityPrototype` 的 rifle projectile spawn 链上接入新 ballistic profile 与 tracer root
- 在 `SpiderCrawlerLab` 的 rifle projectile spawn 链上复用相同 profile
- 新增 world / spider lab focused tests

不做什么：

- 不改 grenade、laser、missile 的视觉风格
- 不新增命中火花、弹孔、壳体抛壳、音频系统或弹药库存
- 不把 projectile 主链改成瞬时 hitscan
- 不把 spider lab 战斗逻辑拆出第二套 rifle-only runtime

## Acceptance

1. 自动化测试必须证明：`PlayerController` 暴露正式 `get_rifle_visual_state()`，并在接受 rifle fire request 后进入 fire FX active 状态。
2. 自动化测试必须证明：主世界 rifle fire 会在 `CombatRoot/ProjectileTracers` 下生成至少一个短寿命 smoke tracer。
3. 自动化测试必须证明：主世界 rifle projectile 的 `visual_profile` 为 `rifle_smoke_trace`，且弹体本身不可见。
4. 自动化测试必须证明：主世界 rifle projectile 的速度与射程已经显著高于旧版慢弹丸合同。
5. 自动化测试必须证明：玩家 rifle 专用 trace distance 已同步提高，避免视觉升级后仍只有旧版短瞄距。
6. 自动化测试必须证明：`SpiderCrawlerLab` 也复用同一条 muzzle flash / tracer / rifle projectile profile。
7. 自动化测试必须证明：蜘蛛 lab 中 rifle fire 在视觉升级后仍然能伤害蜘蛛。
8. 反作弊条款：不得只把蓝色球隐藏掉却不补 tracer；不得只补 tracer 但仍保留旧 200m 级射程；不得在主世界和 spider lab 各写一套不同数值。

## Files

- Create: `docs/plan/v40-index.md`
- Create: `docs/plan/v40-rifle-vfx-and-ballistics.md`
- Create: `docs/plans/2026-03-23-v40-rifle-vfx-and-ballistics-design.md`
- Create: `docs/plans/2026-03-23-v40-rifle-vfx-and-ballistics-research.md`
- Create: `city_game/combat/CityProjectileTracer.gd`
- Create: `city_game/combat/shaders/CityProjectileTracerSmoke.gdshader`
- Modify: `city_game/combat/CityProjectile.gd`
- Modify: `city_game/scripts/PlayerController.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/scenes/labs/SpiderCrawlerLab.gd`
- Modify: `city_game/scenes/labs/SpiderCrawlerLab.tscn`
- Create: `tests/world/test_city_player_rifle_vfx_and_ballistics.gd`
- Create: `tests/world/test_spider_crawler_lab_rifle_feedback_contract.gd`

## Steps

1. Research
   - 对比 `GPUParticles3D + RibbonTrailMesh`、`TubeTrailMesh`、自定义短寿命 tracer node 三种方案。
2. Design
   - 冻结 `v40` 的 muzzle flash / tracer / ballistics / spider lab 共线实现。
3. TDD Red
   - 先写主世界与蜘蛛 lab 的 rifle feedback contract tests。
4. Run Red
   - 确认失败原因是缺少 rifle visual getter / tracer runtime / new ballistic profile。
5. TDD Green
   - 扩展 `PlayerController`、`CityProjectile`，并新增 `CityProjectileTracer`。
   - 在主世界与 spider lab 接入统一 rifle profile。
6. Regression
   - 跑玩家 combat、crosshair、grenade、laser、missile 与蜘蛛 lab combat 回归。
7. Closeout
   - 写 fresh verification 文档并更新 `v40-index`。

## Risks

- 如果完全切 hitscan，会打碎现有 projectile count / live node 合同与相关测试。
- 如果 tracer 依赖 `GPUParticles3D` trail-only 特性，Compatibility 渲染器与 headless 测试边界会更脆。
- 如果主世界和 spider lab 的 ballistic profile 分叉，后续调参会再次出现“双标数值”。
