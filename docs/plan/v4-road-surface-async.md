# V4 Road Surface Async

## Goal

把道路 surface mask 的 CPU 数据准备迁到异步路径，主线程只做最终资源提交，进一步削掉 streaming 尖峰。

## PRD Trace

- REQ-0001-003
- REQ-0001-006
- REQ-0001-010

## Scope

做什么：

- 后台线程准备 byte mask / cache 读写
- 主线程只提交 `Image` / `Texture2D` / 材质绑定
- 在 profiling 中显式输出 async queue 与主线程 commit 成本

不做什么：

- 不直接在后台线程操作 scene tree
- 不直接在后台线程提交 GPU 纹理

## Acceptance

- 自动化测试至少断言异步路径存在，且 scene tree / GPU 提交仍在主线程。
- runtime profiling 的 mount 尖峰必须继续下降，且不允许引入线程相关崩溃。
- 反作弊条款：不得仅把同一段同步逻辑包进线程后再立即 `wait_to_finish()`，从而伪装成异步。

## Files

- `city_game/world/rendering/CityChunkRenderer.gd`
- `city_game/world/rendering/CityChunkScene.gd`
- `city_game/world/rendering/*RoadSurface*.gd`
- `tests/world/test_city_road_surface_async_pipeline.gd`
- `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 写失败测试（红）
2. 运行到红：`test_city_road_surface_async_pipeline.gd`
3. 实现异步数据准备与主线程提交分离（绿）
4. 运行到绿：async pipeline + runtime profile
5. 必要重构：把异步队列和缓存接口稳定下来
6. E2E：复测 runtime profile

## Risks

- Godot 场景树和 GPU 资源线程安全边界很窄，线程里只能做数据准备，不能乱碰资源和节点。
- 如果异步完成回调没有和 streaming 生命周期绑定，chunk 退场后容易回写无效对象。
