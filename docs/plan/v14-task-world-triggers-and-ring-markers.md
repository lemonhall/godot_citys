# V14 Task World Triggers And Ring Markers

## Goal

交付正式绿色/蓝色任务火焰圈、任务开始/完成触发和步行/驾车 E2E 主链，让任务系统不只存在于地图 UI，而是真正落到 3D 世界里。

## PRD Trace

- Direct consumer: REQ-0007-005
- Direct consumer: REQ-0007-006
- Direct consumer: REQ-0007-007
- Guard / Performance: REQ-0007-008

## Dependencies

- 依赖 M1 已交付正式 `task runtime / task slot index`。
- 依赖 M2 已交付正式 `tracked task / task pin / task brief`。
- 依赖 `v12` 已交付 destination world marker、map destination、route target 与 player vehicle control contract。

## Contract Freeze

- 任务 world marker 必须与 `CityDestinationWorldMarker` 共享模型族；不允许另起一套独立任务圈模型。
- 主题冻结为：
  - `task_available_start` -> green flame ring
  - `task_active_objective` -> blue flame ring
  - `destination` -> existing orange theme
- start trigger 支持两类玩家载体：
  - on-foot player body
  - currently driven player vehicle
- world marker runtime 只显示：
  - nearby available start slots
  - tracked active objective

## Scope

做什么：

- 把 destination 火焰圈抽成可复用 shared ring marker 族
- 新增 task start/objective ring runtime
- 实现玩家步行/驾车穿圈触发开始
- 实现 active objective 圈与任务完成清理

不做什么：

- 不做全城所有任务圈常亮
- 不做 NPC/ambient traffic 触发任务
- 不做复杂失败条件

## Acceptance

1. 自动化测试必须证明：任务圈与 destination 圈共享模型族或共享基类 contract。
2. 自动化测试必须证明：绿色 available start 圈与蓝色 active objective 圈能被正式区分。
3. 自动化测试必须证明：玩家步行进入 start slot 会开始任务。
4. 自动化测试必须证明：玩家驾驶当前车辆进入 start slot 也会开始任务。
5. 自动化测试必须证明：完成 objective 后 active marker 与任务状态会按 contract 清理或推进。
6. 自动化测试必须证明：world marker runtime 只处理 nearby/tracked 任务，而不是全量任务常亮。
7. 反作弊条款：不得通过另做第二套 marker、只支持步行、不支持车辆、或直接在测试里手调 `set_task_active()` 来宣称完成。

## Files

- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/navigation/CityDestinationWorldMarker.gd`
- Create: `city_game/world/navigation/CityWorldRingMarker.gd`
- Create: `city_game/world/tasks/runtime/CityTaskTriggerRuntime.gd`
- Create: `city_game/world/tasks/runtime/CityTaskWorldMarkerRuntime.gd`
- Create: `tests/world/test_city_task_world_ring_marker_contract.gd`
- Create: `tests/world/test_city_task_trigger_start_contract.gd`
- Create: `tests/world/test_city_task_vehicle_trigger_start_contract.gd`
- Create: `tests/e2e/test_city_task_start_flow.gd`
- Modify: `docs/plan/v14-index.md`

## Steps

1. 写失败测试（红）
   - 先写 shared ring marker contract、步行触发、车辆触发、任务开始/完成 flow。
2. 运行到红
   - 预期失败点是当前仓库只有 destination marker，没有正式 task trigger runtime。
3. 实现（绿）
   - 把火焰圈抽成 shared ring marker。
   - 新建 task trigger runtime 和 task world marker runtime。
   - 在 `CityPrototype` 里把 nearby available starts 与 tracked active objective 接到 world runtime。
   - 接入 on-foot / vehicle trigger start 与 objective completion。
4. 运行到绿
   - world tests + e2e flow 通过。
5. 必要重构（仍绿）
   - 将 marker theme、trigger query、task state transition 解耦。
6. E2E
   - 串行跑 `test_city_task_start_flow.gd` 与性能三件套。

## Risks

- 如果 task ring 不共享现有火焰圈模型族，视觉和代码都会分叉。
- 如果车辆触发不写进正式 contract，用户要求的“player 或车触碰绿圈即可开始”会直接落空。
- 如果 nearby/tracked 限制不写硬，任务圈 runtime 很容易演变成全量常亮与性能噪声源。
