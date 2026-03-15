# V12 M2 Verification Artifact

## Purpose

本文件用于确认 `v12 / M2 Place Index 与 Query` 已完成 fresh closeout，重点验证：

- `world_data` 已暴露正式 `place_index / place_query / route_target_index`
- `resolved_target` contract 稳定，且不回退成 chunk-local 临时查询
- `place_index` 磁盘 cache path/schema 已冻结并可重复命中

## Environment

- Date: `2026-03-15`
- Workspace: `E:\development\godot_citys`
- Branch: `main`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`

## Commands

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_place_query_resolution.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_resolved_target_contract.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_place_index_cache.gd'
```

## Verification Results

| Test | Result | Note |
|---|---|---|
| `test_city_place_query_resolution.gd` | PASS | landmark / address / raw-world-point 查询都走正式 `place_query` 主链 |
| `test_city_resolved_target_contract.gd` | PASS | `resolved_target` 已稳定暴露 `place_id / place_type / raw_world_anchor / routable_anchor / source_kind` |
| `test_city_place_index_cache.gd` | PASS | `user://cache/world/place_index/place_index_<world_signature>.bin` cache contract 与 schema version `2` 可复核 |

## Closeout Notes

- `M2` 保持“road/intersection/landmark 物化、address 按 query 反解”的口径，没有回退成 120 万条全量地址索引。
- `place_query` 与 `resolved_target` 现在已经足够支撑地图点击、HUD、fast travel 与 autodrive 共用同一目标语义。
