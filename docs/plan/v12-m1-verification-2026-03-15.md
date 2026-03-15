# V12 M1 Verification Artifact

## Purpose

本文件用于确认 `v12 / M1 数据审计与地址规则冻结` 已完成 fresh closeout，重点验证：

- `street cluster / address grammar / candidate pool / frontage slot` 的正式 contract 已冻结
- 世界级 `roads / intersections / lanes / blocks / parcels / street clusters` 统计稳定可复核
- 命名与门牌规则已具备 deterministic test evidence

## Environment

- Date: `2026-03-15`
- Workspace: `E:\development\godot_citys`
- Branch: `main`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`

## Commands

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_place_index_world_counts.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_street_cluster_naming.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_address_grammar.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_name_candidate_catalog.gd'
```

## Verification Results

| Test | Result | Note |
|---|---|---|
| `test_city_place_index_world_counts.gd` | PASS | `roads / intersections / lanes / blocks / parcels / street clusters` 统计与正式世界资产对齐 |
| `test_city_street_cluster_naming.gd` | PASS | `street cluster` 命名冻结为 deterministic contract |
| `test_city_address_grammar.gd` | PASS | `parcel_id + frontage_slot_index` 门牌编码/解码 contract 生效 |
| `test_city_name_candidate_catalog.gd` | PASS | landmark / road 命名候选池规模与生成语义已冻结 |

## Closeout Notes

- `M1` 现在具备完整的上游冻结证据，可作为 `M2-M5` 的 place-id / display-name 真值来源。
- 本轮 evidence 为 `2026-03-15` fresh rerun，不依赖聊天记录中的历史 PASS。
