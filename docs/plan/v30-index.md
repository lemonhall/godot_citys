# V30 Index

## 愿景

PRD 入口：[PRD-0020 Scene Preview Harness](../prd/PRD-0020-scene-preview-harness.md)

设计入口：[2026-03-20-v30-scene-preview-harness-design.md](../plans/2026-03-20-v30-scene-preview-harness-design.md)

`v30` 的目标是把当前零散、一次性的 `F6` 预览逻辑提升成一条正式的通用资产链：任何值得单独观察的 3D 场景，都应该能通过统一的 preview harness 获得光照、环境、自由飞行观察、基础 FPS/frame ms overlay 与可选 subject preview 激活，而不必每次重新在 subject 里手写 `PreviewCamera/PreviewLight/控制逻辑`。`v30` 第一版冻结为“仓库内 scene-first harness + wrapper 生成命令”，不先做 editor plugin。

## 决策冻结

- 首版不做 `addons/` editor plugin
- 正式 harness 冻结为：
  - `city_game/preview/ScenePreviewHarness.tscn`
  - `city_game/preview/ScenePreviewHarness.gd`
- 正式生成命令冻结为 repo-local script：
  - `tools/scene_preview/generate_scene_preview_wrapper.gd`
- subject contract 冻结为可选：
  - `get_scene_preview_contract()`
  - `set_scene_preview_active(active, preview_context={})`
- stats overlay 首版冻结为：
  - `FPS`
  - `frame ms`
- 首个真实迁移样例冻结为：
  - `InterceptorMissileVisual`

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD-0020 / design / v30-index / v30-plan | 文档链完整，`REQ-0020-*` 可追溯 | `rg -n "REQ-0020" docs/prd/PRD-0020-scene-preview-harness.md docs/plan/v30-index.md docs/plan/v30-scene-preview-harness.md` | done |
| M1 harness core | harness scene / subject mount / free-fly camera / stats overlay | harness 可实例化并挂载 target，具备正式 controls 与 overlay | `tests/world/test_scene_preview_harness_contract.gd` | done |
| M2 wrapper command | wrapper 生成脚本 / output scene contract | 指定 source scene 后能正式生成 wrapper `.tscn` | `tests/world/test_scene_preview_wrapper_generator_contract.gd` | done |
| M3 sample migration | missile visual 接入 harness / optional preview contract | `InterceptorMissileVisual` 在新 harness 下能启动 preview 行为 | `tests/world/test_scene_preview_subject_activation_contract.gd` | done |
| M4 regression | missile command 受影响回归 | `v29` 预览与正式玩法不被 v30 污染 | `tests/world/test_city_missile_command_battery_contract.gd`、`tests/world/test_city_missile_command_wave_contract.gd`、`tests/world/test_city_missile_command_damage_contract.gd`、`tests/e2e/test_city_missile_command_wave_flow.gd` | done |

## 计划索引

- [v30-scene-preview-harness.md](./v30-scene-preview-harness.md)

## 追溯矩阵

| Req ID | v30 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0020-001 | `v30-scene-preview-harness.md` | `tests/world/test_scene_preview_harness_contract.gd` | `--script res://tests/world/test_scene_preview_harness_contract.gd` | [v30-m4-verification-2026-03-20.md](./v30-m4-verification-2026-03-20.md) | done |
| REQ-0020-002 | `v30-scene-preview-harness.md` | `tests/world/test_scene_preview_wrapper_generator_contract.gd` | `--script res://tests/world/test_scene_preview_wrapper_generator_contract.gd` | [v30-m4-verification-2026-03-20.md](./v30-m4-verification-2026-03-20.md) | done |
| REQ-0020-003 | `v30-scene-preview-harness.md` | `tests/world/test_scene_preview_harness_contract.gd` | `--script res://tests/world/test_scene_preview_harness_contract.gd` | [v30-m4-verification-2026-03-20.md](./v30-m4-verification-2026-03-20.md) | done |
| REQ-0020-004 | `v30-scene-preview-harness.md` | `tests/world/test_scene_preview_subject_activation_contract.gd` | `--script res://tests/world/test_scene_preview_subject_activation_contract.gd` | [v30-m4-verification-2026-03-20.md](./v30-m4-verification-2026-03-20.md) | done |
| REQ-0020-005 | `v30-scene-preview-harness.md` | `tests/world/test_scene_preview_subject_activation_contract.gd` | `--script res://tests/world/test_city_missile_command_battery_contract.gd` | [v30-m4-verification-2026-03-20.md](./v30-m4-verification-2026-03-20.md) | done |

## ECN 索引

- 当前无

## 差异列表

- `v30` 首版不包含 editor plugin、右键菜单或批量全仓扫描生成 wrapper。
- `v30` 首版优先覆盖 3D scene preview，不承诺 2D/Control preview 一次到位。
