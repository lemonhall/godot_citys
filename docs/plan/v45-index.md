# V45 Index

## 愿景

PRD 入口：[PRD-0030 World Orientation And Compass System](../prd/PRD-0030-world-orientation-and-compass-system.md)

设计入口：[2026-03-24-v45-world-orientation-and-compass-design.md](../plans/2026-03-24-v45-world-orientation-and-compass-design.md)

依赖入口：

- [v12-index.md](./v12-index.md)
- [v44-index.md](./v44-index.md)

`v45` 的目标不是给 UI 随手补一个 `N`，而是正式建立全项目共享的方向学基础设施：冻结 `北=-Z / 东=+X` 的世界方向 contract，冻结 `北=0°、顺时针增加` 的 bearing 口径，让 main world HUD、minimap、full map 与 `M777HowitzerLab` 全部复用它。只有先把这一层坐标体系立住，后续火炮操炮与方位角沟通才有共同语言。

## 决策冻结

- 共享世界北：
  - `Vector3(0, 0, -1)`
- 共享世界东：
  - `Vector3(1, 0, 0)`
- bearing 冻结：
  - `北 = 0°`
  - 顺时针增加
  - `东 = 90°`
  - `南 = 180°`
  - `西 = 270°`
- 地图冻结：
  - full map `north-up`
  - minimap `north-up`
  - `map north = geographic north = world north`
- 主世界 compass HUD：
  - `res://city_game/ui/PrototypeHud.gd` 管理
- 共享 compass 视图：
  - `res://city_game/ui/CityCompassStrip.gd`
- 共享 orientation helper：
  - `res://city_game/world/navigation/CityWorldOrientation.gd`
- lab 并轨对象：
  - `res://city_game/scenes/labs/M777HowitzerLab.tscn`

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / design / v45 plan 全链冻结 | 世界 north/east 定义、bearing 口径、north-up 地图和主世界 + lab compass 范围全部落文档 | `rg -n "north-up|Vector3\\(0, 0, -1\\)|东 = 90|CityCompassStrip|CityWorldOrientation|M777HowitzerLab" docs/prd/PRD-0030-world-orientation-and-compass-system.md docs/plan/v45-index.md docs/plan/v45-world-orientation-and-compass.md docs/plans/2026-03-24-v45-world-orientation-and-compass-design.md` | done |
| M1 shared orientation + map contract | orientation helper、full map、minimap north-up contract | focused tests 证明 bearing 口径冻结且 map/minimap 都是 north-up | `tests/world/test_city_world_orientation_contract.gd` | done |
| M2 HUD + lab compass | main-world compass HUD + M777 lab compass | focused tests 证明主世界 HUD 和 lab 都能给出 bearing / cardinal state | `tests/world/test_city_navigation_compass_hud_contract.gd`; `tests/world/test_city_m777_howitzer_lab_compass_contract.gd` | done |
| M3 verification | focused tests + fresh closeout 文档 | 受影响 tests 全绿，fresh verification 文档回填追溯矩阵 | `docs/plan/v45-m3-verification-2026-03-24.md` | done |

## 计划索引

- [v45-world-orientation-and-compass.md](./v45-world-orientation-and-compass.md)

## 追溯矩阵

| Req ID | V45 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0030-001 | `v45-world-orientation-and-compass.md` | `tests/world/test_city_world_orientation_contract.gd` | `docs/plan/v45-m3-verification-2026-03-24.md` | `v45-m3-verification-2026-03-24.md` | done |
| REQ-0030-002 | `v45-world-orientation-and-compass.md` | `tests/world/test_city_world_orientation_contract.gd` | `docs/plan/v45-m3-verification-2026-03-24.md` | `v45-m3-verification-2026-03-24.md` | done |
| REQ-0030-003 | `v45-world-orientation-and-compass.md` | `tests/world/test_city_navigation_compass_hud_contract.gd` | `docs/plan/v45-m3-verification-2026-03-24.md` | `v45-m3-verification-2026-03-24.md` | done |
| REQ-0030-004 | `v45-world-orientation-and-compass.md` | `tests/world/test_city_world_orientation_contract.gd`; `tests/world/test_city_navigation_compass_hud_contract.gd` | `docs/plan/v45-m3-verification-2026-03-24.md` | `v45-m3-verification-2026-03-24.md` | done |
| REQ-0030-005 | `v45-world-orientation-and-compass.md` | `tests/world/test_city_m777_howitzer_lab_compass_contract.gd` | `docs/plan/v45-m3-verification-2026-03-24.md` | `v45-m3-verification-2026-03-24.md` | done |

## Closeout 证据口径

- `v45` 不接受“地图本来就差不多是 north-up，所以不需要合同化”的说法。
- 必须有 fresh test 证明：
  - 共享 orientation helper 已正式冻结 `北=-Z / 东=+X / 北=0°顺时针增大`；
  - minimap 的几何投影是 north-up；
  - full map 的 render state 明确声明 north-up；
  - 主世界 HUD 已经挂上正式 compass strip；
  - 玩家转向东侧时 HUD 进入 `90°` 口径；
  - `M777HowitzerLab` 也复用同一 compass 语义，而不是 lab-only 口径。

## ECN 索引

- 当前无。

## 差异列表

- 当前无；火炮自身方位角显示、射向/射距解算与真实炮兵火控属于后续版本。
