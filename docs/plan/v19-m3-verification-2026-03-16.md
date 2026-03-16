# V19 Verification 2026-03-16

## Scope

本轮验证覆盖：

- gun shop scene / manifest / registry contract
- service building full-map pin multi-building contract
- minimap / startup-delay regressions
- Godot headless import check

## Fresh Commands And Results

| Command / Test | Result | Evidence |
|---|---|---|
| `--script res://tests/world/test_city_gun_shop_scene_contract.gd` | PASS | 枪店 scene 可加载，具备门洞、橱窗、招牌、室内陈列、灯光与 service anchors |
| `--script res://tests/world/test_city_gun_shop_manifest_contract.gd` | PASS | manifest / registry 都指向 `枪店_A.tscn`，并声明 `full_map_pin.icon_id = gun_shop` |
| `--script res://tests/world/test_city_service_building_map_pin_runtime.gd` | PASS | service building pin runtime 现已接受 `cafe + gun_shop` 双 pin fixtures |
| `--script res://tests/world/test_city_service_building_full_map_pin_contract.gd` | PASS | full map render state 同时暴露 `cafe -> ☕` 与 `gun_shop -> 🔫` |
| `--script res://tests/e2e/test_city_service_building_full_map_icon_flow.gd` | PASS | 现有 cafe full-map icon 用户流不回退 |
| `--script res://tests/world/test_city_map_pin_overlay.gd` | PASS | shared pin registry / minimap overlay contract 不回退 |
| `--script res://tests/world/test_city_minimap_idle_contract.gd` | PASS | idle minimap 仍无默认 service-building pin 污染 |
| `--script res://tests/world/test_city_service_building_map_pin_startup_delay_contract.gd` | PASS | full map 关闭的 early window 内仍不读 manifest |
| `--headless --rendering-driver dummy --path $project --quit` | PASS | 项目导入与场景解析通过，无新 scene parse 错误 |

## Outcome

- M1：通过
- M2：通过
- M3：通过

## Notes

- gun shop registry / manifest 的 `scene_path` 已统一收口到 `枪店_A.tscn`，不再保留旧的 `building_scene.tscn` 占位路径。
- gun shop manifest 已沿 `v18` 正式主链接入 `full_map_pin`。
- 现有 cafe flow、minimap idle 与 startup-delay no-IO contract 未回退。
