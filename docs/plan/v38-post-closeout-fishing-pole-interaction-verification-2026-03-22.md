# V38 Post-Closeout Fishing Pole Interaction Verification 2026-03-22

## Scope

本轮 closeout 收口的是 `ECN-0028` 定义的 fishing 交互重构：

- 废弃 `MatchStartRing` / 绿圈 / 坐下开局语义
- fishing 入口改为 authored `FishingPoleRestAnchor` 上的鱼竿本体
- `E = 拿起/放回鱼竿`
- `右键 = 待甩杆预览`
- `左键 = 甩杆 / 收杆`
- lab 与主世界继续共享同一套 `CityFishingVenueRuntime.gd`

## Code Delta

- 修改 `city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/minigame_venue_manifest.json`
  - 移除 `seat_anchor_ids` / `trigger_radius_m`
  - 新增 `pole_anchor_id` / `pole_interaction_radius_m`
- 修改 `city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/lake_fishing_minigame_venue.tscn`
  - 删除 `MatchStartRing`
  - 保留 `FishingPoleRestAnchor`
  - 新增 `FishingBobberVisual` / `FishingLineVisual`
- 重写 `city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/LakeFishingMinigameVenue.gd`
  - 入口 contract 改为 `get_pole_anchor()`
  - scene 负责鱼竿/鱼漂/鱼线 carrier，可视由 runtime 同步
- 重写 `city_game/world/minigames/CityFishingVenueRuntime.gd`
  - 状态收口为 `idle -> equipped -> cast_out -> bite_ready`
  - 运行时增加 `pole_equipped` / `bobber_visible` / `fishing_line_visible` / `bobber_bite_feedback_active`
  - 新增 `set_cast_preview_active*()` / `request_cast_action*()` / `debug_set_bite_delay_override()`
- 修改 `city_game/scripts/PlayerController.gd`
  - 新增 fishing 输入信号与持竿/预甩可视
  - 右键/左键复用手雷式抛物线预览 UX，但落点收口到湖面高度
- 修改 `city_game/scenes/labs/LakeFishingLab.tscn`
  - `Player/Visual/FishingPoleHoldAnchor/FishingPoleEquippedVisual` 正式 author 到 scene
- 修改 `city_game/scenes/labs/LakeFishingLab.gd`
  - 暴露 `set_fishing_cast_preview_active()` / `request_fishing_cast_action()` / `debug_set_fishing_bite_delay_override()`
  - 连接 Player 输入信号，lab 内可直接 `E / 右键 / 左键` 实操
- 修改 `city_game/scenes/CityPrototype.tscn`
  - `Player/Visual/FishingPoleHoldAnchor/FishingPoleEquippedVisual` 正式 author 到主场景
- 修改 `city_game/scripts/CityPrototype.gd`
  - 新增 shared fishing cast-preview / cast-action / deterministic bite wrapper
  - 连接 Player fishing 输入信号并同步 HUD / focus message
- 修改 `city_game/ui/PrototypeHud.gd`
  - fishing HUD 文案切换为新输入链路，不再出现“坐下/进圈/收竿重置”旧语义

## Verification

执行：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

$tests=@(
  'res://tests/test_city_skeleton_smoke.gd',
  'res://tests/world/test_city_fishing_minigame_venue_manifest_contract.gd',
  'res://tests/world/test_city_fishing_pole_visual_contract.gd',
  'res://tests/world/test_city_lake_lab_scene_contract.gd',
  'res://tests/world/test_city_fishing_venue_cast_loop_contract.gd',
  'res://tests/world/test_city_lake_main_world_port_contract.gd',
  'res://tests/world/test_city_fishing_venue_reset_on_exit_contract.gd',
  'res://tests/e2e/test_city_lake_lab_fishing_flow.gd',
  'res://tests/e2e/test_city_lake_fishing_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：

| Area | Result | Notes |
|---|---|---|
| project smoke | PASS | `CityPrototype.tscn` 仍可 headless 启动 |
| fishing manifest contract | PASS | `pole_anchor_id` / `pole_interaction_radius_m` 正式生效 |
| pole visual contract | PASS | venue rest pole、player hold pole、bobber、line 均已 scene-authored |
| lab scene contract | PASS | lab 场景暴露新 cast-preview / cast-action API，且持竿挂点已进 scene |
| lab cast loop | PASS | `E 拿竿 -> 右键预甩 -> 左键甩杆 -> bite_ready -> 左键收杆 -> E 放回` 整链通过 |
| main-world port | PASS | 主世界 prompt / HUD / pole pickup 已切换到鱼竿入口 |
| reset on exit | PASS | 超出 `32m` release buffer 后 runtime 自动回到 `idle` |
| lab fishing e2e | PASS | lab 真正走通新交互闭环 |
| main-world fishing e2e | PASS | 主世界复用同一套 pole-driven runtime，未分叉第二套逻辑 |

## Notes

- 本轮验证的是 fishing 交互 contract 改造，不是 terrain/rendering profiling 工作，因此没有新增 profiling 过线声明。
- 当前正式口径以本 artifact + `ECN-0028` 为准；任何旧文档里出现的 `MatchStartRing` fishing 入口语义都应视为已废弃。
