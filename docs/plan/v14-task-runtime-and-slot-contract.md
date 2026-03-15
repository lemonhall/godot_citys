# V14 Task Runtime And Slot Contract

## Goal

交付正式 `task catalog / task slot / task runtime / tracked task` 数据主链，让 `v14` 的任务系统第一次拥有可重复、可查询、可测试的上游，而不再只是 map debug pin。

## PRD Trace

- Direct consumer: REQ-0007-001
- Direct consumer: REQ-0007-002
- Guard / Runtime discipline: REQ-0007-008

## Dependencies

- 依赖 `v12` 已交付 `resolved_target + route_result + shared pin registry` 主链。
- 依赖 `v13` 当前世界 morphology 已收口，保证首批 task slot 有可信空间锚点。
- 本计划完成前，M2/M3 不允许宣称已有正式任务页签或正式任务 world trigger。

## Contract Freeze

- `task definition` 的正式最小字段冻结为：`task_id`、`title`、`summary`、`icon_id`、`initial_status`、`start_slot`、`objective_slots`。
- `task slot` 的正式最小字段冻结为：`slot_id`、`slot_kind`、`world_anchor`、`trigger_radius_m`、`marker_theme`、`route_target_override`。
- `task runtime` 的最小状态集冻结为：`available`、`active`、`completed`。
- active task 在任意时刻最多只能有一个；`v14` 首版不做并行 active tasks。
- `task slot` 查询必须支持按 world rect / active chunk 检索；禁止每帧全量遍历全部任务。

## Scope

做什么：

- 新增 `task catalog`、`task slot index`、`task runtime`
- 冻结首版 sample task 数据模型
- 提供按状态/按空间查询任务与 slot 的正式接口
- 提供当前 tracked / active task 的正式 contract

不做什么：

- 不做任务 UI
- 不做 world marker 渲染
- 不做多阶段剧情、奖励或失败条件
- 不做磁盘存档

## Acceptance

1. 自动化测试必须证明：相同 seed 下 `task_id/slot_id/world_anchor` 稳定可复现。
2. 自动化测试必须证明：任务可按 `available -> active -> completed` 正式转移，而不是只改 UI 文案。
3. 自动化测试必须证明：task runtime 可按状态与空间查询任务/slot。
4. 自动化测试必须证明：active task 在任意时刻最多一个。
5. 反作弊条款：不得通过 hardcode 测试任务、每帧全量扫描全部任务、或把状态藏在 UI node 里来宣称完成。

## Files

- Modify: `city_game/world/generation/CityWorldGenerator.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Create: `city_game/world/tasks/model/CityTaskCatalog.gd`
- Create: `city_game/world/tasks/model/CityTaskDefinition.gd`
- Create: `city_game/world/tasks/model/CityTaskRuntime.gd`
- Create: `city_game/world/tasks/model/CityTaskSlotIndex.gd`
- Create: `city_game/world/tasks/generation/CityTaskCatalogBuilder.gd`
- Create: `tests/world/test_city_task_catalog_contract.gd`
- Create: `tests/world/test_city_task_slot_seed_stability.gd`
- Create: `tests/world/test_city_task_runtime_state_machine.gd`
- Modify: `docs/plan/v14-index.md`

## Steps

1. 写失败测试（红）
   - 先写 `task catalog` contract、seed stability、state machine 三类测试。
2. 运行到红
   - 预期失败点是当前仓库没有正式 `task runtime` 和 `task slot index`。
3. 实现（绿）
   - 新建 `task catalog`、`task slot index`、`task runtime`。
   - 在 world bootstrap 阶段挂入首批 sample task 数据。
   - 在 `CityPrototype` 暴露 runtime/query 入口。
4. 运行到绿
   - world tests 全绿，且 active task contract 可被稳定读取。
5. 必要重构（仍绿）
   - 把 query、runtime、sample data 分层，避免后续 UI 直接依赖原始 definition。
6. E2E
   - 当前计划不单独要求 E2E；M2/M3 会消费本计划产物并完成用户流程验证。

## Risks

- 如果 `task slot` 不先写硬，M2/M3 一定会退回 scene-local marker。
- 如果 runtime 允许多个 active task，地图页签和世界 marker 的 tracked 语义会立刻变脏。
- 如果查询依赖每帧全量遍历，world marker 与 minimap 接入后会直接带来性能噪声。
