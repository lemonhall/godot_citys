# V35 Index

## 愿景

PRD 入口：

- [PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)
- [PRD-0002 Pedestrian Crowd Foundation](../prd/PRD-0002-pedestrian-crowd-foundation.md)
- [PRD-0003 Vehicle Traffic Foundation](../prd/PRD-0003-vehicle-traffic-foundation.md)
- [PRD-0022 Player Missile Launcher Weapon](../prd/PRD-0022-player-missile-launcher.md)
- [PRD-0023 Building Collapse Destruction Lab](../prd/PRD-0023-building-collapse-destruction-lab.md)

依赖入口：

- [v22-index.md](./v22-index.md)
- [v34-index.md](./v34-index.md)

`v35` 的目标不是马上“优化一堆地方看看会不会好点”，而是把用户现在遇到的真实运行时抖动拆成至少两条独立的性能诊断链并正式收口证据：

- 不炸楼时，沿有人行人的道路按 `C` 高速 inspection 穿行，仍然会出现明显 frame-time 抖动
- 用火箭炮炸楼后，如果同时引发行人恐慌，FPS 会进一步掉到 `20-30`

这轮要先回答：这到底是同一个 shared runtime 根因，还是 `inspection HUD/minimap`、`streaming renderer sync`、`crowd panic/combat` 各自叠加出来的两类问题。

## 决策冻结

- `v35` 是诊断版，不是假装 closeout 的优化版。
- `v35` 不直接沿用 `v22` 的 warm / first-visit 报告结论，必须跑 fresh rendered profiling。
- `v35` 当前至少拆两条场景：
  - `inspection_high_speed_with_pedestrians`
  - `panic_threat_chain_under_real_rendering`
- `v34` 的楼体坍塌 profiling 保留，但不把它误当成“行人恐慌链”的替代品。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 fresh rendered 基线 | `inspection` 疾跑与 `live gunshot` 恐慌链的 Windows/Vulkan 基线 | 两条现有 profiling 在真实渲染下跑出 fresh 数值，并落回文档 | rendered `test_city_pedestrian_high_speed_inspection_performance.gd` / `test_city_pedestrian_live_gunshot_performance.gd` | done |
| M2 focused diagnostics | 打开 diagnostics 后的分相位归因与 artifact | 至少能回答高频抖动主要落在 HUD/minimap、renderer_sync queue、crowd assignment、还是 combat/panic | targeted diagnostics tests + artifact | todo |
| M3 优化收口 | 基于证据的最小修复 | before/after 数值可对账，且不破坏 crowd/traffic/building gameplay contract | targeted regressions + profiling rerun | todo |

## 计划索引

- [v35-runtime-jitter-full-diagnostic.md](./v35-runtime-jitter-full-diagnostic.md)

## Closeout 证据口径

- `v35` 当前还没有 closeout。
- M1 只证明“用户说的抖动是真有，而且两条链都能 fresh 打红”，不证明已经定位完根因。
- 任何“问题已经找到/已经修复”的说法，都必须等 M2/M3 的 diagnostics artifact 和 rerun 证据。

## 差异列表

- `inspection` 疾跑在真实渲染下已经明显失守红线。
- `live gunshot` 恐慌链在真实渲染下也明显失守红线。
- 当前仍缺少两条场景在 diagnostics mode 下的 artifact，因此 `renderer_sync` 的具体子相位与 `panic/combat` 的更细热点还未定案。
