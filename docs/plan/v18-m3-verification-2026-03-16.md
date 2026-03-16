# V18 M3 Verification 2026-03-16

## Scope

本轮验证覆盖：

- `v18` M1 lazy manifest loader
- `v18` M2 full map icon integration
- `v18` M3 map/minimap/task pin regressions + profiling

## Fresh Commands And Results

| Command / Test | Result | Evidence |
|---|---|---|
| `--script res://tests/world/test_city_service_building_map_pin_runtime.gd` | PASS | lazy loader 分批读取 manifest，当前 fixtures 只生成 1 个 `service_building` pin |
| `--script res://tests/world/test_city_service_building_map_pin_startup_delay_contract.gd` | PASS | full map 关闭时前 64 帧 `manifest_read_count = 0`；打开 full map 后 loader 才开始读 manifest |
| `--script res://tests/world/test_city_service_building_full_map_pin_contract.gd` | PASS | full map render state 暴露 cafe marker，`icon_id = cafe`，`icon_glyph = ☕`，minimap 不含 `service_building` |
| `--script res://tests/e2e/test_city_service_building_full_map_icon_flow.gd` | PASS | 用户流：打开 full map 后能看到咖啡馆 icon，关闭地图恢复正常 |
| `--script res://tests/world/test_city_map_pin_overlay.gd` | PASS | shared pin registry 与显式 task pin 主链不回退 |
| `--script res://tests/world/test_city_minimap_idle_contract.gd` | PASS | idle minimap 仍无默认 pin 污染 |
| `--script res://tests/world/test_city_task_map_tab_contract.gd` | PASS | task panel / tracked task / full map task pins 主链不回退 |
| `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd` | PASS | `CITY_CHUNK_SETUP_PROFILE.total_usec = 3359` |
| `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | PASS | `update_streaming_avg_usec = 8093`，`wall_frame_avg_usec = 9746` |
| `--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | FAIL | `update_streaming_avg_usec = 17339`，高于 gate `14500` |

## Outcome

- M1：通过
- M2：通过
- M3：部分通过

当前 `v18` 的功能链、shared pin regressions、chunk setup profile 与 warm runtime profile 都已通过。

当前唯一未收口项是 `test_city_first_visit_performance_profile.gd`：

- failure gate: `update_streaming average <= 14500 usec`
- fresh result: `15732 usec`

## Notes

- 本轮已把自定义建筑 full-map pin loader 设计成：
  - 只读 manifest，不加载 scene
  - 启动后延迟 + 低速批处理
  - streaming 有背压时让路
- 本轮进一步把 `service_building` pin 同步改成 delta apply，避免随着建筑数量增长而在每个 lazy batch 里整组重建同源 pins。
- 尽管如此，`first_visit` profiling 仍未过线，因此 `REQ-0011-004` 不能宣称完成。
- `test_city_service_building_map_pin_startup_delay_contract.gd` 已证明：在 full map 保持关闭的 early traversal window 内，`manifest_read_count = 0`，说明当前 `first_visit` profiling 失败并不是由 `v18` loader 在该窗口提前读 manifest 造成的。
