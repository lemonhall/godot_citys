# V3 Minimap Navigation

## Goal

把参考项目的 2D 表达层转成当前项目的小地图/导航底层，让玩家在 `70km x 70km` 世界里能看见道路骨架、自己位置和宏观路径。

## PRD Trace

- REQ-0001-005
- REQ-0001-006
- REQ-0001-009

## Scope

做什么：

- 基于共享 world road graph 生成 2D 投影数据
- 在 HUD 中增加默认折叠的小地图视图
- 显示玩家位置、朝向与 `plan_macro_route()` 路径高亮
- 暴露世界坐标 <-> 小地图坐标投影接口

不做什么：

- 不做最终美术化地图瓦片
- 不做 GPS 语音导航
- 不做复杂 POI 筛选与搜索

## Acceptance

- 小地图道路骨架必须与 world road graph 同源，不能单独随机生成。
- HUD 小地图默认折叠，可展开，并稳定显示玩家标记与朝向。
- 至少一条宏观 route 能被投影为 2D 高亮折线。
- 反作弊条款：不得用静态贴图或预渲染图冒充小地图。

## Files

- `city_game/ui/PrototypeHud.gd`
- `city_game/scripts/CityPrototype.gd`
- `city_game/world/navigation/*`
- `city_game/world/map/*`
- `tests/world/test_city_minimap_projection.gd`
- `tests/world/test_city_minimap_route_overlay.gd`
- `tests/world/test_city_prototype_ui.gd`

## Steps

1. 写失败测试（红）
2. 运行到红：`test_city_minimap_projection.gd`、`test_city_minimap_route_overlay.gd`
3. 实现 2D 投影与 HUD minimap（绿）
4. 运行到绿：相关 world/UI 测试
5. 必要重构：把地图投影与 HUD 绘制解耦
6. E2E：跑 `test_city_navigation_flow.gd` 与 `test_city_fast_inspection_mode.gd`

## Risks

- 若 HUD 直接持有过多 world internals，小地图会再次变成临时拼装 UI。
- 若 2D 投影不基于共享道路图，后续路径高亮与 POI 标注会全部漂移。
- 若地图刷新不做裁剪与轻量缓存，inspection 高速模式下可能再次放大 UI 帧耗。
