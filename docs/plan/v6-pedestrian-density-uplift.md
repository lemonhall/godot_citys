# V6 Pedestrian Density Uplift

## Goal

把 `pedestrian_mode = lite` 从“虽然守住红线，但街上仍偏空”的状态，推进到“主街、核心区和高活动区拥有更可信的人流存在感，同时继续守住 `16.67ms/frame` 红线”的状态。

## PRD Trace

- REQ-0002-011

## Scope

做什么：

- 上调默认 `district_class_density` 与 `road_class_density`，优先提升 core / mixed / 主街路段的 crowd presence
- 视需要调整 deterministic spawn-slot 分配阈值或等价 lane occupancy 规则，确保 uplift 反映到真实 query / roster，而不是只改文档数字
- 保持 `pedestrian_mode = lite` 下 Tier 1 优先吃掉密度增量，继续把 Tier 2 / Tier 3 视为高成本近场集合
- 在 uplift 完成后重新跑 isolated travel/runtime profiling，确认 crowd 变密后仍守住红线

不做什么：

- 不做 `full` crowd 模式
- 不做通过抬高 Tier 2 / Tier 3 hard cap 来伪造“更热闹”
- 不做全城统一饱和填充，不抹平 district / road class 之间的差异

## Acceptance

1. 自动化测试必须证明：`pedestrian_mode = lite` 默认配置下，`core >= 0.78`、`mixed >= 0.62`、`residential >= 0.46`、`industrial >= 0.30`、`periphery >= 0.16`，且保持 `core > mixed > residential > industrial > periphery`。
2. 自动化测试必须证明：`pedestrian_mode = lite` 默认配置下，`arterial >= 0.45`、`secondary >= 0.32`、`collector >= 0.20`、`local >= 0.12`，且保持 `arterial > secondary > collector > local > expressway_elevated`。
3. 自动化 profiling 必须证明：沿现有固定 warm/first-visit profiling 路线，`ped_tier1_count` 至少达到 warm `>= 24`、first-visit `>= 52`，不得继续回到 M6 的稀疏基线 warm `14` / first-visit `36`。
4. `tests/e2e/test_city_pedestrian_performance_profile.gd` 与 `tests/e2e/test_city_runtime_performance_profile.gd` 必须继续 `PASS`，且 `wall_frame_avg_usec <= 16667`。
5. `tests/e2e/test_city_pedestrian_travel_flow.gd` 必须继续 `PASS`，证明 density uplift 没有引入 page leak、duplicate page load 或 spawn storm。
6. 反作弊条款：不得通过复制静止假人、关闭 identity continuity、抬高 Tier 2 / Tier 3 hard cap 或把所有 district 强行拉平为同一高密度来宣称需求完成。

## Files

- Modify: `city_game/world/pedestrians/model/CityPedestrianConfig.gd`
- Modify: `city_game/world/pedestrians/model/CityPedestrianQuery.gd`
- Modify: `city_game/world/pedestrians/generation/CityPedestrianWorldBuilder.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianBudget.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `tests/world/test_city_pedestrian_density_profile.gd`
- Create: `tests/world/test_city_pedestrian_lite_density_uplift.gd`
- Modify: `tests/e2e/test_city_pedestrian_performance_profile.gd`
- Modify: `tests/e2e/test_city_runtime_performance_profile.gd`
- Modify: `tests/e2e/test_city_pedestrian_travel_flow.gd`

## Steps

1. 写失败测试（红）
   - 扩展 `test_city_pedestrian_density_profile.gd`，把新的 lite density 下限写死。
   - 新增 `test_city_pedestrian_lite_density_uplift.gd`，断言固定 query / profile 路线上的 density 与 spawn capacity 高于 M6 稀疏基线。
   - 扩展 `test_city_pedestrian_performance_profile.gd`，把 warm/first-visit `ped_tier1_count` 的 uplift 门槛写死。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是当前 density profile 与 profiling count 仍停留在 M6 的稀疏默认值。
3. 实现（绿）
   - 调整 density scalar、spawn-slot 阈值与相关 deterministic query / roster 构建逻辑。
   - 仅在 profiling 证据不足以达到目标时，再评估是否需要单独 ECN 讨论 budget contract；默认不先动高成本 cap。
4. 跑到绿
   - density profile、travel flow 与两条 isolated profiling 基线全部 PASS。
5. 必要重构（仍绿）
   - 收敛 density 配置来源，确保 debug overlay、minimap、query 与 runtime roster 继续同源。
6. E2E / Profiling
   - isolated 重新运行 `test_city_pedestrian_performance_profile.gd` 与 `test_city_runtime_performance_profile.gd`，确认 uplift 后仍不打穿红线。

## Risks

- 如果只提高配置数字但不让 deterministic query / spawn-slot 实际增量落地，用户观感不会改善。
- 如果通过提高高成本 Tier 2 / Tier 3 cap 来做“密度 uplift”，会把 crowd 问题重新变成性能问题。
- 如果 density uplift 不保留 district / road class 层次，城市会从“太空”变成“到处一样满”的另一种失真。

## Verification

- 2026-03-13 本地 headless `PASS`：`tests/world/test_city_pedestrian_density_profile.gd`
- 2026-03-13 本地 headless `PASS`：`tests/world/test_city_pedestrian_lite_density_uplift.gd`
- 2026-03-13 回归 `PASS`：`tests/e2e/test_city_pedestrian_travel_flow.gd`
- lite density floor fresh 证据：`core >= 0.78`、`mixed >= 0.62`、`residential >= 0.46`、`industrial >= 0.30`、`periphery >= 0.16`，且 `arterial >= 0.45`、`secondary >= 0.32`、`collector >= 0.20`、`local >= 0.12`
- lite uplift fresh 证据：`tests/world/test_city_pedestrian_lite_density_uplift.gd` 输出 warm `tier1_count = 54`、first-visit `tier1_count = 60`，duplicate page load 持续为 `0`
- 2026-03-13 isolated profiling 继续守线：`tests/e2e/test_city_pedestrian_performance_profile.gd` warm `16048`、first-visit `13507`；`tests/e2e/test_city_runtime_performance_profile.gd` warm `12339`
- 运行期通过增量 chunk crowd membership、state-ref chunk snapshot 与 mount-time crowd apply 去重，把 uplift 后的 fresh isolated first-visit 红线重新压回 `16.67ms/frame` 以内，而没有回退 district / road density floor。
