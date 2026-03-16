# V15 Laser Designator World Inspection

## Goal

交付正式 `laser designator` 武器模式、building/chunk inspection contract、绿色激光束、剪贴板复制与 `10` 秒 HUD 消息，让玩家能在 3D 世界里直接读取建筑唯一名字、`building_id` 与 chunk 信息。

## PRD Trace

- Direct consumer: REQ-0008-001
- Direct consumer: REQ-0008-002
- Direct consumer: REQ-0008-003
- Guard / Performance: REQ-0008-004

## Dependencies

- 依赖 `v12` 已冻结 `CityAddressGrammar`、`CityPlaceIndexBuilder.resolve_address_target_data()` 与 chunk/address contract。
- 依赖 `v9` 已冻结 weapon mode、ADS、projectile / grenade combat 主链。

## Contract Freeze

- `laser designator` 是第三种正式 weapon mode，不是 debug key。
- building inspection payload 的最小字段冻结为：`inspection_kind / building_id / display_name / address_label / place_id / chunk_id / chunk_key / generation_locator`。
- chunk inspection payload 的最小字段冻结为：`inspection_kind / chunk_id / chunk_key / world_position`。
- HUD message 默认生命周期冻结为 `10.0` 秒。
- clipboard text 必须在每次 inspection 时立即刷新；building clipboard text 必须包含 `building_id`。
- beam 视觉冻结为一次性绿色脉冲束；不引入持续照射、伤害或导航副作用。

## Scope

做什么：

- 在 `PlayerController` 新增 `laser designator` 模式与 request signal
- 在 `CityPrototype` 新增 laser trace、inspection 解析、beam spawn 与 state introspection
- 在 `CityChunkProfileBuilder/CityChunkScene` 给 near building collider 挂 deterministic inspection payload
- 在 `PrototypeHud` 新增短时消息层
- 在 runtime 暴露 `building_id -> generation contract` 的最小查询口
- 新增 world/e2e tests 与 verification 文档

不做什么：

- 不做本地化地址 grammar 重写
- 不做激光伤害或任务/导航联动
- 不在 `v15` 内交付完整的 persistent city JSON / 功能建筑替换系统

## Acceptance

1. 自动化测试必须证明：玩家能切换到正式 `laser designator` 模式，并能通过 request path 发射激光。
2. 自动化测试必须证明：`laser designator` 模式不会继续生成 projectile 或 grenade。
3. 自动化测试必须证明：激光命中 building collider 时，inspection result 返回 `building` kind、非空 `building_id` 与唯一 `display_name`。
4. 自动化测试必须证明：`building_id` 能反查到当前 streamed building 的 generation contract。
5. 自动化测试必须证明：激光命中地面时，inspection result 返回 `chunk` kind 与正式 `chunk_id / chunk_key`，且第二次 inspection 会立即刷新 HUD/clipboard。
6. 自动化测试必须证明：HUD 会显示 inspection 消息，并在 `10` 秒后自动清空。
7. 自动化测试必须证明：现有 grenade / crosshair contract 不回退。
8. 反作弊条款：不得通过只写 debug 文本、只返回 node name、复用 bullet/grenade 节点、或 headless-only 特判来宣称完成。

## Files

- Modify: `city_game/scripts/PlayerController.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/ui/PrototypeHud.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkProfileBuilder.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Create: `city_game/combat/CityLaserDesignatorBeam.gd`
- Create: `city_game/world/inspection/CityWorldInspectionResolver.gd`
- Create: `tests/world/test_city_player_laser_designator.gd`
- Create: `tests/e2e/test_city_laser_designator_flow.gd`
- Modify: `docs/plan/v15-index.md`

## Steps

1. 写失败测试（红）
   - 先写 laser mode、building/chunk inspection、HUD timeout 两类测试。
2. 运行到红
	- 预期失败点是当前仓库没有 `laser designator` weapon mode、没有 HUD message layer、building collider 也没有 inspection payload。
3. 实现（绿）
	- 新增 `laser designator` signal / mode / input。
	- 新增 beam 节点与 inspection resolver。
	- 给 building collider 注入带 `building_id` 与 `generation_locator` 的 deterministic payload。
	- 新增 HUD focus message layer。
	- 把 inspection 结果复制到 clipboard，并保证第二次 inspection 立即覆盖第一次。
4. 运行到绿
	- laser world test + e2e + 相关旧回归通过。
5. 必要重构（仍绿）
   - 把 trace、inspection resolve、HUD message 更新从 `CityPrototype` 内部做职责收口。
6. E2E
   - 跑 `test_city_laser_designator_flow.gd`。
   - 串行跑性能三件套。

## Risks

- 如果 building inspection payload 没有正式 `building_id`，`v15` 会失去后续建筑替换链的锚点价值。
- 如果 HUD message 只复用 debug status，用户可见交付会是假的。
- 如果 beam 逻辑写进现有 projectile/grenade 节点，会把 combat contract 搞脏。
