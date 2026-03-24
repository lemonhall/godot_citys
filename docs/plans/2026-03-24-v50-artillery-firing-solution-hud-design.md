# 2026-03-24 V50 Artillery Firing Solution HUD Design

## Context

howitzer 当前已经具备正式 scene wrapper、操炮交互、world compass 与 fire presentation，但玩家真正操炮时仍然缺少两条关键基础设施。第一，操炮态里没有一组正式“射击诸元”标尺，玩家只能看 world compass、看炮口、或者读 debug text，自行把炮口方向和真实方位角换算起来。第二，accepted fire 以后没有正式 firing solution payload，导致后续如果要接 projectile、落点动画、弹道积分或反炮兵逻辑，howitzer runtime 并不能给出一份稳定、结构化、可回放的 shot snapshot。

用户已经把本轮目标冻结得很具体：HUD 里的 `yaw` 直接显示炮口世界 bearing，不让玩家做相对角换算；`pitch` 继续使用现有 howitzer 的真实仰角口径；这轮仍然不做炮弹飞出，但 firing solution payload 必须正式落下来，为未来战斗系统预埋真接口。

## Recommended Approach

推荐继续沿 shared consumer 方案推进，而不是在 `M777HowitzerLab` 里临时画控件。具体做法是把 artillery solution HUD 做成 `PrototypeHud` 的新 consumer，并新增一个轻量 `CityArtillerySolutionHud.gd` 作为视图容器。视图内部不重新发明一整套美术，而是复用现有 `CityCompassStrip` 的视觉语言：上条显示 `yaw`，下条显示 `pitch`，两者都沿用军用刻度条的中心指示器与滚动刻度，只是数据源不同。

与此同时，把 howitzer 的“开火瞬间射击诸元”冻结成正式 runtime contract。`CityM777Howitzer` 提供 `get_firing_solution_snapshot()` 与 `get_last_fired_solution()`；accepted `request_fire()` 会把 snapshot 一并返回并落存。这样 lab、未来主世界 howitzer controller、后续 projectile runtime 都能消费同一份数据，而不是再各算一套 bearing / pitch / origin / chunk 信息。

## Data Strategy

`yaw` 不应直接读取 howitzer 的相对 `_yaw_deg`。推荐真源是 howitzer 当前炮口方向在世界空间中的真实向量，也就是由 `PitchPivotAnchor` 指向 `MuzzleFxAnchor` 的世界向量，再投影到 `XZ` 平面，最后交给 `CityWorldOrientation.bearing_deg_from_world_vector()` 统一解算。这样即便 howitzer 整体摆在世界里再旋转一次，HUD 与 payload 仍然输出正确的世界 bearing。

`pitch` 则继续复用 howitzer 已有的校准结果 `get_pitch_degrees()`，不再重复维护第二套 UI 偏置。payload 至少保留：world origin、platform world position、muzzle world direction、world bearing、pitch、`shell_type_id`、`muzzle_velocity_mps`、`chunk_key`、`chunk_id`。这轮不做 ballistic solver，但字段先冻结下来，后续就能直接作为 projectile 初始化参数或弹道学输入。

## Risks

- 如果 artillery solution HUD 不放进 `PrototypeHud`，未来主世界接入时一定会再次出现 lab / world 两套 UI contract。
- 如果 `yaw` 偷懒继续显示 howitzer 相对 yaw，玩家还是得自己把炮口方位换算成世界 bearing，这轮目标就没有达成。
- 如果 payload 只落一个“最后一次 fire 的 debug 字符串”，后续 projectile / 落点 / 反炮兵系统依然无从复用。
