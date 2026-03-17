# V23 M4 Verification Artifact

## Scope

本文件记录 `v23` 在 `2026-03-17` 的 fresh verification，当前收口范围是：

- 音乐公路 manifest 已迁到用户指定的新落点：`chunk_108_210` / `(-7202.77, -9.82, 18962.72)`
- 钢琴键 MultiMesh 视觉条带已抬离路面，不再埋进 road deck
- note player 的 fallback 电子音链已进入正式回归口径，drive-song flow 需要显式证明 `played_note_count > 0`
- full-map pin、scene-landmark mount、runtime sequence、reverse / slow semantics 维持通过

本轮没有 fresh 重跑 profiling 三件套，所以**不在这里宣称 FPS 已恢复**；真实渲染性能仍以用户进游戏手测和后续 profiling closeout 为准。

## Environment

- Date: `2026-03-17`
- Workspace: `E:\development\godot_citys`
- Branch: `main`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`

## Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_music_road_manifest_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_music_road_visual_phase_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_music_road_visual_envelope.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_music_road_drive_song_flow.gd'

$tests=@(
  'res://tests/e2e/test_city_music_road_full_map_flow.gd',
  'res://tests/e2e/test_city_scene_landmark_mount_flow.gd',
  'res://tests/world/test_city_music_road_definition_contract.gd',
  'res://tests/world/test_city_music_road_runtime_sequence_contract.gd',
  'res://tests/world/test_city_music_road_speed_window_contract.gd',
  'res://tests/world/test_city_music_road_reverse_traversal_contract.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}

python 'tests/tools/test_music_score_preview_contract.py'
```

## Results

| Test | Result | Note |
|---|---|---|
| `test_city_music_road_manifest_contract.gd` | PASS | manifest 已冻结到 `chunk_108_210` / `world_position=(-7202.77,-9.82,18962.72)` / `yaw_rad=PI*0.5` |
| `test_city_music_road_visual_phase_contract.gd` | PASS | shader phase contract 继续保持 `idle / approach / active / decay` |
| `test_city_music_road_visual_envelope.gd` | PASS | 音乐公路 landmark 继续产出完整 key-strip 集合，且 visual bottom 贴近 manifest 高度 |
| `test_city_music_road_drive_song_flow.gd` | PASS | drive-song e2e 现在还要求 `note_player.played_note_count > 0` 且 `bank_status in {ready, fallback_synth}` |
| `test_city_music_road_full_map_flow.gd` | PASS | full map 继续显示 `music_road -> 🎵`，minimap 不泄漏 |
| `test_city_scene_landmark_mount_flow.gd` | PASS | scene-landmark 主链未因音乐公路 persistent mount 回退 |
| `test_city_music_road_definition_contract.gd` | PASS | `music_road_definition` sidecar 继续保持 formal contract |
| `test_city_music_road_runtime_sequence_contract.gd` | PASS | 正向 canonical run 继续触发完整 strip 序列 |
| `test_city_music_road_speed_window_contract.gd` | PASS | 慢速仍会完整 audition，但不会误判成 `song_success` |
| `test_city_music_road_reverse_traversal_contract.gd` | PASS | 倒着开仍会逆序 audition |
| `tests/tools/test_music_score_preview_contract.py` | PASS | 中间试听 QA 产物链仍然可用 |

## Functional Notes

- 本轮关键修复不是只改坐标，还包含两处直接影响手感的问题：
  - key-strip 的中心高度原先落在 road deck 内部，实机很容易看成“根本没有琴键”；现在已整体抬到路面上方。
  - fallback synth 的默认 voice count / volume 已上调，drive-song flow 也正式验证 note player 确实收到并播放了音符事件。
- 当前声音链仍允许走 `fallback_synth`，这是用户在本轮对话里明确接受的临时口径；真正的高保真钢琴 sample bank 仍是后续优化项，不在本次 verification 中冒充“已完成”。

## Performance Guard

| Test | Result | Note |
|---|---|---|
| `test_city_chunk_setup_profile_breakdown.gd` | not rerun | 本轮主要修 placement / visible keys / audible fallback，没有 fresh profiling 证据 |
| `test_city_runtime_performance_profile.gd` | not rerun | 不在本文件内宣称 warm runtime FPS 恢复 |
| `test_city_first_visit_performance_profile.gd` | not rerun | 用户仍需实机观察；后续若要正式 closeout，需要单独补 profiling 三件套 |

## Residual Risks

- 用户前一次实机反馈里明确提到“17 FPS”与“无声”；本轮虽然功能回归已经证明音乐公路会出键、会出声，但**没有** fresh profiling 数据，因此仍不能把“性能已修复”当结论。
- fallback synth 现在只是“先可用”的电子音，不代表最终钢琴质感已经达标。
