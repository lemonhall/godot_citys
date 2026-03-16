# V19 Index

## 愿景

设计入口：[2026-03-16-v19-gun-shop-service-scene-design.md](../plans/2026-03-16-v19-gun-shop-service-scene-design.md)

依赖入口：

- [PRD-0009 Building Serviceability Reconstruction](../prd/PRD-0009-building-serviceability-reconstruction.md)
- [PRD-0011 Custom Building Full-Map Icons](../prd/PRD-0011-custom-building-full-map-icons.md)
- [v16-index.md](./v16-index.md)
- [v18-index.md](./v18-index.md)

`v19` 的目标不是新增一条基础设施，而是把 `bld:v15-building-id-1:seed424242:chunk_134_130:014` 正式收成一栋能挂回城市的枪械店 consumer：场景要从空壳 block 变成可识别的枪店门面与室内，manifest / registry 要指向真实 scene path，并沿 `v18` full-map pin 主链为这栋店提供枪械 icon。

## 决策冻结

- 本轮只做这栋枪店的门面、室内、manifest、registry 和 full-map icon。
- 本轮不做 NPC 店员、不做对话、不做可购买武器逻辑。
- 枪店 front facade 必须有正式门洞与招牌，不能继续保留整块封死前墙。
- 枪店 icon 走 `building_manifest.json.full_map_pin`，不写另一套 gun-shop marker 旁路。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 scene + data contract | 枪店 scene、manifest、registry | 枪店 scene 可加载；manifest / registry 都指向 `枪店_A.tscn`；枪店声明正式 `full_map_pin` | `tests/world/test_city_gun_shop_scene_contract.gd`、`tests/world/test_city_gun_shop_manifest_contract.gd` | done |
| M2 shared pin integration | gun-shop icon 接入 `v18` runtime/full map | full map 上 gun shop 与 cafe icon 共存；runtime 不再假设只有一栋带 icon 的 service building | `tests/world/test_city_service_building_map_pin_runtime.gd`、`tests/world/test_city_service_building_full_map_pin_contract.gd` | done |
| M3 verification | 受影响回归 | 相关 scene / full-map flow 不回退；项目导入检查通过 | `tests/e2e/test_city_service_building_full_map_icon_flow.gd`、Godot headless import check | done |

## 计划索引

- [v19-gun-shop-service-scene.md](./v19-gun-shop-service-scene.md)

## 追溯矩阵

| Req ID | v19 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0009-002 | `v19-gun-shop-service-scene.md` | `tests/world/test_city_gun_shop_scene_contract.gd`、`tests/world/test_city_gun_shop_manifest_contract.gd` | `& $godot --headless --rendering-driver dummy --path $project --quit` | [v19-m3-verification-2026-03-16.md](./v19-m3-verification-2026-03-16.md) | done |
| REQ-0009-003 | `v19-gun-shop-service-scene.md` | `tests/world/test_city_gun_shop_manifest_contract.gd` | `& $godot --headless --rendering-driver dummy --path $project --quit` | [v19-m3-verification-2026-03-16.md](./v19-m3-verification-2026-03-16.md) | done |
| REQ-0011-001 | `v19-gun-shop-service-scene.md` | `tests/world/test_city_gun_shop_manifest_contract.gd` | `tests/world/test_city_service_building_map_pin_runtime.gd` | [v19-m3-verification-2026-03-16.md](./v19-m3-verification-2026-03-16.md) | done |
| REQ-0011-003 | `v19-gun-shop-service-scene.md` | `tests/world/test_city_service_building_full_map_pin_contract.gd` | `tests/e2e/test_city_service_building_full_map_icon_flow.gd` | [v19-m3-verification-2026-03-16.md](./v19-m3-verification-2026-03-16.md) | done |

## ECN 索引

- 当前无。

## 差异列表

- 本轮不做枪店 NPC。
- 本轮不做枪店交互 / 对话 / 购买逻辑。
