# V62 City Building Art Direction

## Goal

把程序化城市建筑从 LEGO 色块改成有建筑立面语法的电影感街区，同时守住 chunk 装载预算与既有建筑契约。

## Scope

- 只改**程序化生成建筑**的视觉与配色。
- 作者场景（汉堡店、枪店、咖啡馆、服务建筑、landmark、venue、interactive prop）不改。
- 不改道路、地形、行人、车辆、导航、任务、流式策略。

## Art Direction

| 维度 | 旧口径 | 新口径 |
| --- | --- | --- |
| 形体 | 单盒 + 圆角 + 凸点 | 基座 / 裙房 / 塔身 / 退台 / 顶冠 / 女儿墙 |
| 立面 | 纯色 | shader 窗格 7 种样式 + 层线 + 檐口 + fins + 角柱 |
| 屋顶 | 4 个凸点 | 机房、冷却塔、水箱、天线、栏杆、楼梯间、烟囱 |
| 材质 | clearcoat 塑料 | 分 surface 的立面 / 构件 / 玻璃三套材质 |
| 配色 | LEGO 六色 | 冷混凝土 / 暖石灰岩 / 深钢铜 / 砖红米白 |
| AO | 无 | 顶点色烘焙（近地、檐下、体量交接） |

## Milestones

- `M1` 材质与几何基座：facade / trim / glass 三套 shader；`CityBuildingMeshBuilder` 合并网格工具；gallery 渲染探针。
- `M2` 体量语法：七种 archetype 的分层体量、退台、顶冠、屋顶设备、裙房与店招。
- `M3` 契约与配色：`CityBuildingSceneBuilder` 接线、建筑契约保持、调色板与环境光改造。
- `M4` 验收：gallery 三视角截图、主城街道截图、建筑相关 headless 测试、chunk setup / first-visit / warm runtime 三件套。

## Definition of Done

- `tests/e2e/debug_capture_building_gallery.gd` 输出 `street` / `aerial` / `closeup` 三张 PNG，无 `push_error`。
- 新 `tests/world/test_city_building_visual_contract.gd` 通过：
  - `build_runtime_building()` 返回 `StaticBody3D`，带 `city_generated_building`。
  - 主体 `MeshInstance3D` 是 `ArrayMesh`，含 `POSITION/NORMAL/COLOR/UV`，三角面数 ≥ 400。
  - 存在 `TrimMesh`/`GlassMesh` 至少其一，且 `trim` 材质是 `ShaderMaterial`。
  - 屋顶构件 AABB 高于主体顶面（不再全部埋进主体）。
  - 同一 `building_contract` 重复构建得到相同顶点数（deterministic）。
- `build_service_scene_root()` 仍返回 `GeneratedBuilding` 为 `StaticBody3D` 的 `Node3D`。
- `test_city_building_ornaments_not_embedded.gd` 改写为新口径并通过。
- 建筑相关测试全绿；`chunk setup` 总装载 ≤ 8500 usec，`buildings_usec` 不高于 2500 usec（1000 次平均）。
- 主城 `first-visit` / `warm runtime` 三件套不劣化。

## Risks

- GDScript 合并网格的构建开销会挤占 chunk setup 预算：用共享几何常量、避免 `SurfaceTool`、限制每楼盒体数量在 ~40-110。
- 每个建筑一个 facade `ShaderMaterial`，材质数上升：窗格共享同一 shader 变体，首次编译只发生一次。
- 立面窗口在远处产生摩尔纹：shader 内按 `fwidth` 淡出到平均色。
- 作者场景导出的 `.tscn` 会包含 `ShaderMaterial` 子资源：`PackedScene.pack()` 已验证可序列化。
