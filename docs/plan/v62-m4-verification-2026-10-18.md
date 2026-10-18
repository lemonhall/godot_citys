# V62 M4 Verification — 2026-10-18

## Scope

程序化城市建筑美术口径改造（ECN-0043）。作者场景（汉堡店 / 枪店 / 咖啡馆 / 服务建筑 / landmark / venue / interactive prop）未改动。

## 对照

| 项 | 旧实现 | 新实现 |
| --- | --- | --- |
| 建筑视觉 | 圆角盒 + 六色 LEGO 调色板 + 凸点 MultiMesh | 分层体量 + facade shader + 构件 MultiMesh |
| 材质 | 单 StandardMaterial3D（clearcoat 塑料） | facade / trim / glass 三套 shader |
| 立面 | 纯色 | 7 种程序化窗格 + 层线 + 挑檐 + 竖梃 + 玻璃反射 |
| 天空 | 纯色 clear color | ProceduralSky 渐变 + 太阳 |
| 环境 | 平光 ambient 0.82 | sky ambient + ACES + 对比/饱和调整 + 距离雾 |
| 调色板 | 高饱和主色 | 冷混凝土 / 暖石灰岩 / 砖红米白 / 深钢铜 |

## 代码落点

- 新增 `city_game/world/rendering/buildings/`：
  - `CityBuildingFacade.gdshader`
  - `CityBuildingTrim.gdshader`
  - `CityBuildingGlass.gdshader`
  - `CityBuildingMeshBuilder.gd`
  - `CityBuildingDetailBatch.gd`
  - `CityBuildingMassingBuilder.gd`
- 重写 `city_game/world/serviceability/CityBuildingSceneBuilder.gd` 的视觉生成；契约 API 不变。
- `CityChunkProfileBuilder.gd`：建筑调色板改为建筑色系，地面 / 道路 / 标线改为城市色。
- `CityToyVisualStyle.gd`：环境改为渐变天空 + 天空环境光 + 距离雾。
- `CityPrototype.tscn`：太阳改为低角度暖光，`directional_shadow_max_distance=520`、`shadow map 4096`；补光 `sky_mode=1` 防止双太阳。
- `CityChunkScene.gd`：删除已死的 LEGO 盒体辅助函数。
- `CityDestructibleBuildingRuntime.gd`：从 `city_building_main_color` meta 读取碎块颜色（facade 已不是 StandardMaterial3D）。

## 测试

顺序执行（headless，dummy renderer）：

| 测试 | 结果 |
| --- | --- |
| `test_city_building_visual_contract.gd` | PASS |
| `test_city_building_ornaments_not_embedded.gd` | PASS（已改为 v62 口径） |
| `test_city_visual_environment.gd` | PASS（此前 FAIL：缺 sky） |
| `test_city_toon_outline_post_process_contract.gd` | PASS（已改为 v62 环境口径） |
| `test_city_chunk_renderer.gd` | PASS |
| `test_city_building_visual_envelope.gd` | PASS |
| `test_city_building_collision.gd` | PASS |
| `test_city_main_world_building_collapse.gd` | PASS |
| `test_building_collapse_lab_damage_contract.gd` | PASS |
| `test_city_building_road_alignment_metadata.gd` | PASS |
| `test_city_cafe_scene_contract.gd` | PASS |
| `test_city_gun_shop_scene_contract.gd` | PASS |
| `test_city_gun_shop_scene_front_orientation.gd` | PASS |
| `test_city_gun_shop_weapon_display_contract.gd` | PASS |

生成场景导出（`PackedScene.pack` + `ResourceSaver.save` + reload）实测通过，`ShaderMaterial` 作为子资源可序列化。

## 性能

- 单楼生成（7 archetype 平均）：`334 usec`，最慢 `1060 usec`。
- chunk setup（`test_city_chunk_setup_profile_breakdown`）：

| 指标 | 基线 HEAD `803ee55` | 本版 |
| --- | --- | --- |
| `buildings_usec` | 270 | 226 |
| `total_usec` | 1270 | 1725 |

- first-visit（`test_city_first_visit_performance_profile`）：

| 指标 | 基线 HEAD `803ee55` | 本版 | 门槛 |
| --- | --- | --- | --- |
| `streaming_mount_setup_avg_usec` | 2265 | 2450 | ≤ 5500 |
| `update_streaming_avg_usec` | 14653 | 14599 | ≤ 14500 |
| `wall_frame_avg_usec` | 23222 | 22889 | ≤ 16667 |

结论：`update_streaming` 与 `wall_frame` 在基线提交上已经超线，本版与基线持平（略好），不是本次改动引入的回归。

## 已知缺口 / 既有失败

- `test_city_chunk_variation.gd`：基线即 FAIL（相邻 chunk 复用同一 profile）。
- `test_city_burger_shop_scene_contract.gd`：基线场景缺 `Shell/UpperMassingA|B`，与本次改动无关。
- `test_city_building_serviceability_export.gd`：测试只扫描 `NearGroup` 的直接 `StaticBody3D` 子节点，v16 service-root 结构下拿不到目标，基线即失败。
- `test_city_streetfront_building_layout.gd`：基线即 FAIL（streetfront 比例低于 0.7）。
- 描边 overlay 仍是原点锚定的世界空间 quad，玩家离开原点后不覆盖全屏（既有问题，本次未改）。
- 建筑仍是无贴图的程序化材质；没有 sidewalk / 行道树 / 街道家具。

## 截图

- `user://debug/final_gallery_street.png`
- `user://debug/final_gallery_aerial.png`
- `user://debug/city_final_street.png`
- `user://debug/city_final_aerial.png`
- `user://debug/building_material_probe.png`

## Addendum (2026-10-19)

- 修复立面三角形绕序：Godot 以顺时针为正面，旧代码反了，导致近墙被背面剔除、能看到楼内。已反转为顺时针，建筑现在是实心。
- 新增 CityDistrictCharacter：downtown / commercial / residential / oldtown / industrial，按区域加权建筑组合、高度系数和调色板。
- 新增 hotel_tower / esidential_tower / ow_house 三种体量。
- 新增 10 组建筑色彩家族（蓝玻、绿玻、青铜、琥珀、银灰、石灰岩、砂岩、砖红、奶白、炭黑），玻璃色独立传参，不再由墙色推导。
- 街道层：人行道 + 路缘石 + 行道树 + 长椅 + 垃圾桶；地面改为多尺度草地/泥土/沥青纹理；环境启用 SSAO。
- 已知：建筑落位仍受 6m 路侧净空与“外接圆”近似限制，街区密度和连续街墙尚未重写。