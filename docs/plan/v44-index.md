# V44 Index

## 愿景

PRD 入口：[PRD-0029 Artillery Howitzer Scene Foundation](../prd/PRD-0029-artillery-howitzer-scene-foundation.md)

设计入口：[2026-03-24-v44-artillery-howitzer-scene-and-lab-design.md](../plans/2026-03-24-v44-artillery-howitzer-scene-and-lab-design.md)

依赖入口：

- [v37-index.md](./v37-index.md)
- [v42-index.md](./v42-index.md)

`v44` 的目标不是把 `m777_3_parts.glb` 临时摆进一个 preview wrapper，也不是立刻把它接入主世界。它要先建立一条正式的火炮 scene foundation：冻结 `lower_base / upper_carriage / gun_assembly` 的三层 runtime 层级，冻结两个手工可调轴心锚点，建立独立 lab 供后续调 yaw / pitch、控制面与音效，再把主世界接入留给后续版本。

## 决策冻结

- 正式火炮场景路径：
  - `res://city_game/combat/artillery/CityM777Howitzer.tscn`
- 正式火炮 lab 场景路径：
  - `res://city_game/scenes/labs/M777HowitzerLab.tscn`
- 正式 source asset：
  - `res://city_game/assets/environment/source/artillery/m777/m777_3_parts.glb`
- 正式三段式节点名：
  - `m777_lower_base`
  - `m777_upper_carriage`
  - `m777_gun_assembly`
- 正式手工锚点：
  - `Anchors/YawPivotAnchor`
  - `Anchors/PitchPivotAnchor`
- 正式 runtime pivot：
  - `ModelRoot/YawPivot`
  - `ModelRoot/YawPivot/PitchPivot`
- 正式 pitch 口径：
  - `pitch=0°` 表示炮口视觉放平后的真实仰角零位
  - 正值表示抬高炮口
  - 最大仰角 `71°`
  - 模型内部允许保留独立零位校准偏置
- 正式 yaw 口径：
  - `yaw` 对外归一到 `0-360°`
  - 超过整圈后回卷
  - `360°` 视为 `0°`

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / design / v44 plan 全链冻结 | 正式 scene/lab 路径、三段式节点名、两枚锚点与非目标边界全部落文档 | `rg -n "CityM777Howitzer|M777HowitzerLab|YawPivotAnchor|PitchPivotAnchor|m777_lower_base|m777_upper_carriage|m777_gun_assembly" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/plan/v44-index.md docs/plan/v44-artillery-howitzer-scene-and-lab.md docs/plans/2026-03-24-v44-artillery-howitzer-scene-and-lab-design.md` | done |
| M1 howitzer scene wrapper | 正式火炮包装 scene + runtime API + 两枚锚点 | focused test 证明 scene wrapper / pivots / anchors / API 全部成立 | `tests/world/test_city_m777_howitzer_scene_contract.gd` | done |
| M2 howitzer lab | 独立 lab 场景 + 最小调角入口 | lab focused test 证明正式 howitzer scene 被挂载，lab 可读写 yaw / pitch，并以正式玩家相机启动 | `tests/world/test_city_m777_howitzer_lab_scene_contract.gd` | done |
| M3 verification | focused tests + fresh closeout 文档 | 受影响 tests 全绿，fresh verification 文档回填追溯矩阵 | `docs/plan/v44-m3-verification-2026-03-24.md` | done |

## 计划索引

- [v44-artillery-howitzer-scene-and-lab.md](./v44-artillery-howitzer-scene-and-lab.md)

## 追溯矩阵

| Req ID | V44 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0029-001 | `v44-artillery-howitzer-scene-and-lab.md` | `tests/world/test_city_m777_howitzer_scene_contract.gd` | `docs/plan/v44-m3-verification-2026-03-24.md` | `v44-m3-verification-2026-03-24.md` | done |
| REQ-0029-002 | `v44-artillery-howitzer-scene-and-lab.md` | `tests/world/test_city_m777_howitzer_scene_contract.gd` | `docs/plan/v44-m3-verification-2026-03-24.md` | `v44-m3-verification-2026-03-24.md` | done |
| REQ-0029-003 | `v44-artillery-howitzer-scene-and-lab.md` | `tests/world/test_city_m777_howitzer_scene_contract.gd` | `docs/plan/v44-m3-verification-2026-03-24.md` | `v44-m3-verification-2026-03-24.md` | done |
| REQ-0029-004 | `v44-artillery-howitzer-scene-and-lab.md` | `tests/world/test_city_m777_howitzer_scene_contract.gd` | `docs/plan/v44-m3-verification-2026-03-24.md` | `v44-m3-verification-2026-03-24.md` | done |
| REQ-0029-005 | `v44-artillery-howitzer-scene-and-lab.md` | `tests/world/test_city_m777_howitzer_lab_scene_contract.gd` | `docs/plan/v44-m3-verification-2026-03-24.md` | `v44-m3-verification-2026-03-24.md` | done |
| REQ-0029-006 | `v44-artillery-howitzer-scene-and-lab.md` | `tests/world/test_city_m777_howitzer_lab_scene_contract.gd` | `docs/plan/v44-m3-verification-2026-03-24.md` | `v44-m3-verification-2026-03-24.md` | done |

## Closeout 证据口径

- `v44` 不接受把 `m777_3_parts.glb` 直接扔进 lab 里当完成。
- 必须有 fresh test 证明：
  - 正式 howitzer `.tscn` scene 存在并包裹正式 glb；
  - 正式 howitzer scene 已归一化到 world-scale 火炮尺寸，而不是保持 `1m` 级缩水玩具比例；
  - yaw / pitch 是两级独立 pivot，不是整坨单轴旋转；
  - `yaw` 对外暴露的是归一化圆周角，而不是累计转圈数；
  - `pitch` 对外暴露的是校准后的真实仰角，炮口放平时为 `0°`，正值表示抬高炮口；
  - `pitch` 被限制在 `0-71°` 射界内；
  - 两枚锚点是 scene-authored `Marker3D`；
  - lab 挂的是正式 howitzer scene，而不是 glb；
  - lab 能通过稳定 API 调 yaw / pitch；
  - lab 以正式 `PlayerController` 玩家和当前玩家相机启动，而不是只剩静态镜头。

## ECN 索引

- [ECN-0029-artillery-pitch-calibration-and-elevation-limit.md](../ecn/ECN-0029-artillery-pitch-calibration-and-elevation-limit.md)

## 差异列表

- 当前无实现差异；主世界接入、开火链、音效与交互仍按 `v44` 非目标保留给后续版本。
