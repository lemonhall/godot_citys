# 2026-03-17 V21 World Feature Overrides Design

## 问题收口

当前仓库已经有两条很强的链：`v16` 的 `building_id -> manifest -> scene override`，以及 `v18` 的 `manifest -> full_map_pin -> icon glyph`。但它们都默认“先有一栋 building”。喷泉、电视塔、雕塑这类离散地标不满足这个前提；山和湖这种区域特征更不满足，因为它们不只是放一个 scene，而是要影响 terrain / water / nav。另一方面，激光指示器在打到地面时虽然内部已经有 `world_position`，对外却只给了 chunk 文本，导致 authored placement 缺乏稳定坐标输入。

所以 `v21` 的设计不该是“再造一条建筑 override”，而该是把世界扩展分成两条 sibling family。第一条是 `scene_landmark`，服务喷泉、电视塔、雕塑、奇怪标志性建筑。第二条是未来的 `terrain_region_feature`，服务山、湖、地形隆起和水域。两条链共享的输入是 `ground_probe`，而不是共享同一个 runtime mount 实现。

## 推荐架构

推荐方案是“小抽象，大分流”：

1. `ground_probe`
   - 由激光指示器正式输出 `world_position / chunk_key / chunk_local_position / surface_normal`
   - 它是 authored placement 的统一输入，不再依赖肉眼抄 chunk id

2. `scene_landmark`
   - 新增独立 registry 与 manifest
   - chunk near mount 时实例化 scene
   - `full_map_pin` 可选，喷泉 opt-in，山湖默认不走这里
   - 地图 `pin_type` 继续复用现有 `landmark` 颜色语义，只新增 `icon_id = fountain`
   - 对电视塔这类 tall landmark，允许 manifest 声明 `far_visibility`，但只能渲染廉价 proxy，不允许完整 scene 远距常驻

3. `terrain_region_feature`
   - 当前只冻结路线，不在 `v21` 实现
   - 未来接 terrain / water page provider，用 footprint / mask / height delta / water fill 驱动
   - 默认不要求 full-map pin

这个拆法的核心好处是：喷泉能快速落地，不把山湖问题硬塞进 scene mount；而山湖也不会因为 v21 先做了一个 fountain runtime，就被迫走一条不适合自己的路径。

## 数据 contract 建议

`scene_landmark` manifest 建议保留和 `building_manifest.json` 接近的手感，但字段语义要干净：

- `landmark_id`
- `feature_kind = scene_landmark`
- `display_name`
- `anchor_chunk_id`
- `anchor_chunk_key`
- `world_position`
- `scene_path`
- `manifest_path`
- `full_map_pin` 可选
- `far_visibility` 可选：
  - `enabled`
  - `proxy_scene_path`
  - `visibility_radius_m`
  - `lod_modes`

喷泉建议落在 `chunk_129_142`，其 chunk center 是 `(-1848, 0, 1480)`。真正 authored 摆放时，不应该只存“这是 `chunk_129_142`”，而应该存：

- `world_position`
- `chunk_local_position`

这样用户后续即使只看 clipboard 文本，也能稳定把一个离散 landmark 放回同一个点。电视塔、雕塑、奇怪建筑以后都能直接复用这套 contract。

如果是电视塔这种“远处也应该看得见”的地标，推荐做法不是扩大 `scene_landmark` 的常驻范围，而是给它单独配一个远距 proxy。也就是说：

- near LOD：挂完整 landmark scene
- mid/far LOD：按 `far_visibility` 决定是否显示廉价 proxy
- 超过 `visibility_radius_m`：连 proxy 也不显示

这样既保住世界辨识度，也不把 streaming 纪律击穿。

## 为什么山和湖不是“同一条实现链”

山和湖可以共享“放置输入”和“manifest 思维”，但不能共享 `scene_landmark` 的 instantiate 路径。原因有三个。

第一，它们通常跨 chunk，甚至需要修改 terrain page / road clearance / water render。第二，它们影响的不只是可见 mesh，还可能影响导航、地面采样、碰撞甚至 place query。第三，把山/湖做成一个超大 scene 挂在 near chunk 里，会把 streaming、LOD 和 page cache 纪律全打乱。

所以更合理的路线是：`v21` 先把 `ground_probe` 和 `scene_landmark` 做硬，证明“非 building authored 内容”能进世界；下一轮再基于同一个 probe 输入，新增 `terrain_region_feature` family，让 mountain / lake 走 terrain/water page provider 这条 sibling 链。两者共享术语 `world feature override`，但不共享 mount 实现。
