# V2 Index

## 愿景

PRD 入口：[PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)

v2 的目标不是“把地图表面积做大”，而是把 `godot_citys` 升级为一个真正可扩展的大城市底盘：世界数据、chunk streaming、渲染降级、导航边界和 E2E 证据都必须先成立，后续玩法系统才允许叠加。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 世界数据骨架 | 确定性世界配置、district/road/block/parcel 数据模型 | 固定 seed 下 `7000m x 7000m` 世界与 `256m x 256m` chunk 配置稳定生成；禁止整城节点树常驻 | `test_city_world_model.gd`、`test_city_world_generator.gd` | done |
| M2 Chunk Streaming | 玩家驱动的 `5x5` 活跃窗口、后台准备、主线程挂载 | 自动 travel 过程中活跃 chunk 数始终 `<= 25`，chunk 生命周期无重复/漏卸载 | `test_city_chunk_streamer.gd`、`test_city_travel_streaming_flow.gd` | todo |
| M3 渲染降级 | chunk-local MultiMesh、HLOD、occluder | 至少一种重复资产走 `MultiMeshInstance3D`；近中远三档表现存在；非整城高模常驻 | `test_city_chunk_renderer.gd`、`test_city_hlod_contract.gd` | todo |
| M4 导航与 E2E | chunk nav source、宏观路由、连续穿越验证 | Headless E2E 跨越至少 `2048m` 并输出 chunk 迁移证据；不存在整城单 navmesh 验收路径 | `test_city_navigation_flow.gd`、`test_city_large_world_e2e.gd` | todo |

## 计划索引

- [v2-world-data-model.md](./v2-world-data-model.md)
- [v2-chunk-streaming.md](./v2-chunk-streaming.md)
- [v2-rendering-lod.md](./v2-rendering-lod.md)
- [v2-navigation-e2e.md](./v2-navigation-e2e.md)

## 追溯矩阵

| Req ID | v2 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0001-001 | `v2-world-data-model.md` | `tests/world/test_city_world_model.gd` | `--script res://tests/world/test_city_world_model.gd` | 2026-03-11 本地 headless `PASS` | done |
| REQ-0001-002 | `v2-world-data-model.md` | `tests/world/test_city_world_generator.gd` | `--script res://tests/world/test_city_world_generator.gd` | 2026-03-11 本地 headless `PASS` | done |
| REQ-0001-003 | `v2-chunk-streaming.md` | `tests/world/test_city_chunk_streamer.gd` | `--script res://tests/e2e/test_city_travel_streaming_flow.gd` | — | todo |
| REQ-0001-004 | `v2-rendering-lod.md` | `tests/world/test_city_chunk_renderer.gd` | `--script res://tests/world/test_city_hlod_contract.gd` | — | todo |
| REQ-0001-005 | `v2-navigation-e2e.md` | `tests/world/test_city_nav_chunks.gd` | `--script res://tests/e2e/test_city_navigation_flow.gd` | — | todo |
| REQ-0001-006 | `v2-chunk-streaming.md`, `v2-rendering-lod.md` | `tests/world/test_city_debug_overlay.gd` | `--script res://tests/e2e/test_city_large_world_e2e.gd` | — | todo |
| REQ-0001-007 | `v2-navigation-e2e.md` | `tests/e2e/test_city_large_world_e2e.gd` | `--script res://tests/e2e/test_city_large_world_e2e.gd` | — | todo |

验证命令默认使用：

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://<test-path>.gd'
```

## ECN 索引

- 当前无 ECN。

## 差异列表

- v1 无流式加载，所有可见内容仍由单场景直接持有。
- v1 无 MultiMesh/HLOD/occlusion 的分块约束。
- v1 无分块导航，也无跨多 chunk 的 E2E travel 证据。
- v1 缺少性能/debug 护栏，因此不能宣称具备“大城市底盘”。
