# V30 Scene Preview Harness

## Goal

交付一条正式的 `v30` 实现计划：在仓库里建立通用的 3D scene preview harness，让未来新组件只需通过一条生成命令连接 harness 和 target scene，就能拥有 `F6` 独立预览、自由飞行视角、基础 FPS/frame ms overlay 和可选 subject preview 激活，不必再为每个 subject 重写 `PreviewCamera/PreviewLight/控制逻辑`。

## PRD Trace

- Direct consumer: REQ-0020-001
- Direct consumer: REQ-0020-002
- Direct consumer: REQ-0020-003
- Direct consumer: REQ-0020-004
- Direct consumer: REQ-0020-005

## Dependencies

- 依赖现有 Godot `PackedScene` / `.tscn` 资产链，保持 scene-first。
- 依赖 `PrototypeHud.gd` 已有 FPS overlay 颜色语义，便于复用口径而不强绑主 HUD。
- 依赖 `InterceptorMissileVisual.gd` 已经存在 preview 行为，便于作为真实 subject 迁移样例。

## Contract Freeze

- 正式 harness 路径冻结为：
  - `res://city_game/preview/ScenePreviewHarness.tscn`
  - `res://city_game/preview/ScenePreviewHarness.gd`
- 正式 wrapper 生成脚本冻结为：
  - `res://tools/scene_preview/generate_scene_preview_wrapper.gd`
- harness 最小节点 contract 冻结为：
  - `PreviewSubjectRoot`
  - `PreviewCameraRig`
  - `PreviewCamera`
  - `PreviewLight`
  - `PreviewEnvironment`
  - `PreviewFloor`
  - `Overlay`
  - `Overlay/FpsLabel`
  - `Overlay/FrameTimeLabel`
- harness 最小 runtime state 冻结为：
  - `subject_scene_path`
  - `subject_loaded`
  - `preview_mouse_captured`
  - `camera_world_position`
  - `camera_forward`
  - `fps_overlay_visible`
  - `fps_sample`
  - `frame_time_ms`
- 可选 subject contract 冻结为：
  - `get_scene_preview_contract()`
  - `set_scene_preview_active(active, preview_context={})`

## Scope

做什么：

- 新增正式 preview harness 场景和脚本
- 新增轻量 stats overlay
- 新增 wrapper 生成脚本
- 新增至少 3 条 tests 锁定 harness / generator / subject activation
- 让 `InterceptorMissileVisual` 接入通用 subject contract
- 新增一个真实 wrapper scene 作为样例（如需要）
- 补 usage 文档

不做什么：

- 不做 Godot editor plugin
- 不做通用 profiler dashboard
- 不做批量为整个仓库所有场景自动建 wrapper
- 不强制所有 subject 场景都改代码

## Acceptance

1. 自动化测试必须证明：正式 harness scene 可实例化，且最小节点 contract 齐全。
2. 自动化测试必须证明：harness 可以正式挂载任意 target `PackedScene`，而不是只持有字符串路径。
3. 自动化测试必须证明：preview camera 响应鼠标 look、`WASD` 平移、`Q/E` 升降、`Shift` 加速、`Esc` 鼠标释放。
4. 自动化测试必须证明：当 subject 自身发生平移时，harness 相机会按 follow contract 跟随。
5. 自动化测试必须证明：FPS/frame ms overlay 存在并持续更新。
6. 自动化测试必须证明：wrapper 生成脚本可为给定 source scene 生成可加载的 wrapper `.tscn`。
7. 自动化测试必须证明：支持 subject contract 的目标会被 harness 正式激活 preview 行为。
8. 自动化测试必须证明：`InterceptorMissileVisual` 在新 harness 下能启动导弹飞行/尾焰 preview，而不是只能靠它自己当 root 时才预览。
9. 自动化测试必须证明：现有 `v29` missile command 主链回归不被污染。
10. 反作弊条款：不得只新增一份 demo scene 却没有通用 harness；不得只写一个命令说明却没有实际生成脚本；不得把所有 preview helper 继续塞进各个 subject 后宣称“复用机制已建立”。

## Files

- Create: `docs/prd/PRD-0020-scene-preview-harness.md`
- Create: `docs/plans/2026-03-20-v30-scene-preview-harness-design.md`
- Create: `docs/plan/v30-index.md`
- Create: `docs/plan/v30-scene-preview-harness.md`
- Create: `city_game/preview/ScenePreviewHarness.tscn`
- Create: `city_game/preview/ScenePreviewHarness.gd`
- Create: `tools/scene_preview/generate_scene_preview_wrapper.gd`
- Modify: `city_game/assets/minigames/missile_command/projectiles/InterceptorMissileVisual.gd`
- Create or Generate: `city_game/assets/minigames/missile_command/projectiles/InterceptorMissileVisualPreview.tscn`
- Create: `tests/world/test_scene_preview_harness_contract.gd`
- Create: `tests/world/test_scene_preview_wrapper_generator_contract.gd`
- Create: `tests/world/test_scene_preview_subject_activation_contract.gd`

## Steps

1. Analysis
   - 固定第一版采用 harness + wrapper 生成脚本，不先做 editor plugin。
   - 固定最小 subject contract、overlay 字段和控制键位。
2. Design
   - 写 `PRD-0020`、design doc、`v30-index`、`v30 plan`。
3. TDD Red
   - 先写 harness contract test。
   - 再写 wrapper generator contract test。
   - 再写 subject activation contract test。
4. Run Red
   - 逐条运行新测试，确认失败原因是 `v30` 尚未实现。
5. TDD Green
   - 实现 harness scene/script。
   - 实现 wrapper 生成脚本。
   - 给 `InterceptorMissileVisual` 增加可选 subject contract。
   - 生成/提交真实 wrapper sample。
6. Refactor
   - 收口 preview 控制与 runtime state，避免在 subject 里继续膨胀通用逻辑。
7. E2E / Regression
   - 跑 `v30` 新 tests。
   - 跑 `v29` missile command battery / wave / damage / e2e flow。
8. Review
   - 更新 `v30-index` traceability 和验证证据。
   - 如后续决定升级为 editor plugin，走新版本或 ECN，不在 `v30` 偷扩范围。
9. Ship
   - `v30: doc: freeze scene preview harness scope`
   - `v30: test: add preview harness contracts`
   - `v30: feat: add scene preview harness and wrapper generator`

## Risks

- 如果第一版直接冲 editor plugin，范围会膨胀且难以自动化验证。
- 如果 harness 不支持普通零代码场景，只支持实现了新接口的 subject，这套机制会很快失去普适性。
- 如果不把 overlay 与 controls 做成正式 contract，未来还是会再次“一场景一套手写 preview”。
- 如果 `InterceptorMissileVisual` 不接入新 harness，`v30` 的真实价值很难被证明。
