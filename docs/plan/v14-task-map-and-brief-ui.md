# V14 Task Map And Brief UI

## Goal

在现有 `M` 全屏地图上交付正式 `Tasks` 页签 / Brief 面板、任务状态 pin 和 tracked task 同步，让玩家能在“地图仍可见”的前提下查看待开始、进行中任务并切换追踪。

## PRD Trace

- Direct consumer: REQ-0007-003
- Direct consumer: REQ-0007-004
- Direct consumer: REQ-0007-007
- Guard / Presentation discipline: REQ-0007-008

## Dependencies

- 依赖 M1 已交付正式 `task runtime`。
- 依赖 `v12` 已交付 `CityMapScreen`、`CityMapPinRegistry`、`resolved_target`、`route_result`。
- 本计划完成前，M3 的 world trigger 只能靠 debug/runtime 入口验证，不允许宣称 GTA 风格任务主链闭环。

## Contract Freeze

- full map 必须保持地图画布可见；`Tasks` 以旁侧页签/面板存在，不改成任务整页。
- `Tasks` 面板最小分组冻结为：`当前任务`、`进行中`、`待开始`、`已完成`。
- task pin 最小字段冻结为：`task_id`、`status`、`icon_id`、`title`、`world_position`、`priority`。
- `status -> visual theme` 当前冻结为：
  - `available` -> green
  - `active` -> blue
  - `completed` -> neutral white/gray
- 数据层只传 `icon_id`，不把 emoji 字符写死进 runtime contract。

## Scope

做什么：

- 给 `CityMapScreen` 加正式 `Tasks` 页签/面板
- 把 task runtime 投影为 full map / minimap 的正式 pin overlay
- 支持在任务页签里切换 tracked task
- 让任务选择与 current route target 联动

不做什么：

- 不做奖励结算页
- 不做剧情对话历史
- 不做复杂筛选器矩阵
- 不做新的 route solver

## Acceptance

1. 自动化测试必须证明：`M` 全屏地图打开后存在正式 `Tasks` 面板状态，而不是 debug text。
2. 自动化测试必须证明：地图上至少能区分 `available` 与 `active` task pins。
3. 自动化测试必须证明：`Tasks` 面板数据来自 task runtime，而不是手工 hardcode UI。
4. 自动化测试必须证明：在任务页签里选中任务会同步 tracked task，并驱动 destination / route target。
5. 自动化测试必须证明：task pin 仍走 shared pin registry / map overlay 主链，而不是第二套 map state。
6. 反作弊条款：不得通过把任务列表塞进 HUD debug panel、把地图完全隐藏、或把 task pin 做成静态背景纹理来宣称完成。

## Files

- Modify: `city_game/ui/CityMapScreen.gd`
- Modify: `city_game/ui/CityMapScreen.tscn`
- Modify: `city_game/ui/PrototypeHud.gd`
- Modify: `city_game/world/map/CityMapPinRegistry.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Create: `city_game/ui/CityTaskBriefPanel.gd`
- Create: `city_game/ui/CityTaskBriefPanel.tscn`
- Create: `city_game/world/tasks/presentation/CityTaskBriefViewModel.gd`
- Create: `city_game/world/tasks/presentation/CityTaskPinProjection.gd`
- Create: `tests/world/test_city_task_map_tab_contract.gd`
- Create: `tests/world/test_city_task_pin_projection.gd`
- Create: `tests/world/test_city_task_brief_view_model.gd`
- Create: `tests/e2e/test_city_task_tab_selection_flow.gd`
- Modify: `docs/plan/v14-index.md`

## Steps

1. 写失败测试（红）
   - 先写 map tab contract、task pin projection、brief view model、task tab selection flow。
2. 运行到红
   - 预期失败点是当前 `CityMapScreen` 只有地图画布，没有正式 task panel 和 tracked task sync。
3. 实现（绿）
   - 新增 `CityTaskBriefPanel` 与 task presentation view model。
   - 扩展 `CityMapPinRegistry` 支持正式 task status pin。
   - 在 `CityMapScreen` 里挂入 `Tasks` 面板，并保持地图画布常驻。
   - 把任务选择接入 tracked task / destination 主链。
4. 运行到绿
   - world tests + e2e flow 通过。
5. 必要重构（仍绿）
   - 把 UI view model 与 runtime state 断开，避免地图脚本直接读取原始 definition。
6. E2E
   - 串行跑 `test_city_task_tab_selection_flow.gd` 与受影响的 map/navigation 回归。

## Risks

- 如果 `Tasks` 面板直接读 raw runtime，对后续状态扩展会非常脆弱。
- 如果选择任务不走 `resolved_target + route_result` 主链，M3 的 world trigger 和 objective marker 会漂移。
- 如果地图被做成整页切换，用户要求的“地图旁边加页签”会被违背。
