# Lego Plastic City Visual Style Design

## 背景

当前主世界画面偏灰、偏哑光，建筑、道路、地面等主要 runtime 几何大多使用简单 `StandardMaterial3D`，大量材质 `roughness = 1.0`。这让低多边形城市虽然可读，但缺少玩具塑料的高光、色彩对比和接触阴影，整体观感平庸。

目标是把主世界统一改成鲜亮的乐高塑料风格，而不是只美化单个模型。

## 目标

- 主世界第一眼应读作“鲜亮玩具塑料城市”。
- 建筑、道路、地面、水体、车辆、行人代理等 runtime 生成对象共享同一套视觉语言。
- 材质应有塑料高光和更高饱和度，但仍保持 low-poly、程序生成和流式性能边界。
- 改动应集中在共享渲染入口，不手工逐个改大量 `.tscn`。
- 保持现有 deterministic world generation、chunk streaming、navigation/task contract 不变。

## 非目标

- 不在第一阶段给每栋楼生成大量乐高凸点、倒角或砖缝几何。
- 不引入外部贴图包、PBR 资源库或新渲染依赖。
- 不改变导航、任务、place query、streaming 半径、chunk profile 语义。
- 不追求真实城市写实材质。

## 推荐方案

采用方案 B：新增共享乐高塑料视觉风格模块，并把现有共享材质入口迁移到该模块。

模块暂命名为 `CityToyVisualStyle.gd`，放在 `city_game/world/rendering/`。它负责：

- 提供乐高式色板。
- 生成或缓存 `StandardMaterial3D`。
- 为不同表面类型提供一致参数：building、road、ground、water、vehicle、pedestrian、street_prop、hlod。
- 给测试提供可查询的材质 contract。

## 视觉规则

### 环境

- 主天空改为更亮的蓝色渐变。
- 太阳光保持单主光，但色温略暖，阴影清晰。
- 环境光提升亮度但避免洗平暗部。
- 配置 tone mapping、轻量 SSAO 和可控 glow，让接触阴影与高光更明显。

### 材质

- 建筑：高饱和塑料色板，颜色按既有 profile seed 稳定选择。
- 道路：深灰或深蓝灰塑料材质，与鲜亮建筑形成对比。
- 地面：更鲜亮的草绿色或玩具底板绿色。
- 水体：透明偏青蓝，保留低 roughness 高光。
- 车辆：白色、黄色、红色、蓝色等玩具车色，保留轻微高光。
- 行人代理：比现在更明确的身体色块，但仍保持轻量。

默认材质参数：

- `metallic = 0.0`
- `roughness` 大致在 `0.35` 到 `0.62`
- `specular_mode` 使用 Godot 默认或显式保持可见高光
- 必要时使用轻微 emission 只提亮 UI/marker，不滥用于建筑主体

## 接入点

第一阶段优先改以下共享入口：

- `city_game/scenes/CityPrototype.tscn`
- `city_game/scripts/CityPrototype.gd`
- `city_game/world/rendering/CityChunkScene.gd`
- `city_game/world/rendering/CityRoadMeshBuilder.gd`
- `city_game/world/rendering/CityChunkHlodBuilder.gd`
- `city_game/world/rendering/CityLakeBasinCarrierBuilder.gd`
- `city_game/world/vehicles/rendering/CityVehicleTrafficBatch.gd`
- `city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd`
- `city_game/scripts/CityBlockGrid.gd`
- `city_game/world/serviceability/CityBuildingSceneBuilder.gd`

如果某些 authored scene 已有明确材质语义，第一阶段不强行覆盖，避免破坏场景作者真源。

## 数据流

```text
chunk profile / authored builder
  -> semantic color or palette key
  -> CityToyVisualStyle material factory
  -> cached StandardMaterial3D
  -> MeshInstance3D / MultiMeshInstance3D material_override
```

颜色选择必须仍由现有 seed/profile 决定，不能引入每次运行变化的随机值。

## 错误处理

- 如果未知 surface type 被请求，返回明确的 fallback 塑料材质，而不是 `null`。
- 如果材质参数不被当前 Godot 版本支持，保持默认 `StandardMaterial3D` 参数，不阻断运行。
- 不让视觉模块依赖 chunk renderer 的运行时状态，避免隐藏状态耦合。

## 测试策略

新增或调整 focused contract：

- 验证 `CityToyVisualStyle` 对主要 surface type 返回非空 `StandardMaterial3D`。
- 验证建筑、道路、地面、水体材质 roughness 不再全部是 `1.0`。
- 验证色板选择 deterministic。
- 验证主场景 parse check 通过。

受影响测试：

- Godot parse check。
- 相关 world/rendering contract 测试。
- 如修改 chunk rendering 热路径，顺序跑性能三件套：
  - `test_city_chunk_setup_profile_breakdown.gd`
  - `test_city_first_visit_performance_profile.gd`
  - `test_city_runtime_performance_profile.gd`

## 验收标准

- 主世界截图中建筑、地面、道路整体明显更鲜亮，接近玩具塑料风格。
- 主要 runtime 材质统一来自共享视觉模块或遵循相同参数。
- 没有新增外部依赖。
- 受影响 Godot 测试通过。
- 性能 profiling 没有因为材质系统引入明显回退。

