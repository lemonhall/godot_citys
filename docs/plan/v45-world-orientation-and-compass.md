# V45 World Orientation And Compass

## Goal

冻结 shared world orientation contract，并把它正式接入 main world HUD、minimap、full map 与 `M777HowitzerLab`，为后续火炮方位角操控建立统一口径。

## Dependencies

- 主世界 runtime：
  - `res://city_game/scenes/CityPrototype.tscn`
  - `res://city_game/scripts/CityPrototype.gd`
- 主世界 HUD：
  - `res://city_game/ui/PrototypeHud.gd`
  - `res://city_game/ui/CityMinimapView.gd`
  - `res://city_game/ui/CityMapScreen.gd`
- 地图投影：
  - `res://city_game/world/map/CityMinimapProjector.gd`
- 火炮 lab：
  - `res://city_game/scenes/labs/M777HowitzerLab.tscn`
  - `res://city_game/scenes/labs/M777HowitzerLab.gd`

## Contract Freeze

- 世界北：
  - `-Z`
- 世界东：
  - `+X`
- bearing：
  - `0° = 北`
  - 顺时针递增
  - `90° = 东`
  - `180° = 南`
  - `270° = 西`
- north-up 地图：
  - `map north = geographic north = world north`
- 共享 helper：
  - `CityWorldOrientation`
- 共享 HUD 视图：
  - `CityCompassStrip`

## PRD Trace

- `REQ-0030-001`
- `REQ-0030-002`
- `REQ-0030-003`
- `REQ-0030-004`
- `REQ-0030-005`

## Scope

做什么：

- 创建共享 orientation helper，集中定义 bearing / cardinal / north-up contract
- 给 minimap snapshot 与 full map render state 增加显式 orientation contract
- 给 `PrototypeHud` 增加 compass strip HUD
- 给 `M777HowitzerLab` 增加 compass HUD 与 orientation state
- 补 focused tests 与 verification 文档

不做什么：

- 不实现炮口方位角独立 HUD
- 不实现火控解算、装药、射表
- 不实现地磁偏角或真实军标坐标网
- 不对其它与模型摆正相关的 yaw 公式做无关重构

## Acceptance

1. 自动化测试必须证明：共享 orientation helper 存在并冻结 `北=-Z`、`东=+X`、`北=0°顺时针增大`。
2. 自动化测试必须证明：minimap 投影是 north-up，north/east/south/west 的世界点分别落到地图上/右/下/左。
3. 自动化测试必须证明：full map render state 显式暴露 north-up contract，而不是只有隐式数学结果。
4. 自动化测试必须证明：主世界 HUD 已挂接 compass strip，并暴露 bearing / cardinal state。
5. 自动化测试必须证明：玩家转向东边后，主世界 compass 进入 `90° / E` 口径。
6. 自动化测试必须证明：`build_minimap_snapshot()` 和 full map state 都显式暴露 orientation contract。
7. 自动化测试必须证明：`M777HowitzerLab` 暴露 compass / orientation state，且与主世界共享相同 bearing 口径。

## Files

- Create: `docs/prd/PRD-0030-world-orientation-and-compass-system.md`
- Create: `docs/plans/2026-03-24-v45-world-orientation-and-compass-design.md`
- Create: `docs/plan/v45-index.md`
- Create: `docs/plan/v45-world-orientation-and-compass.md`
- Create: `city_game/world/navigation/CityWorldOrientation.gd`
- Create: `city_game/ui/CityCompassStrip.gd`
- Update: `city_game/scripts/CityPrototype.gd`
- Update: `city_game/ui/PrototypeHud.gd`
- Update: `city_game/ui/CityMinimapView.gd`
- Update: `city_game/ui/CityMapScreen.gd`
- Update: `city_game/world/map/CityMinimapProjector.gd`
- Update: `city_game/scenes/labs/M777HowitzerLab.gd`
- Create: `tests/world/test_city_world_orientation_contract.gd`
- Create: `tests/world/test_city_navigation_compass_hud_contract.gd`
- Create: `tests/world/test_city_m777_howitzer_lab_compass_contract.gd`
- Create: `docs/plan/v45-m3-verification-2026-03-24.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 north/east 轴、bearing 口径、north-up 地图与 main world + lab compass 范围。
2. TDD Red
   - 先写三条 focused tests：
     - `test_city_world_orientation_contract.gd`
     - `test_city_navigation_compass_hud_contract.gd`
     - `test_city_m777_howitzer_lab_compass_contract.gd`
   - 预期第一轮红灯原因：
     - orientation helper 尚不存在；
     - HUD compass 尚不存在；
     - minimap / full map 尚未显式暴露 north-up contract；
     - lab 尚未暴露 compass state。
3. TDD Green
   - 实现共享 orientation helper、HUD compass、north-up contract 与 lab 并轨。
4. Refactor
   - 收口主世界与 lab 的 compass state 构建，避免一边报 bearing、一边报 heading_rad 的口径分裂。
5. Verification
   - focused tests 全绿；
   - 补 `v45-m3-verification-2026-03-24.md` closeout 证据。

## Risks

- 如果 helper 不集中收口，主世界 HUD、lab、minimap 很容易出现顺时针/逆时针口径漂移。
- 如果 north-up 只靠现有投影隐式成立，没有 state contract，后续任何 UI 重构都可能悄悄把地图旋转掉。
- 如果 lab compass 不复用主世界口径，后续操炮仍会出现“lab 里朝东是 90，主世界却不是”的分叉。
