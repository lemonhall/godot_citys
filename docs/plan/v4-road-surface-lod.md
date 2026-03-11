# V4 Road Surface LOD

## Goal

把普通地面道路的可见细节拆成 near / mid / far 三档，确保远中景只支付轮廓成本，不支付近景标线和高细节 mask 成本。

## PRD Trace

- REQ-0001-004
- REQ-0001-006
- REQ-0001-010

## Scope

做什么：

- 定义 near / mid / far 的道路表面细节策略
- `mid/far` 默认禁用 `stripe_mask` 或降级为纯底色
- 保持道路轮廓连续，不允许因为降级产生明显断裂

不做什么：

- 不做最终美术化车道箭头/字样
- 不做 surface page 多分辨率分页

## Acceptance

- `mid/far` chunk 不再绑定完整的近景 `stripe_mask`。
- 近景仍保留路面底色和标线；中远景至少保留路面轮廓。
- `test_city_runtime_performance_profile.gd` 中 `streaming_mount_setup_avg_usec` 必须继续低于上一轮提交基线。
- 反作弊条款：不得通过“远中景直接不显示道路”来满足成本下降。

## Files

- `city_game/world/rendering/CityChunkScene.gd`
- `city_game/world/rendering/CityGroundRoadOverlay.gdshader`
- `city_game/world/rendering/CityRoadMaskBuilder.gd`
- `tests/world/test_city_road_surface_lod.gd`
- `tests/world/test_city_ground_road_overlay_material.gd`
- `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 写失败测试（红）
2. 运行到红：`test_city_road_surface_lod.gd`
3. 实现分层路面策略（绿）
4. 运行到绿：LOD / material / runtime profile 相关测试
5. 必要重构：把细节策略集中到单一配置点
6. E2E：复测 runtime profile

## Risks

- 如果 `mid/far` 降级策略只看距离、不看现有 LOD 合约，会再次造成视觉跳变。
- 如果 shader 退化路径不明确，可能会出现空纹理报错或地表发黑。
