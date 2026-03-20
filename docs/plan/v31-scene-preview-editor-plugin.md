# V31 Scene Preview Editor Plugin

## Goal

交付一条正式的 `v31` 实现计划：在仓库里建立 Godot `EditorPlugin` 入口，让用户在编辑器里打开一个 3D 场景后，只需点击 Preview 按钮，就能自动走完当前编辑态 snapshot、临时 wrapper、`v30` harness 播放与 optional subject preview contract 激活整条链路，不再手工生成/维护 preview wrapper。

## PRD Trace

- Direct consumer: REQ-0021-001
- Direct consumer: REQ-0021-002
- Direct consumer: REQ-0021-003
- Direct consumer: REQ-0021-004
- Direct consumer: REQ-0021-005

## Dependencies

- 依赖 `v30` 已经完成的：
  - `res://city_game/preview/ScenePreviewHarness.tscn`
  - `res://city_game/preview/ScenePreviewHarness.gd`
  - `res://tools/scene_preview/generate_scene_preview_wrapper.gd`
  - optional subject preview contract
- 依赖 Godot `EditorPlugin` / `plugin.cfg` 资产链
- 依赖当前仓库的 headless contract test 习惯，把 editor shell 外的大部分逻辑压回可测试服务层

## Contract Freeze

- 正式插件入口冻结为：
  - `res://addons/scene_preview/plugin.cfg`
  - `res://addons/scene_preview/plugin.gd`
- 正式 editor service 冻结为：
  - `res://addons/scene_preview/ScenePreviewEditorEligibility.gd`
  - `res://addons/scene_preview/ScenePreviewEditorSessionBuilder.gd`
- 正式按钮语义冻结为：
  - 当前 3D scene 可 preview：按钮启用
  - 无场景 / 非 3D root / snapshot 失败：按钮禁用或明确反馈原因
- 临时输出路径冻结为：
  - `user://scene_preview/editor_subjects/`
  - `user://scene_preview/editor_wrappers/`

## Scope

做什么：

- 新增正式 `addons/scene_preview` 插件
- 新增 editor eligibility / session builder 服务
- 新增 editor 按钮入口
- 新增当前编辑态 snapshot 主链
- 新增至少 3 条测试锁定 plugin manifest / session builder / preview request
- 跑 `v30` 与 missile 受影响回归
- 补文档与验证证据

不做什么：

- 不做多页 dock 面板
- 不做 2D/Control 一次性全覆盖
- 不做截图录屏或深度 profiler
- 不把临时 preview wrapper 写进 `res://`

## Acceptance

1. 自动化测试必须证明：`plugin.cfg` 存在且正式指向插件脚本。
2. 自动化测试必须证明：当前编辑 scene root 可被 eligibility resolver 判定为 `eligible / ineligible`，且有明确 reason。
3. 自动化测试必须证明：当前编辑态可 materialize 成临时 subject snapshot，而不是只能依赖原始磁盘 scene。
4. 自动化测试必须证明：session builder 组装出的 preview request 最终引用正式 `v30` harness。
5. 自动化测试必须证明：临时 wrapper / snapshot 默认写到 `user://scene_preview/*`，而不是 `res://`。
6. 自动化测试必须证明：支持 subject contract 的真实资产在 editor preview request 下仍会被正式激活。
7. 自动化测试必须证明：`v30` 的 harness / wrapper / subject activation contracts 继续通过。
8. 自动化测试必须证明：Missile Command 受影响回归继续通过。
9. 反作弊条款：不得仅仅给 editor 加一个按钮文本而没有正式 session builder；不得复制一份独立 preview 场景到 `addons/`；不得要求用户先手工保存/生成 wrapper 才能点按钮。

## Files

- Create: `docs/prd/PRD-0021-scene-preview-editor-plugin.md`
- Create: `docs/plans/2026-03-20-v31-scene-preview-editor-plugin-design.md`
- Create: `docs/plan/v31-index.md`
- Create: `docs/plan/v31-scene-preview-editor-plugin.md`
- Create: `addons/scene_preview/plugin.cfg`
- Create: `addons/scene_preview/plugin.gd`
- Create: `addons/scene_preview/ScenePreviewEditorEligibility.gd`
- Create: `addons/scene_preview/ScenePreviewEditorSessionBuilder.gd`
- Modify: `project.godot`（如需登记插件 enable 状态或相关 editor setting）
- Modify: `tools/scene_preview/generate_scene_preview_wrapper.gd` 或抽共用 service
- Create: `tests/world/test_scene_preview_editor_plugin_manifest_contract.gd`
- Create: `tests/world/test_scene_preview_editor_session_builder_contract.gd`
- Create: `tests/world/test_scene_preview_editor_preview_request_contract.gd`
- Modify: `docs/plan/v31-index.md` closeout 证据

## Steps

1. Analysis
   - 固定 `v31` 只做 editor plugin 入口升级，不重写 `v30` harness。
   - 固定首版目标为“一键 preview 当前 3D scene”，并把未保存编辑态纳入正式范围。
2. Design
   - 写 `PRD-0021`、design doc、`v31-index`、`v31 plan`。
3. TDD Red
   - 先写 plugin manifest contract test。
   - 再写 session builder contract test。
   - 再写 preview request / harness reuse contract test。
4. Run Red
   - 逐条运行新测试，确认失败原因是 `v31` 尚未实现。
5. TDD Green
   - 实现 eligibility 服务。
   - 实现 session builder。
   - 实现 `EditorPlugin` 按钮壳。
   - 接上 editor play custom scene 主链。
6. Refactor
   - 收口 editor-only 代码，保证 plugin 壳保持薄。
   - 如需复用 `v30` generator，抽正式共用服务而不是 copy/paste。
7. Regression
   - 跑 `v31` 新 tests。
   - 重跑 `v30` harness / wrapper / subject activation。
   - 重跑 Missile Command 受影响 world/e2e 回归。
8. Review
   - 更新 `v31-index` traceability 与验证证据。
   - 如果 editor API 现实与计划不符，走 ECN 或 `v32`，不在实现阶段偷改 DoD。
9. Ship
   - `v31: doc: freeze scene preview editor plugin scope`
   - `v31: test: add editor plugin preview contracts`
   - `v31: feat: add editor preview plugin`

## Risks

- editor plugin 本体可测性弱于纯 runtime 代码，必须尽量把逻辑拆到服务层。
- 如果 session builder 不能覆盖未保存编辑态，按钮价值会明显打折。
- 如果插件不复用 `v30` 主链，会迅速形成 editor preview / CLI preview 双轨漂移。
- 如果临时工件落到 `res://`，很快会把仓库污染成一堆 preview 垃圾文件。
