# V21 Index

## 愿景

PRD 入口：[PRD-0012 World Feature Ground Probe And Landmark Overrides](../prd/PRD-0012-world-feature-ground-probe-and-landmark-overrides.md)

设计入口：[2026-03-17-v21-world-feature-overrides-design.md](../plans/2026-03-17-v21-world-feature-overrides-design.md)

依赖入口：

- [PRD-0008 Laser Designator World Inspection](../prd/PRD-0008-laser-designator-world-inspection.md)
- [PRD-0009 Building Serviceability Reconstruction](../prd/PRD-0009-building-serviceability-reconstruction.md)
- [PRD-0011 Custom Building Full-Map Icons](../prd/PRD-0011-custom-building-full-map-icons.md)
- [v15-index.md](./v15-index.md)
- [v16-index.md](./v16-index.md)
- [v18-index.md](./v18-index.md)

`v21` 的目标是把“非 building authored 内容”正式接进世界。第一批真实 consumer 是喷泉：它不依赖某个 `building_id`，而是以独立地标 scene 的身份挂到 `chunk_129_142`，full map 上还能出现喷泉 icon。与此同时，激光指示器对地面命中不再只告诉用户 chunk id，而要给出正式 `ground_probe` payload，让 authored placement 有稳定坐标输入。山和湖不在本版实现，但路线冻结为 future sibling family：共享 ground probe，单独走 terrain / water feature 链。

## 决策冻结

- `v21` 首版只实现 `scene_landmark`，不实现 mountain / lake runtime。
- `v21` 首版的地标首个真实 consumer 冻结为喷泉，资产路径是 `res://city_game/assets/environment/source/fountains/Santo Spirito Fountain.glb`。
- 喷泉目标 chunk 冻结为 `chunk_129_142`。
- 地面 inspection 必须升级为正式 `ground_probe`，最小字段冻结为：`chunk_id / chunk_key / world_position / chunk_local_position / surface_normal`。
- `scene_landmark` 的 full-map pin 为 manifest opt-in；喷泉需要 pin，山和湖当前不需要。
- minimap 不纳入 `v21` 范围。
- mountain / lake 的 future route 冻结为 `terrain_region_feature` sibling family，而不是把一个超大 scene 挂到 landmark runtime。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 ground probe contract | laser ground hit payload、clipboard text、building hit guard | ground probe 暴露正式字段；building inspection 不回退 | `tests/world/test_city_ground_probe_inspection_contract.gd`、`tests/world/test_city_player_laser_designator.gd` | todo |
| M2 scene landmark runtime | landmark registry、manifest、chunk near mount | scene landmark 能跨 session 重新加载，并在 near chunk mount 时实例化 | `tests/world/test_city_scene_landmark_registry_runtime.gd`、`tests/e2e/test_city_scene_landmark_mount_flow.gd` | todo |
| M3 fountain consumer + full map pin | 喷泉场景、manifest、registry、full map marker | `chunk_129_142` 的喷泉挂入世界；full map 出现喷泉 icon；minimap 不泄漏 | `tests/world/test_city_fountain_landmark_manifest_contract.gd`、`tests/world/test_city_world_feature_full_map_pin_contract.gd`、`tests/e2e/test_city_fountain_landmark_full_map_flow.gd` | todo |
| M4 verification | 受影响 inspection/map/perf 回归 | `v15/v16/v18` 主链不回退；profiling 三件套继续过线 | `tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | todo |

## 计划索引

- [v21-world-feature-overrides.md](./v21-world-feature-overrides.md)

## 追溯矩阵

| Req ID | v21 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0012-001 | `v21-world-feature-overrides.md` | `tests/world/test_city_ground_probe_inspection_contract.gd` | `--script res://tests/world/test_city_player_laser_designator.gd` | — | todo |
| REQ-0012-002 | `v21-world-feature-overrides.md` | `tests/world/test_city_scene_landmark_registry_runtime.gd` | `--script res://tests/e2e/test_city_scene_landmark_mount_flow.gd` | — | todo |
| REQ-0012-003 | `v21-world-feature-overrides.md` | `tests/world/test_city_fountain_landmark_manifest_contract.gd`、`tests/world/test_city_world_feature_full_map_pin_contract.gd` | `--script res://tests/e2e/test_city_fountain_landmark_full_map_flow.gd` | — | todo |
| REQ-0012-004 | `v21-world-feature-overrides.md` | `tests/world/test_city_player_laser_designator.gd`、`tests/world/test_city_service_building_full_map_pin_contract.gd` | `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | — | todo |

## ECN 索引

- 当前无。

## 差异列表

- `v21` 不实现 mountain / lake 的 terrain / water runtime，只冻结 sibling 路线。
- `v21` 不做 landmark minimap pin。
- `v21` 不做 landmark click-to-route / fast travel / autodrive。
