# ECN-0024: V25 Soccer Ball Scale Readability Rebaseline

## 基本信息

- **ECN 编号**：ECN-0024
- **关联 PRD**：PRD-0015
- **关联 Req ID**：REQ-0015-002、REQ-0015-003
- **发现阶段**：v25 closeout 后用户实机场景反馈
- **日期**：2026-03-18

## 变更原因

`v25` 首版把足球冻结在接近真实足球的视觉直径（约 `0.22m`）。自动化测试与 authored manifest 口径一致，但用户实际进入游戏后明确反馈“太小”，即使在 scene 里手动把节点放大，运行时仍会被 `SoccerBallProp.gd` 的规范化逻辑覆盖回 `target_diameter_m` 对应的尺寸。

这说明原 freeze 虽然技术上正确，但产品上不满足当前玩法可读性要求。用户已明确要求：足球实际尺寸“起码要 `x5` 倍以上”。因此 `v25` 的尺寸口径不再是“真实足球大小”，而改为“刻意 oversized 的玩法尺寸”，优先保证世界里一眼可见、靠近可读、踢动反馈明显。

## 变更内容

### 原设计

- 足球视觉 envelope 接近真实足球大小。
- `target_diameter_m = 0.22`
- `scene_root_offset.y = 0.11`

### 新设计

- 足球视觉 envelope 冻结为明显 oversized 的玩法尺寸。
- 足球 target diameter 冻结为 `1.20m`，满足“至少 `x5` 倍于原尺寸”。
- 地面 authored anchor 语义不变，仍然是用户给定的 ground probe。
- 为保持球体不埋地，`scene_root_offset.y` 同步冻结为 `0.60m`，即大球半径。
- visual envelope 测试阈值同步改为围绕 `1.20m` 的可读区间，而不是围绕真实足球尺寸。

## 影响范围

- 受影响的 Req ID：
  - `REQ-0015-002`
  - `REQ-0015-003`
- 受影响的 v25 计划：
  - `docs/plan/v25-index.md`
  - `docs/plan/v25-soccer-ball-interactive-prop.md`
- 受影响的测试：
  - `tests/world/test_city_soccer_ball_manifest_contract.gd`
  - `tests/world/test_city_soccer_ball_visual_envelope.gd`
  - `tests/world/test_city_soccer_ball_kick_contract.gd`
  - `tests/e2e/test_city_soccer_ball_interaction_flow.gd`
- 受影响的代码文件：
  - `city_game/serviceability/interactive_props/generated/prop_v25_soccer_ball_chunk_129_139/interactive_prop_manifest.json`
  - `city_game/serviceability/interactive_props/generated/prop_v25_soccer_ball_chunk_129_139/SoccerBallProp.gd`

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0024）
- [x] v25 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新
