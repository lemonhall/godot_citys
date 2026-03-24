# V44 Artillery Howitzer Scene And Lab

## Goal

建立一套正式可复用的 M777 火炮包装 scene 与独立 lab：把 `m777_3_parts.glb` 收口进稳定的 `lower_base / yaw / pitch` 层级，暴露手工锚点与最小 runtime API，并提供独立 lab 用于后续调试控制面、音效与其它扩展。

## Dependencies

- 正式 source asset：
  - `res://city_game/assets/environment/source/artillery/m777/m777_3_parts.glb`
- 参考正式 authored combat scenes：
  - `res://city_game/combat/drone/CityDroneGunship.tscn`
  - `res://city_game/combat/helicopter/CityHelicopterGunship.tscn`
- 参考 lab 组织：
  - `res://city_game/scenes/labs/HelicopterGunshipLab.tscn`

## Contract Freeze

- 正式 howitzer scene root：
  - `CityM777Howitzer`
- 正式 lab scene root：
  - `M777HowitzerLab`
- 正式 source asset child：
  - `ModelRoot/SourceAsset`
- 正式 runtime pivots：
  - `ModelRoot/YawPivot`
  - `ModelRoot/YawPivot/PitchPivot`
- 正式 hand-authored anchors：
  - `Anchors/YawPivotAnchor`
  - `Anchors/PitchPivotAnchor`
- 正式 runtime mesh owners：
  - `ModelRoot/LowerBaseMount/m777_lower_base`
  - `ModelRoot/YawPivot/m777_upper_carriage`
  - `ModelRoot/YawPivot/PitchPivot/m777_gun_assembly`

## PRD Trace

- `REQ-0029-001`
- `REQ-0029-002`
- `REQ-0029-003`
- `REQ-0029-004`
- `REQ-0029-005`
- `REQ-0029-006`

## Scope

做什么：

- 创建正式 `CityM777Howitzer.tscn` 与 `CityM777Howitzer.gd`
- 创建两枚正式锚点 marker，并由 runtime 读取它们定位 pivot
- 创建独立 `M777HowitzerLab.tscn` 与 lab 脚本
- 建立最小 howitzer runtime API 与 lab 调角 API
- 补 focused contract tests 与 verification 文档

不做什么：

- 不接入主世界 landmark / task / full map / world feature registry
- 不做开火、弹道、后坐、装填、炮口焰、音效实现
- 不做 NPC、交互 UI、任务、碰撞破坏、伤害链
- 不做 scene preview harness wrapper

## Acceptance

1. 自动化测试必须证明：正式 howitzer scene 存在，并直接引用 `m777_3_parts.glb`。
2. 自动化测试必须证明：`YawPivot` 与 `PitchPivot` 是正式 runtime 节点，而不是靠临时数学直接旋转 mesh。
3. 自动化测试必须证明：`YawPivotAnchor` 与 `PitchPivotAnchor` 是正式 `Marker3D`，并通过 root API 进入 debug state。
4. 自动化测试必须证明：调用 `set_yaw_degrees()` 只改变 yaw 层，调用 `set_pitch_degrees()` 只改变 pitch 层。
5. 自动化测试必须证明：`pitch` 对外读写口径已经校准到真实仰角；炮口放平时为 `0°`，正值表示抬高炮口，而不是暴露模型内部偏置角或把正负方向写反。
6. 自动化测试必须证明：`pitch` 被限制在 `0-71°` 射界之内。
7. 自动化测试必须证明：lab scene 挂载正式 howitzer scene，而不是直接引用 `glb`。
8. 自动化测试必须证明：lab scene 暴露 `get_howitzer()`、`get_lab_state()`、`reset_lab_state()` 和调角入口。
9. 自动化测试必须证明：lab scene 启动时存在正式 `PlayerController` 玩家与当前玩家相机，而不是只留静态观察镜头。
10. 自动化测试必须证明：正式 howitzer scene 已把缩水 AI 资产归一化到 world-scale 火炮尺寸，而不是仍然保持玩具比例。

## Files

- Create: `docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md`
- Create: `docs/plans/2026-03-24-v44-artillery-howitzer-scene-and-lab-design.md`
- Create: `docs/plan/v44-index.md`
- Create: `docs/plan/v44-artillery-howitzer-scene-and-lab.md`
- Create: `city_game/combat/artillery/CityM777Howitzer.gd`
- Create: `city_game/combat/artillery/CityM777Howitzer.tscn`
- Create: `city_game/scenes/labs/M777HowitzerLab.gd`
- Create: `city_game/scenes/labs/M777HowitzerLab.tscn`
- Create: `tests/world/test_city_m777_howitzer_scene_contract.gd`
- Create: `tests/world/test_city_m777_howitzer_lab_scene_contract.gd`
- Create: `docs/plan/v44-m3-verification-2026-03-24.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 howitzer scene 路径、lab 路径、三段式节点名、两枚锚点与非目标边界。
2. TDD Red
   - 先写 `test_city_m777_howitzer_scene_contract.gd` 与 `test_city_m777_howitzer_lab_scene_contract.gd`。
   - 预期第一轮红灯原因：
     - 正式 howitzer `.tscn` / `.gd` 还不存在；
     - lab 场景还不存在；
     - yaw / pitch API 尚未建立。
3. TDD Green
   - 实现 howitzer scene wrapper、pivot chain、anchors、lab scene 与最小调角接口。
4. Refactor
   - 收口公共状态与 debug 输出，避免 lab 和 howitzer scene 各自维护一套角度状态。
5. Verification
   - focused tests 全绿；
   - 补 `v44-m3-verification-2026-03-24.md` closeout 证据。

## Risks

- 如果三段 mesh 没有被正式 reparent 到 pivot 层级，后续无论怎么设 anchor 都只是“看起来分件”，不能稳定旋转。
- 如果 anchor 位置继续藏在脚本常量里，后续每次调轴都要改代码，scene-first contract 会失效。
- 如果 lab 直接引用 `glb` 而不是 howitzer scene，后续主世界接入和 lab 调试会再次分叉。
