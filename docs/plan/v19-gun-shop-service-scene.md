# V19 Gun Shop Service Scene

## Goal

把 `bld:v15-building-id-1:seed424242:chunk_134_130:014` 从一个只够证明 override 挂载的空壳场景，收口成正式的枪械店 consumer：有门面、有入口、有枪店室内陈列，registry / manifest 指向真实 scene path，并在 full map 上显示枪店 icon。

## PRD Trace

- Direct consumer: REQ-0009-002
- Direct consumer: REQ-0009-003
- Direct consumer: REQ-0011-001
- Direct consumer: REQ-0011-003

## Scope

做什么：

- 重做 `枪店_A.tscn` 的 shell / interior / lighting / signage / anchors
- 修正 gun shop manifest / registry 的 scene path
- 给 gun shop manifest 增加 `full_map_pin`
- 扩展 full-map glyph 映射与相关 tests

不做什么：

- 不做 gun shop NPC / dialogue
- 不做交易系统
- 不做新的 building exporter 行为

## Acceptance

1. 自动化测试必须证明：gun shop manifest 与 registry 都指向 `枪店_A.tscn`，而不是旧的 `building_scene.tscn`。
2. 自动化测试必须证明：gun shop scene 可以直接加载，并且包含正式门洞、招牌、室内陈列、灯光与 service anchors。
3. 自动化测试必须证明：gun shop manifest 声明正式 `full_map_pin`，且 world position 仍来自现有 sidecar contract。
4. 自动化测试必须证明：service building pin runtime 与 full map contract 接受“咖啡馆 + 枪店”并存，而不是假设永远只有一栋自定义建筑上图。
5. 自动化测试必须证明：现有 cafe full-map icon flow 不回退。
6. 反作弊条款：不得只修路径、不改场景；不得把枪店 icon 写死在 UI 而不写 manifest；不得通过空壳 interior 或贴图假招牌来宣称完成。

## Files

- Modify: `city_game/serviceability/buildings/generated/building_override_registry.json`
- Modify: `city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_134_130_014/building_manifest.json`
- Modify: `city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_134_130_014/枪店_A.tscn`
- Modify: `city_game/ui/CityMapScreen.gd`
- Modify: `tests/world/test_city_service_building_map_pin_runtime.gd`
- Modify: `tests/world/test_city_service_building_full_map_pin_contract.gd`
- Create: `tests/world/test_city_gun_shop_scene_contract.gd`
- Create: `tests/world/test_city_gun_shop_manifest_contract.gd`

## Steps

1. 写失败测试（红）
   - 写 `test_city_gun_shop_scene_contract.gd`
   - 写 `test_city_gun_shop_manifest_contract.gd`
   - 修改 `test_city_service_building_map_pin_runtime.gd`
   - 修改 `test_city_service_building_full_map_pin_contract.gd`
2. 运行到红
   - 预期失败点必须明确落在：枪店 scene 还是空壳、manifest / registry path 仍指向旧 scene、gun shop icon 尚未接入。
3. 实现（绿）
   - 重做枪店 scene
   - 修 gun shop manifest / registry
   - 扩 UI glyph 映射
4. 运行到绿
   - 跑 gun shop scene/manifest/full-map 相关 tests
5. 必要重构（仍绿）
   - 收口 scene 结构命名与 test helper，避免 future service building consumer 再走特判。
6. E2E / Verify
   - 跑 `test_city_service_building_full_map_icon_flow.gd`
   - 跑 Godot headless import check

## Risks

- 如果 registry / manifest path 没一起改，世界 mount 与 direct scene load 会出现口径分叉。
- 如果把枪店 icon 直接硬编码到 UI，而不是 manifest opt-in，`v18` 主链会被破坏。
- 如果枪店 scene 只有视觉 mesh 没有 collision / anchors，后续接 NPC 或互动时会重新返工。
