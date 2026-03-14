# V8 Vehicle Asset Foundation

## Goal

把当前新增的 8 个车辆 `glb` 从“仓库根目录临时落地素材”，提升为 `v8` 可以稳定引用的正式车辆资产：目录结构明确、命名稳定、manifest 完整、现实尺度基线可追溯。

## PRD Trace

- REQ-0003-001

## Scope

做什么：

- 把 8 个 `glb` 按 `civilian / service / commercial` 分类归档
- 建立 `vehicle_model_manifest.json`
- 为每个模型记录 `source_dimensions_m`、`source_ground_offset_m`、`target_length_m`、`runtime_uniform_scale`
- 输出资产目录说明文档

不做什么：

- 不在本计划里接线 traffic runtime
- 不做材质重制、LOD 烘焙、轮胎骨骼、碰撞网格优化
- 不做 `glb -> tscn` 包装场景

## Acceptance

1. 仓库根目录不再保留这批车辆 `glb` 素材，全部迁入正式资产目录。
2. `vehicle_model_manifest.json` 覆盖 8 个模型，且每个条目都包含 `model_id`、`file`、`traffic_role`、`source_dimensions_m`、`source_ground_offset_m`、`target_length_m`、`runtime_uniform_scale`。
3. `README.md` 明确说明目录约定、命名约定和尺度口径。
4. 反作弊条款：不得通过“只移动文件不建 manifest”“只建 manifest 但根目录仍然留散落素材”或“把尺寸写成模糊备注而不是结构化字段”来宣称完成。

## Files

- Modify: `city_game/assets/vehicles/civilian/*.glb`
- Modify: `city_game/assets/vehicles/service/*.glb`
- Modify: `city_game/assets/vehicles/commercial/*.glb`
- Create: `city_game/assets/vehicles/vehicle_model_manifest.json`
- Create: `city_game/assets/vehicles/README.md`
- Create: `tests/world/test_city_vehicle_asset_manifest.gd`

## Steps

1. 写失败测试（红）
   - 新增 `test_city_vehicle_asset_manifest.gd`，先钉死“根目录不得再出现车辆 `glb`”和“manifest 必须覆盖全部 8 个模型”。
2. 运行到红
   - 当前工作区在素材归档前应因根目录散落文件或 manifest 缺失而失败。
3. 实现（绿）
   - 迁移文件、重命名、补 manifest 和说明文档。
4. 运行到绿
   - `test_city_vehicle_asset_manifest.gd` 通过，`rg --files city_game/assets/vehicles` 与根目录检查都符合预期。
5. 必要重构（仍绿）
   - 收敛命名和分类，避免未来继续出现素材命名漂移。
6. E2E
   - 本计划无运行期 E2E；验证以资产结构和 manifest 为准。

## Risks

- 如果尺度口径不结构化，后续 `CityVehicleVisualCatalog` 会重复发明归一化逻辑。
- 如果继续保留根目录散落素材，未来很容易再次出现“引用临时文件而不是正式 asset”。
- 如果一开始就承诺过多 runtime 行为，素材计划会被错误地拉成玩法计划。

## Progress Notes

- 2026-03-14 当前工作区已预先完成本计划的资产清场动作：8 个 `glb` 已迁入 `city_game/assets/vehicles/`，并建立 manifest / README；后续代码接线时只需把这套资产 contract 接进 visual catalog。
