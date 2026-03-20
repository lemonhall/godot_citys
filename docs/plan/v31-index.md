# V31 Index

## 愿景

PRD 入口：[PRD-0021 Scene Preview Editor Plugin](../prd/PRD-0021-scene-preview-editor-plugin.md)

设计入口：[2026-03-20-v31-scene-preview-editor-plugin-design.md](../plans/2026-03-20-v31-scene-preview-editor-plugin-design.md)

`v31` 的目标是把 `v30` 已经冻结好的通用 preview 主链提升成编辑器内的一键入口：以后打开一个可预览的 3D 场景，不需要命令行、不需要手工 wrapper、不需要给 subject 场景额外挂 preview helper，只要在 Godot editor 里点 Preview 按钮，插件就自动把当前编辑态 materialize 成临时 subject snapshot，生成临时 wrapper，并进入正式 preview 玩法态。

## 决策冻结

- `v31` 必须复用 `v30` harness 主链，不允许复制第二套 preview 舞台
- `v31` 首版采用 `EditorPlugin + editor toolbar button`，不先做复杂 dock
- `v31` 首版只承诺 3D scene root（`Node3D` 主链）
- `v31` 必须支持“当前未保存编辑态” preview
- `v31` 临时工件默认写到 `user://scene_preview/editor_subjects/` 与 `user://scene_preview/editor_wrappers/`

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD-0021 / design / v31-index / v31-plan | 文档链完整，`REQ-0021-*` 可追溯 | `rg -n "REQ-0021" docs/prd/PRD-0021-scene-preview-editor-plugin.md docs/plan/v31-index.md docs/plan/v31-scene-preview-editor-plugin.md` | done |
| M1 session builder | eligibility / snapshot / wrapper request 服务 | 当前编辑场景可被解析成正式 preview request | `tests/world/test_scene_preview_editor_session_builder_contract.gd` | done |
| M2 plugin shell | `addons/scene_preview` plugin manifest + toolbar button shell | Godot editor 内具备正式 Preview 按钮入口 | `tests/world/test_scene_preview_editor_plugin_manifest_contract.gd` | done |
| M3 editor play flow | 插件按钮驱动 preview 播放链 | 点按钮能进入基于 `v30` harness 的 preview | `tests/world/test_scene_preview_editor_preview_request_contract.gd` | done |
| M4 regression | `v30` / missile 回归 | editor plugin 不破坏既有 preview 与正式玩法链 | `tests/world/test_scene_preview_harness_contract.gd`、`tests/world/test_scene_preview_wrapper_generator_contract.gd`、`tests/world/test_scene_preview_subject_activation_contract.gd`、`tests/world/test_city_missile_command_battery_contract.gd`、`tests/e2e/test_city_missile_command_wave_flow.gd` | done |

## 计划索引

- [v31-scene-preview-editor-plugin.md](./v31-scene-preview-editor-plugin.md)

## 追溯矩阵

| Req ID | v31 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0021-001 | `v31-scene-preview-editor-plugin.md` | `tests/world/test_scene_preview_editor_plugin_manifest_contract.gd` | `--script res://tests/world/test_scene_preview_editor_plugin_manifest_contract.gd` | [v31-m4-verification-2026-03-20.md](./v31-m4-verification-2026-03-20.md) | done |
| REQ-0021-002 | `v31-scene-preview-editor-plugin.md` | `tests/world/test_scene_preview_editor_session_builder_contract.gd` | `--script res://tests/world/test_scene_preview_editor_session_builder_contract.gd` | [v31-m4-verification-2026-03-20.md](./v31-m4-verification-2026-03-20.md) | done |
| REQ-0021-003 | `v31-scene-preview-editor-plugin.md` | `tests/world/test_scene_preview_editor_preview_request_contract.gd` | `--script res://tests/world/test_scene_preview_editor_preview_request_contract.gd` | [v31-m4-verification-2026-03-20.md](./v31-m4-verification-2026-03-20.md) | done |
| REQ-0021-004 | `v31-scene-preview-editor-plugin.md` | `tests/world/test_scene_preview_editor_session_builder_contract.gd` | `--script res://tests/world/test_scene_preview_editor_session_builder_contract.gd` | [v31-m4-verification-2026-03-20.md](./v31-m4-verification-2026-03-20.md) | done |
| REQ-0021-005 | `v31-scene-preview-editor-plugin.md` | `tests/world/test_scene_preview_harness_contract.gd`、`tests/world/test_city_missile_command_battery_contract.gd` | `--script res://tests/e2e/test_city_missile_command_wave_flow.gd` | [v31-m4-verification-2026-03-20.md](./v31-m4-verification-2026-03-20.md) | done |

## ECN 索引

- 当前无

## 差异列表

- `v31` 首版不承诺 2D/Control scene preview
- `v31` 首版不承诺 dock 面板、历史列表或 screenshot capture
- headless dummy renderer 下，真实 missile editor preview request 仍有资源泄漏告警噪音，但当前 exit code 为 `0`，功能合同已通过
