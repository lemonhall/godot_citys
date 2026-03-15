# V12 Map UI HUD Task Pins

## Goal

交付 `M` 全屏地图、世界暂停、选点设目的地、pin overlay、minimap 路线高亮和驾驶态 HUD 导航提示，并保证它们消费同一份 `resolved_target + route_result`。

## PRD Trace

- REQ-0006-003
- REQ-0006-005
- REQ-0006-006
- REQ-0006-008

## Scope

做什么：

- 新增全屏地图界面，按 `M` 打开/关闭
- 打开地图时暂停世界，但地图 UI 保持交互
- 支持地图任意点选目的地
- 支持 landmark pin 与泛型 task/debug pin overlay
- minimap 与 HUD 消费同一份 route result

不做什么：

- 不做任务系统本体
- 不做语音导航
- 不做完整 POI 筛选矩阵

## Acceptance

1. 自动化测试必须证明：按 `M` 打开地图时世界暂停，地图 UI 仍能交互。
2. 自动化测试必须证明：地图点击会设置正式 destination，而不是 UI 临时点。
3. 自动化测试必须证明：minimap route overlay 与 HUD maneuver 提示来自同一 route generation。
4. 自动化测试必须证明：至少两类 pin 能共存显示并区分。
5. 反作弊条款：不得通过“把 minimap 放大”“暂停整棵树导致地图也不能输入”“pin 只是背景纹理”来宣称完成。

## Files

- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/ui/PrototypeHud.gd`
- Modify: `city_game/world/map/CityMinimapProjector.gd`
- Create: `city_game/ui/CityMapScreen.gd`
- Create: `city_game/ui/CityMapScreen.tscn`
- Create: `city_game/world/map/CityMapPinRegistry.gd`
- Create: `tests/world/test_city_full_map_pause_contract.gd`
- Create: `tests/world/test_city_map_pin_overlay.gd`
- Create: `tests/world/test_city_minimap_navigation_hud.gd`
- Create: `tests/e2e/test_city_map_destination_selection_flow.gd`
- Modify: `docs/plan/v12-index.md`

## Steps

1. 写失败测试（红）
   - 地图暂停 contract、pin overlay、HUD/minimap 同源三个方向先写。
2. 运行到红
   - 预期失败点是当前没有 full map screen，也没有正式 pin registry。
3. 实现（绿）
   - 新建 `CityMapScreen`、`CityMapPinRegistry`。
   - 在 `CityPrototype/HUD` 里接入 `M` 打开地图与 destination select。
   - 让 minimap/HUD 切到正式 route result consumer。
4. 运行到绿
   - world/UI/e2e tests 通过。
5. 必要重构（仍绿）
   - pause policy、pin registry、HUD 文案格式化独立。
6. E2E
   - 串行跑 map destination flow 与 runtime profile。

## Risks

- 如果 pin overlay 没有正式 registry，未来 Task 系统接入一定会再次拆 UI。
- 如果全屏地图不暂停世界，选点和驾驶态状态机会互相污染。
- 如果 minimap/HUD 不是同源 consumer，导航体验会直接断裂。
