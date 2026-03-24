# V50 Artillery Firing Solution HUD

## Goal

建立正式的 artillery solution HUD 与 firing solution payload contract，让 howitzer 在操炮态下直接显示炮口世界 bearing / pitch，并在 accepted fire 时留下未来可复用的 shot snapshot。

## Dependencies

- 共享 bearing / compass 语义：
  - `res://city_game/world/navigation/CityWorldOrientation.gd`
  - `res://city_game/ui/CityCompassStrip.gd`
- 正式 howitzer runtime：
  - `res://city_game/combat/artillery/CityM777Howitzer.gd`
  - `res://city_game/combat/artillery/CityM777Howitzer.tscn`
- lab 接入层：
  - `res://city_game/scenes/labs/M777HowitzerLab.gd`
- 世界级 HUD：
  - `res://city_game/ui/PrototypeHud.gd`

## Contract Freeze

- HUD 真源：
  - `PrototypeHud`
- HUD 可见性：
  - 仅 howitzer 操炮态显示
- yaw：
  - 炮口世界 bearing
  - `北=0° / 顺时针增加`
- pitch：
  - 校准后的 howitzer 仰角
  - `0-71°`
- firing solution payload：
  - `get_firing_solution_snapshot()`
  - `get_last_fired_solution()`
  - accepted `request_fire()` 返回 payload

## PRD Trace

- `REQ-0029-009`
- `REQ-0029-010`

## Scope

做什么：

- 给 `PrototypeHud` 新增正式 artillery solution HUD consumer
- 新增 `CityArtillerySolutionHud.gd` 作为共享视图容器
- 给 `CityM777Howitzer` 新增 firing solution snapshot / last fired payload API
- 让 `M777HowitzerLab` 在操炮态内推送 artillery solution HUD state
- 补 focused tests 与 verification 文档

不做什么：

- 不生成 projectile
- 不做弹道积分、落点、爆炸、杀伤或反炮兵雷达
- 不做主世界 howitzer 实际接入任务 / landmark / full map pin
- 不把 yaw 退回成“howitzer 相对方位角”

## Acceptance

1. 自动化测试必须证明：`PrototypeHud` 暴露 `set_artillery_solution_state()` / `get_artillery_solution_state()`，并挂接正式 artillery solution HUD view。
2. 自动化测试必须证明：artillery solution HUD 默认隐藏，只有 howitzer 操炮态激活后才可见。
3. 自动化测试必须证明：HUD 中显示的 `yaw` 是炮口世界 bearing；当整门 howitzer 的世界朝向变化时，HUD yaw 也必须跟着变化。
4. 自动化测试必须证明：HUD 中显示的 `pitch` 继续共享 howitzer 当前真实仰角，而不是另起一套 UI 口径。
5. 自动化测试必须证明：`CityM777Howitzer` 暴露 `get_firing_solution_snapshot()` / `get_last_fired_solution()`。
6. 自动化测试必须证明：accepted fire 后如何itzer 会留下正式 firing solution payload，而不是只在 debug text 中短暂打印。
7. 自动化测试必须证明：payload 至少包含 world origin、chunk metadata、world bearing、pitch、shell type 与 muzzle velocity。

## Files

- Update: `docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md`
- Create: `docs/ecn/ECN-0034-artillery-firing-solution-hud-and-payload.md`
- Create: `docs/plans/2026-03-24-v50-artillery-firing-solution-hud-design.md`
- Create: `docs/plan/v50-index.md`
- Create: `docs/plan/v50-artillery-firing-solution-hud.md`
- Create: `city_game/ui/CityArtillerySolutionHud.gd`
- Update: `city_game/ui/PrototypeHud.gd`
- Update: `city_game/combat/artillery/CityM777Howitzer.gd`
- Update: `city_game/scenes/labs/M777HowitzerLab.gd`
- Create: `tests/world/test_city_artillery_solution_hud_contract.gd`
- Create: `tests/world/test_city_m777_howitzer_firing_solution_contract.gd`
- Create: `tests/world/test_city_m777_howitzer_lab_artillery_solution_contract.gd`
- Create: `docs/plan/v50-m2-verification-2026-03-24.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 artillery solution HUD、world bearing 语义与 firing solution payload 字段边界。
2. TDD Red
   - 先写三条 focused tests：
     - `test_city_artillery_solution_hud_contract.gd`
     - `test_city_m777_howitzer_firing_solution_contract.gd`
     - `test_city_m777_howitzer_lab_artillery_solution_contract.gd`
   - 预期第一轮红灯原因：
     - `PrototypeHud` 还没有 artillery solution consumer；
     - howitzer 还没有 firing solution snapshot / last fired payload API；
     - lab 还没有把操炮态下的 artillery solution state 推到共享 HUD。
3. TDD Green
   - 实现 HUD consumer、view、howitzer payload snapshot 与 lab 接线。
4. Refactor
   - 收口 world bearing 计算，避免 HUD 与 fire payload 各算一套口径。
5. Verification
   - 跑 focused tests 与解析检查；
   - 回填 `v50-m2-verification-2026-03-24.md`。

## Risks

- 如果 HUD 继续做成 lab-only 控件，未来 howitzer 接主世界时会再次分叉。
- 如果 `yaw` 继续显示相对角，玩家仍然要自己做方位换算，违背这轮目标。
- 如果 firing solution 只存在瞬时 debug 文本里，后续 projectile / 弹道 / 落点系统仍然无法复用。
