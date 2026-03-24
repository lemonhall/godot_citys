# V53 Artillery Map Fire Mission

## Goal

把 howitzer 从“能算诸元、能飞会炸”推进到“玩家能在大地图上正式下达一轮炮击任务，并在击发后观察弹着”的完整闭环。

## Dependencies

- full map UI：
  - `res://city_game/ui/CityMapScreen.gd`
- pin 主链：
  - `res://city_game/world/map/CityMapPinRegistry.gd`
- 主世界 host：
  - `res://city_game/scripts/CityPrototype.gd`
- artillery solver / runtime：
  - `res://city_game/combat/artillery/CityArtilleryBallistics.gd`
  - `res://city_game/combat/artillery/CityM777Howitzer.gd`
  - `res://city_game/combat/artillery/CityArtilleryShell.gd`
- streaming prewarm：
  - `res://city_game/world/rendering/CityChunkRenderer.gd`

## Contract Freeze

- full map action：
  - `炮击标记`
  - `artillery_fire_mission`
- active marker 策略：
  - simultaneously one
- marker 视觉：
  - yellow/gold cross
- planned battery snapshot：
  - summon-compatible
- observation closeout：
  - `muzzle_stage -> impact_stage -> restore`
- compatibility：
  - fire mission optional
  - free fire still supported

## PRD Trace

- `REQ-0029-018`
- `REQ-0029-019`
- `REQ-0029-020`
- `REQ-0029-021`
- `REQ-0029-022`
- `REQ-0029-023`

## Scope

做什么：

- 在 `CityMapScreen` 增加 right-click context menu 与 `炮击标记`
- 为 full map 增加单个 active artillery fire mission marker 与 solution panel
- 使用 shared ballistic solver 直接给出 bearing / pitch / range / arc / reason
- 冻结 planned battery snapshot，并让 `KP_8` summon 复用它
- 在 accepted fire 后预测 impact、预热 impact chunk，并切 observer camera 观察爆炸
- 保证 free fire 没有 map mission 时也能走同口径 observer closeout
- 补 focused tests、e2e 与 verification 文档

不做什么：

- 不做多目标 fire mission 列表或 battery roster
- 不做自动调炮、自动击发或 AI 装填手
- 不做 cinematic shell follow camera
- 不做任务系统挂接、持久化 mission log 或弹着修正表

## Acceptance

1. 自动化测试必须证明：full map 在画布内 right-click 时会显示正式 context menu，且动作列表包含 `炮击标记`。
2. 自动化测试必须证明：left-click 现有 map destination selection 不会因为 right-click menu 而退化。
3. 自动化测试必须证明：选择 `炮击标记` 后，系统只保留一个 active fire mission marker，并能正式读回 target chunk metadata。
4. 自动化测试必须证明：map fire mission 会直接使用 shared ballistic solver 给出 `bearing / pitch / range / arc`；超出射程时则给出 formal `reason`。
5. 自动化测试必须证明：在尚未召唤 howitzer 时先创建 fire mission，`KP_8` 召唤 howitzer 会优先复用该 planned battery snapshot。
6. 自动化测试必须证明：主世界 accepted fire 会启动 observation closeout，留下 predicted impact、prewarm chunk 与 camera owner 的正式 runtime state。
7. 自动化测试必须证明：observer closeout 在 impact 观察结束后会恢复 player camera ownership。
8. 自动化测试必须证明：没有 active fire mission marker 的 free fire 仍然会触发同口径的 observation closeout。

## Files

- Update: `docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md`
- Create: `docs/ecn/ECN-0037-artillery-map-fire-mission-and-observer-closeout.md`
- Create: `docs/plans/2026-03-25-v53-artillery-map-fire-mission-design.md`
- Create: `docs/plan/v53-index.md`
- Create: `docs/plan/v53-artillery-map-fire-mission.md`
- Create: `city_game/combat/artillery/CityArtilleryFireMissionRuntime.gd`
- Update: `city_game/ui/CityMapScreen.gd`
- Update: `city_game/world/map/CityMapPinRegistry.gd`
- Update: `city_game/scripts/CityPrototype.gd`
- Update: `city_game/ui/PrototypeHud.gd`
- Create: `tests/world/test_city_map_artillery_context_menu_contract.gd`
- Create: `tests/world/test_city_artillery_fire_mission_contract.gd`
- Create: `tests/world/test_city_artillery_fire_mission_observer_closeout_contract.gd`
- Create: `tests/e2e/test_city_map_artillery_fire_mission_flow.gd`
- Create: `docs/plan/v53-m3-verification-2026-03-25.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 right-click menu、single active marker、planned battery snapshot、observer closeout 与非目标边界。
2. TDD Red
   - 先写四条 tests：
     - `test_city_map_artillery_context_menu_contract.gd`
     - `test_city_artillery_fire_mission_contract.gd`
     - `test_city_artillery_fire_mission_observer_closeout_contract.gd`
     - `test_city_map_artillery_fire_mission_flow.gd`
3. Run Red
   - 预期第一轮红灯原因：
     - map 还没有 right-click menu；
     - 没有 formal fire mission marker / state；
     - accepted fire 还没有 observer closeout。
4. TDD Green
   - 实现 map menu、fire mission runtime、planned battery snapshot 与 observer closeout。
5. Refactor
   - 收口 map mission state / summon override / observer runtime，避免 `CityPrototype` 再次长成 howitzer 私有巨石。
6. Verification
   - 跑 focused tests、e2e、既有 howitzer ballistic 回归与项目解析检查；
   - 回填 `v53-m3-verification-2026-03-25.md`。

## Risks

- 如果 map marker 不接 pin 主链，后面 full map / minimap / future task 化一定再次分叉。
- 如果 planned battery snapshot 不冻结，玩家会马上遇到“地图抄的诸元与召唤后的炮位不一致”。
- 如果 observer closeout 用假爆炸旁路，而不是 actual firing solution + live shell 预测，free fire 与正式 map mission 很快就会口径失真。
