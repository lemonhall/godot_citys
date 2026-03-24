# V53 Index

## 愿景

PRD 入口：[PRD-0029 Artillery Howitzer Scene Foundation](../prd/PRD-0029-artillery-howitzer-scene-foundation.md)

设计入口：[2026-03-25-v53-artillery-map-fire-mission-design.md](../plans/2026-03-25-v53-artillery-map-fire-mission-design.md)

依赖入口：

- [v51-index.md](./v51-index.md)
- [v52-index.md](./v52-index.md)

`v53` 的目标不是把 howitzer 再做成一套独立小游戏，而是把 `solver -> full map -> summon -> fire -> observe` 这条炮兵闭环正式收口。当前范围冻结为：full map 右键 `炮击标记`、单个 active fire mission marker、基于 shared solver 的 bearing/pitch/range/arc 展示、planned battery snapshot 保活、以及 accepted fire 后的 impact chunk prewarm + observer closeout。

## 决策冻结

- full map action：
  - `炮击标记`
  - `artillery_fire_mission`
- active mission 策略：
  - 同时仅一个 active marker
- marker 视觉：
  - yellow/gold cross
- map-side solver 真源：
  - `res://city_game/combat/artillery/CityArtilleryBallistics.gd`
- planned battery snapshot：
  - 与 `KP_8` summon 共线
- observation closeout：
  - predicted impact
  - chunk prewarm
  - observer camera
- compatibility：
  - free fire 也必须进入 observer closeout

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v53 plan 全链冻结 | full map context menu、single active fire mission、planned battery snapshot、observer closeout 与非目标边界全部落文档 | `rg -n "REQ-0029-018|REQ-0029-019|REQ-0029-020|REQ-0029-021|REQ-0029-022|REQ-0029-023|炮击标记|observer closeout|planned battery snapshot" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0037-artillery-map-fire-mission-and-observer-closeout.md docs/plan/v53-index.md docs/plan/v53-artillery-map-fire-mission.md docs/plans/2026-03-25-v53-artillery-map-fire-mission-design.md` | planned |
| M1 map fire mission | right-click menu、single marker、solver 展示、planned battery snapshot | focused tests 证明 full map 支持 `炮击标记`，并能留下 formal fire mission state | `tests/world/test_city_map_artillery_context_menu_contract.gd`; `tests/world/test_city_artillery_fire_mission_contract.gd` | planned |
| M2 observer closeout | accepted fire 预测落点、chunk prewarm、observer camera、free-fire compatibility | focused + e2e 证明 accepted fire 会进入 observer closeout，且 free fire 也能观察 impact | `tests/world/test_city_artillery_fire_mission_observer_closeout_contract.gd`; `tests/e2e/test_city_map_artillery_fire_mission_flow.gd`; `tests/world/test_city_world_howitzer_ballistics_contract.gd` | planned |
| M3 verification | focused + e2e + 解析检查 | 受影响 tests 全绿，fresh verification 文档回填追溯矩阵 | `docs/plan/v53-m3-verification-2026-03-25.md` | planned |

## 计划索引

- [v53-artillery-map-fire-mission.md](./v53-artillery-map-fire-mission.md)

## 追溯矩阵

| Req ID | V53 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0029-018 | `v53-artillery-map-fire-mission.md` | `tests/world/test_city_map_artillery_context_menu_contract.gd` | `docs/plan/v53-m3-verification-2026-03-25.md` | pending | planned |
| REQ-0029-019 | `v53-artillery-map-fire-mission.md` | `tests/world/test_city_artillery_fire_mission_contract.gd` | `docs/plan/v53-m3-verification-2026-03-25.md` | pending | planned |
| REQ-0029-020 | `v53-artillery-map-fire-mission.md` | `tests/world/test_city_artillery_fire_mission_contract.gd` | `docs/plan/v53-m3-verification-2026-03-25.md` | pending | planned |
| REQ-0029-021 | `v53-artillery-map-fire-mission.md` | `tests/world/test_city_artillery_fire_mission_contract.gd`; `tests/world/test_city_world_howitzer_spawn_contract.gd` | `docs/plan/v53-m3-verification-2026-03-25.md` | pending | planned |
| REQ-0029-022 | `v53-artillery-map-fire-mission.md` | `tests/world/test_city_artillery_fire_mission_observer_closeout_contract.gd` | `tests/e2e/test_city_map_artillery_fire_mission_flow.gd`; `docs/plan/v53-m3-verification-2026-03-25.md` | pending | planned |
| REQ-0029-023 | `v53-artillery-map-fire-mission.md` | `tests/world/test_city_artillery_fire_mission_observer_closeout_contract.gd`; `tests/world/test_city_world_howitzer_ballistics_contract.gd` | `docs/plan/v53-m3-verification-2026-03-25.md` | pending | planned |

## Closeout 证据口径

- `v53` 不接受“地图上能画个黄叉就算完成”的说法。
- 必须有 fresh tests 证明：
  - right-click context menu 真存在；
  - map solver 真给出 bearing / pitch / reason；
  - planned battery snapshot 真能影响 `KP_8` summon；
  - accepted fire 真会触发 observer closeout，而不是仍然只停留在炮位。

## ECN 索引

- [ECN-0037-artillery-map-fire-mission-and-observer-closeout.md](../ecn/ECN-0037-artillery-map-fire-mission-and-observer-closeout.md)

## 差异列表

- 当前无；多目标 battery management、任务化 UI、自动调炮与多机位 cinematic 仍属于后续版本范围。
