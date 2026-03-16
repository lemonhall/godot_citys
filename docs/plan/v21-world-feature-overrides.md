# V21 World Feature Overrides

## Goal

交付一条正式的“ground probe -> scene landmark registry/manifest -> near chunk mount -> optional full map pin”主链，让喷泉这类不依赖 `building_id` 的 authored 地标能进入世界；同时把山和湖的未来路线冻结为 sibling family，而不是继续滥用 building override。

## PRD Trace

- Direct consumer: REQ-0012-001
- Direct consumer: REQ-0012-002
- Direct consumer: REQ-0012-003
- Guard / Performance: REQ-0012-004

## Dependencies

- 依赖 `v15` 已冻结激光 inspection 主链。
- 依赖 `v16` 已冻结 registry / manifest / near chunk mount 的资源接入思路。
- 依赖 `v18` 已冻结 `full_map_pin -> icon_id -> glyph` 主链。
- 依赖 `CityChunkRenderer / CityChunkScene` 现有 chunk mount 事件链。

## Contract Freeze

- 地面 inspection result 的正式 kind 冻结为 `ground_probe`。
- `ground_probe` 最小字段冻结为：
  - `inspection_kind`
  - `display_name`
  - `chunk_id`
  - `chunk_key`
  - `world_position`
  - `surface_y_m`
  - `chunk_local_position`
  - `surface_normal`
  - `message_text`
  - `clipboard_text`
- scene landmark registry entry 最小字段冻结为：
  - `landmark_id`
  - `feature_kind`
  - `manifest_path`
  - `scene_path`
- scene landmark manifest 最小字段冻结为：
  - `landmark_id`
  - `display_name`
  - `feature_kind`
  - `anchor_chunk_id`
  - `anchor_chunk_key`
  - `world_position`
  - `scene_path`
  - `manifest_path`
- scene landmark manifest 可选字段冻结为：
  - `far_visibility.enabled`
  - `far_visibility.proxy_scene_path`
  - `far_visibility.visibility_radius_m`
  - `far_visibility.lod_modes`
- `feature_kind` 在 `v21` 首版冻结为 `scene_landmark`。
- scene landmark `full_map_pin` 复用 `v18` contract，并保持 optional。
- scene landmark full-map pin 的 `pin_type` 复用现有 `landmark`，具体图标由 `icon_id` 决定。
- `far_visibility` 的语义冻结为“远距仅渲染廉价 proxy”，禁止把完整近景 scene 直接保活到 mid/far LOD。
- fountain 的 `icon_id` 冻结为 `fountain`，UI glyph 建议为 `⛲`。
- future mountain/lake route 冻结为 `terrain_region_feature` sibling family，不进入本版实现。

## Scope

做什么：

- 把激光地面 inspection 升级为正式 `ground_probe`
- 新增独立于 building override 的 landmark registry/runtime
- 让 chunk near mount 能实例化 landmark scene
- 让 fountain 成为第一个真实 landmark consumer
- 让 fountain 在 full map 上显示 marker
- 冻结 tall landmark 的 `far_visibility` manifest contract，供电视塔等未来 consumer 直接复用
- 补齐 world/e2e/perf 级验证计划

不做什么：

- 不实现 mountain / lake 的 terrain/water runtime
- 不做 landmark minimap pin
- 不做 landmark click route / fast travel / autodrive
- 不做通用世界编辑器 UI
- 不把 tall landmark 的远距可见实现成“完整 scene 永远不卸载”

## Acceptance

1. 自动化测试必须证明：ground hit 返回 `ground_probe` payload，而不是只返回 chunk 级粗文本。
2. 自动化测试必须证明：`surface_y_m` 显式暴露，且与 `world_position.y` 一致；HUD / clipboard 必须带 `y=`，方便后续人工复制摆放高程。
3. 自动化测试必须证明：`chunk_local_position` 可由 `world_position - chunk_center` 稳定复算，不是随手拼的字符串。
4. 自动化测试必须证明：scene landmark registry 能跨 session 重读，并在目标 chunk near mount 时实例化 scene。
5. 自动化测试必须证明：喷泉 manifest / registry / scene path 三者口径一致，并指向正式 fountain scene。
6. 自动化测试必须证明：full map 上能看到 `icon_id = fountain` 的 marker，而 minimap 不会出现它。
7. 自动化测试必须证明：喷泉 mounted 后具备可读视觉包围盒，并且 visual bottom 与地面高度基本对齐，不允许“节点存在但肉眼近似不可见”。
8. 自动化测试必须证明：building inspection/export 以及 service building full-map icon 主链不回退。
9. profiling 三件套必须串行继续过线。
10. 反作弊条款：不得把喷泉挂靠到 fake `building_id`；不得在 `_process()` 每帧扫 registry；不得让喷泉 icon 绕过 manifest 直接写死在 UI；不得在 registry sync 阶段 preview instantiate landmark scene；不得把 mountain/lake 通过一个超大 scene 假装已经有路线。

## Proposed Files

- Create: `docs/prd/PRD-0012-world-feature-ground-probe-and-landmark-overrides.md`
- Create: `docs/plan/v21-index.md`
- Create: `docs/plan/v21-world-feature-overrides.md`
- Create: `docs/plans/2026-03-17-v21-world-feature-overrides-design.md`
- Future Modify: `city_game/world/inspection/CityWorldInspectionResolver.gd`
- Future Modify: `city_game/scripts/CityPrototype.gd`
- Future Create: `city_game/world/features/CitySceneLandmarkRegistry.gd`
- Future Create: `city_game/world/features/CitySceneLandmarkRuntime.gd`
- Future Create: `city_game/serviceability/landmarks/generated/landmark_override_registry.json`
- Future Create: `city_game/serviceability/landmarks/generated/<landmark-id>/landmark_manifest.json`
- Future Create: `city_game/serviceability/landmarks/generated/<landmark-id>/<scene>.tscn`
- Future Modify: `city_game/ui/CityMapScreen.gd`
- Future Create: `tests/world/test_city_ground_probe_inspection_contract.gd`
- Future Create: `tests/world/test_city_scene_landmark_registry_runtime.gd`
- Future Create: `tests/world/test_city_fountain_landmark_manifest_contract.gd`
- Future Create: `tests/world/test_city_fountain_landmark_visual_envelope.gd`
- Future Create: `tests/world/test_city_world_feature_full_map_pin_contract.gd`
- Future Create: `tests/e2e/test_city_scene_landmark_mount_flow.gd`
- Future Create: `tests/e2e/test_city_fountain_landmark_full_map_flow.gd`

## Steps

1. Analysis
   - 固定喷泉 consumer：`chunk_129_142` + `Santo Spirito Fountain.glb`
   - 固定 ground probe 所需字段
   - 固定 mountain/lake 为 future sibling route
2. Design
   - 写 `PRD-0012`
   - 写 v21 design doc，明确 `scene_landmark` vs `terrain_region_feature`
3. Plan
   - 写 `v21-index.md`
   - 写 `v21-world-feature-overrides.md`
4. TDD Red
   - 先写 ground probe contract test
   - 再写 landmark registry/runtime test
   - 再写 fountain manifest/full-map pin tests
   - 最后写 e2e mount/full-map flow
5. TDD Green
   - 实现 ground probe payload
   - 实现 landmark registry/runtime
   - 实现 fountain scene/manifest/registry/full-map pin
6. Refactor
   - 收口 registry decode、chunk filtering、pin delta sync，避免 `CityPrototype` 继续膨胀
7. E2E
   - 跑 fountain mount flow
   - 跑 fountain full-map flow
8. Review
   - 对照 `PRD-0012` 回填追溯矩阵与 verification artifact
   - 检查 mountain/lake 路线是否仍保持 sibling 边界
9. Ship
   - `v21: doc: world feature override plan`
   - 后续实现 slices 再分别 `feat/test/fix`

## Risks

- 如果 ground probe 只加文案不加 formal payload，后续 authored placement 仍然不可自动化。
- 如果 scene landmark runtime 偷偷复用 building override 的 `building_id`，后面会把世界特征和建筑替换身份搅在一起。
- 如果 fountain pin 直接复用 minimap scope，`v18` 的地图边界会被破坏。
- 如果 tall landmark 的远距可见偷懒做成完整 scene 常驻，streaming 与 LOD 预算会被直接打穿。
- 如果 mountain/lake 路线不提前写清，后面很容易为了“快一点出效果”去挂一个超大 scene，直接破坏 terrain/streaming/page provider 纪律。
