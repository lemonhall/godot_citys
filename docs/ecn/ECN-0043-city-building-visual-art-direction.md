# ECN-0043 City Building Visual Art Direction

## Why

`v61` 之前，程序化城市建筑沿用 LEGO 玩具口径：六色高饱和砖块、1.15m 圆角、clearcoat 塑料高光、屋顶与立面凸点（studs）。
这套口径在远景缩略图里成立，但进街道之后暴露三个硬问题：

- 建筑只剩“色块 + 黑点”，没有任何立面语法：没有窗、没有层线、没有檐口、没有屋顶设备，玩家读不出建筑的用途与尺度。
- 圆角半径按建筑尺寸比例走，18m 宽的大楼得到近 1m 的圆角，形体像果冻，不像楼。
- 高饱和主色让整片城区互相打架，远景 HLOD 也继承同一批颜色，看起来像积木摊在草地上。

用户于 `2026-10-18` 明确要求把程序化城市建模整体改造，向 3A 级城市阅读感靠拢，并保留汉堡店、枪店、咖啡馆、服务建筑等作者场景。

## Change

冻结新的城市建筑美术口径，版本号 `v62`：

- 程序化生成建筑改为**分层体量 + 建筑立面语法**：
  - 体量：基座、裙房、塔身、退台、顶冠、女儿墙。
  - 立面：由 shader 绘制的窗格（punched / ribbon / curtain wall / stone / brick / retail / industrial 七种样式），并带真实玻璃反射、窗内亮度差异、按距离淡出的抗摩尔纹。
  - 细节几何：檐口、层线、竖向 fins、角柱、阳台、雨棚、店招、屋顶机房、冷却塔、水箱、天线、栏杆、烟囱、锯齿屋顶。
- 建筑主体变为**单 building 三 surface 合并网格**（facade / trim / glass），不再逐 ornament 建节点：
  - `facade`：per-building `ShaderMaterial`，窗格按 UV 的“开间 x 层高”模块坐标生成。
  - `trim`：全局共享 `ShaderMaterial`，顶点色 albedo + alpha 作为自发光遮罩（店招、航空灯）。
  - `glass`：全局共享玻璃 shader，Fresnel 天空反射，不用反射探针。
- 顶点色写入**烘焙 AO / 明暗梯度**（近地压暗、檐下压暗），不启用 SSAO。
- 调色板从 LEGO 六色改为四种建筑色系（冷混凝土 / 暖石灰岩 / 深钢铜 / 砖红米白），道路、地面、标线颜色保持不变。
- 环境光从 `0.82` 降到 `0.58`，让日照阴影承担形体阅读；天空、太阳、补光、描边后处理保持。
- 建筑契约不变：`build_runtime_building()` 仍返回带 `city_generated_building` meta 的 `StaticBody3D`，`build_service_scene_root()` 仍返回带 `city_service_scene_root` meta 的 `Node3D`，碰撞仍是单 BoxShape3D，`building_id` / `inspection_payload` 链路不变。

## Still Out Of Scope

- 不替换作者场景：`building_override_entries`、`service building scene`、`landmark`、`venue`、`interactive prop` 全部保持原样。
- 不引入外部 GLB / PBR 贴图资产；立面全部由 shader 与几何程序化生成。
- 不改道路、地形、行人、车辆、HLOD 代理数量与流式策略。
- 不启用 SSAO / Glow / 体积雾；性能红线仍是 `60 FPS = 16.67ms/frame`。

## Affected Docs

- `docs/plan/v62-index.md`
- `docs/plan/v62-city-building-art-direction.md`
- `docs/prd/PRD-0009-building-serviceability-reconstruction.md`（仅视觉口径引用）
