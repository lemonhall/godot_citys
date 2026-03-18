# V25 Index

## 愿景

PRD 入口：[PRD-0015 Soccer Ball Interactive Prop](../prd/PRD-0015-soccer-ball-interactive-prop.md)

设计入口：[2026-03-18-v25-interactive-prop-design.md](../plans/2026-03-18-v25-interactive-prop-design.md)

依赖入口：

- [PRD-0010 NPC Interaction Dialogue](../prd/PRD-0010-npc-interaction-dialogue.md)
- [PRD-0012 World Feature Ground Probe And Landmark Overrides](../prd/PRD-0012-world-feature-ground-probe-and-landmark-overrides.md)
- [v21-index.md](./v21-index.md)

`v25` 的目标是把“世界里放一个足球并能踢动它”做成正式产品链，而不是一次性脚本 hack。当前推荐路线不是复用 `scene_landmark` 名词，而是新增一个 sibling family：`scene_interactive_prop`。它复用 `registry -> manifest -> near chunk mount -> scene` 这套 authored 世界接入思路，但语义明确是“可互动道具”，不是“可发现地标”。`v25` 的首个 consumer 只做一个足球：模型正式归置、落点固定到 `chunk_129_139` 的用户探针位置、靠近后出现 `E` prompt、触发 kick 后球会按真实物理 impulse 滚动/弹跳。首版不做球门、比赛、得分、存档和跨 chunk ownership。

当前状态：`M0-M3` 已实现，并已通过 `ECN-0024` 完成 oversized 尺寸 rebaseline 的 fresh verification；`scene_interactive_prop` 已作为正式 sibling family 落地到 registry/runtime/chunk mount/primary interaction 主链，首个 consumer 足球已可在 `chunk_129_139` 挂载并以大号玩法尺寸被玩家踢动。

## 决策冻结

- `v25` 新增 sibling family：`scene_interactive_prop`。
- 足球正式 `prop_id` 冻结为 `prop:v25:soccer_ball:chunk_129_139`。
- 足球 authored anchor 冻结为：
  - `chunk_id = chunk_129_139`
  - `chunk_key = (129,139)`
  - `world_position = (-1877.94, 2.52, 618.57)`
  - `surface_normal = (-0.02, 1.00, -0.02)`
- `world_position` 语义冻结为地面 anchor；球心抬离地面的位移通过 `scene_root_offset` 表达。
- [已由 ECN-0024 变更] 足球尺寸冻结为 oversized 可读玩法尺寸：
  - `target_diameter_m = 1.20`
  - `scene_root_offset.y = 0.60`
- 足球不走 full map / minimap pin，不走 landmark，不走 building override。
- 首版交互键继续复用 `E`，并接入正式 primary interaction 合流，不另造第三套 prompt UI。
- 首版 kick 必须基于真实物理 impulse，不允许瞬移或脚本直写终点。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | `PRD-0015`、design、`v25-index`、`v25` plan、traceability | 4 份文档全部落地且 `REQ-0015-*` 可追溯 | `rg -n "REQ-0015" docs/prd/PRD-0015-soccer-ball-interactive-prop.md docs/plan/v25-index.md docs/plan/v25-soccer-ball-interactive-prop.md` | done |
| M1 interactive prop mount chain | 新 family registry/runtime、soccer manifest/scene、near chunk mount | 足球可在 `chunk_129_139` 被正式 mounted，并带稳定 `prop_id` 元数据 | `tests/world/test_city_scene_interactive_prop_registry_runtime.gd`、`tests/world/test_city_soccer_ball_manifest_contract.gd` | done |
| M2 kick interaction | HUD prompt、primary interaction 合流、kick impulse、基础物理反馈 | 靠近足球可见 `E` prompt，触发后球具有显著速度/位移变化 | `tests/world/test_city_soccer_ball_kick_contract.gd`、`tests/e2e/test_city_soccer_ball_interaction_flow.gd` | done |
| M3 guard verification | NPC prompt、scene landmark、streaming 主链不回退 | 新增测试全绿，受影响旧测试继续通过 | 受影响 world/e2e tests fresh rerun | done |

## 计划索引

- [v25-soccer-ball-interactive-prop.md](./v25-soccer-ball-interactive-prop.md)

## 追溯矩阵

| Req ID | v25 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0015-001 | `v25-soccer-ball-interactive-prop.md` | `tests/world/test_city_scene_interactive_prop_registry_runtime.gd` | `--script res://tests/e2e/test_city_soccer_ball_interaction_flow.gd` | [v25-m4-verification-2026-03-18.md](./v25-m4-verification-2026-03-18.md) | done |
| REQ-0015-002 | `v25-soccer-ball-interactive-prop.md` | `tests/world/test_city_soccer_ball_manifest_contract.gd` | `--script res://tests/world/test_city_soccer_ball_visual_envelope.gd` | [v25-m4-verification-2026-03-18.md](./v25-m4-verification-2026-03-18.md) | done |
| REQ-0015-003 | `v25-soccer-ball-interactive-prop.md` | `tests/world/test_city_soccer_ball_kick_contract.gd` | `--script res://tests/e2e/test_city_soccer_ball_interaction_flow.gd` | [v25-m4-verification-2026-03-18.md](./v25-m4-verification-2026-03-18.md) | done |
| REQ-0015-004 | `v25-soccer-ball-interactive-prop.md` | 受影响 NPC / scene landmark / streaming tests | 受影响 world/e2e tests fresh rerun | [v25-m4-verification-2026-03-18.md](./v25-m4-verification-2026-03-18.md) | done |

## ECN 索引

- [ECN-0024 V25 Soccer Ball Scale Readability Rebaseline](../ecn/ECN-0024-v25-soccer-ball-scale-readability.md)

## 差异列表

- `v25` 仍然不包含球门、规则、比分、存档、跨 chunk ownership 与地图图标；这些继续视为后续版本范围。
