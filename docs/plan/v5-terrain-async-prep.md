# V5 Terrain Async Prep

## Goal

把 terrain height/normal/page 数据准备迁到异步路径，主线程只保留 mesh/resource commit，进一步压低 streaming 尖峰。

## Status

done

## Evidence

- `tests/world/test_city_terrain_async_pipeline.gd`
- `tests/world/test_city_streaming_profile_stats.gd`
- `tests/e2e/test_city_runtime_performance_profile.gd`
- 最新 isolated runtime profile 区间：`wall_frame_avg_usec = 15535 ~ 16679`、`update_streaming_avg_usec = 14240 ~ 15186`、`streaming_mount_setup_avg_usec = 5505 ~ 6034`

## PRD Trace

- REQ-0001-003
- REQ-0001-006
- REQ-0001-011

## Scope

做什么：

- terrain page sample build / cache load-save 进入后台线程
- terrain mesh data arrays 在后台准备，主线程只做 mesh commit
- runtime profiling 显式暴露 async dispatch / complete / commit 成本

不做什么：

- 不在本计划里做最终 LOD 调度
- 不在本计划里直接把 scene tree / GPU 资源放进后台线程

## Acceptance

1. 自动化测试必须断言 terrain prepare 与 terrain commit 已显式拆分，且后台线程不得直接操作 scene tree 或 GPU 资源。
2. runtime profiling 必须新增 `terrain_async_dispatch_*`、`terrain_async_complete_*`、`terrain_commit_*` 和 `pending_terrain_async_count` 或等价字段。
3. `test_city_runtime_performance_profile.gd` 必须证明 `streaming_mount_setup_avg_usec <= 16000`。
4. 反作弊条款：不得把同步逻辑包进线程后立即 `wait_to_finish()`，也不得通过冻结玩家移动来伪装 streaming 尖峰消失。

## Files

- Modify: `city_game/world/rendering/CityTerrainPageProvider.gd`
- Modify: `city_game/world/rendering/CityTerrainMeshBuilder.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Create: `tests/world/test_city_terrain_async_pipeline.gd`
- Modify: `tests/world/test_city_streaming_profile_stats.gd`
- Modify: `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 写失败测试（红）
   - `test_city_terrain_async_pipeline.gd` 断言存在 async dispatch/complete/commit 生命周期。
   - `test_city_streaming_profile_stats.gd` 断言 terrain profiling 字段存在。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是 terrain 仍主要在主线程准备。
3. 实现（绿）
   - 将 terrain page sample 与 mesh array 准备迁到 worker 线程。
   - 主线程只保留 `ArrayMesh` / `MeshInstance3D` / 材质绑定提交。
4. 跑到绿
   - async pipeline 与 profile stats 测试全部 PASS。
5. 必要重构（仍绿）
   - 把 pending job 生命周期与 chunk streaming 生命周期对齐。
6. E2E 测试
   - runtime profile 验证 `streaming_mount_setup_avg_usec` 明显下降，且无回写失效 chunk 的错误。

## Risks

- terrain async 结果如果回写到已卸载 chunk，会出现悬空引用或过期页污染。
- 如果 mesh commit 粒度没有控制好，异步收益可能被主线程大提交重新吃掉。
