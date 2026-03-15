# V12 Fast Travel and Autodrive

## Goal

让同一个 `resolved_target + route_result` 同时支持一键瞬移和 player-only 自动驾驶，并把 auto-drive 明确限定为 route consumer，而不是第二套 route solver。

## PRD Trace

- Direct: REQ-0006-007
- Guard / Performance: REQ-0006-008

## Dependencies

- 依赖 M2 已交付正式 `resolved_target`。
- 依赖 M3 已交付正式 `route_result` 与 reroute lifecycle。
- M4 不是 logic blocker，但 map-triggered 主链体验依赖 M4 的 full map / destination selection 落地。

## Contract Freeze

- fast travel 的正式输入冻结为 `resolved_target`；正式输出冻结为 `safe_drop_anchor + arrival_heading + source_target_id`。
- `safe_drop_anchor` 必须来自可重复的安全落点策略，不允许直接把玩家传送到 `raw_world_anchor` 的任意无效位置。
- auto-drive 的正式状态机冻结为：`inactive -> armed -> following_route -> interrupted / arrived / failed`。
- auto-drive 的显式中断触发至少包括：玩家手动 steering/throttle/brake 输入、退出 driving mode、目标失效。
- auto-drive 只允许消费 `route_result` 与 reroute 回调；不允许偷偷再求一条隐藏路线。

## Scope

做什么：

- 支持从 map/place query 结果触发 fast travel
- 支持玩家当前控制车辆沿正式 route 自动开往目标
- 支持中断 auto-drive，控制权回到玩家
- 保持与既有 driving mode 共存

不做什么：

- 不做 ambient traffic 全局自动驾驶重写
- 不做复杂交通礼让、超车、事故恢复、警察规避
- 不做 taxi service 玩法包装

## Acceptance

1. 自动化测试必须证明：fast travel 消费正式 `resolved_target`，落点稳定且不落入无效地形。
2. 自动化测试必须证明：auto-drive 消费正式 route steps，而不是直线追目标或另一套隐藏路线。
3. 自动化测试必须证明：玩家可以显式中断 auto-drive，车辆控制权正确回到手动驾驶。
4. 自动化测试必须证明：到达目标、目标失效或 reroute 失败会进入显式完成/失败状态，而不是静默卡死。
5. 自动化测试必须证明：开启 auto-drive 后，相关 profiling 仍不过线。
6. 反作弊条款：不得通过“瞬移绕过 target parser”“自动驾驶重新求另一条简化路径”“只在空场景下证明能到达”来宣称完成。

## Files

- Modify: `city_game/scripts/PlayerController.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/navigation/CityChunkNavRuntime.gd`
- Create: `city_game/world/navigation/CityFastTravelResolver.gd`
- Create: `city_game/world/navigation/CityAutodriveController.gd`
- Create: `tests/world/test_city_fast_travel_target_resolution.gd`
- Create: `tests/world/test_city_autodrive_interrupt_contract.gd`
- Create: `tests/e2e/test_city_fast_travel_map_flow.gd`
- Create: `tests/e2e/test_city_autodrive_flow.gd`
- Modify: `tests/e2e/test_city_vehicle_hijack_drive_flow.gd`
- Modify: `docs/plan/v12-index.md`

## Steps

1. 写失败测试（红）
   - `fast travel target resolution / autodrive interrupt contract / autodrive flow / existing hijack driving regression` 四类测试先写。
2. 运行到红
   - 预期失败点是当前没有正式 fast travel/auto-drive consumer。
3. 实现（绿）
   - 新建 `CityFastTravelResolver`，把安全落点策略与 UI trigger 解耦。
   - 新建 `CityAutodriveController`，只消费 route result。
   - 在 `PlayerController/CityPrototype` 里接入 fast travel 与 auto-drive 状态机。
4. 运行到绿
   - fast travel/autodrive tests 与相关 driving flow tests 通过。
5. 必要重构（仍绿）
   - target resolution、vehicle control、UI trigger 解耦。
6. E2E
   - 串行跑 `test_city_fast_travel_map_flow.gd`、`test_city_autodrive_flow.gd`、`test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd`。

## Risks

- 如果 auto-drive 直接绑在 route solver 里，后续 reroute 与 HUD 会互相污染。
- 如果 teleport 与 auto-drive 不共用同一目标解析，地图选点体验会分裂成两套入口。
- 如果 auto-drive 逻辑默认扩展到 ambient traffic，会直接越出 `v12` 边界。
- 如果 fast travel 没有独立 `safe_drop_anchor` 规则，任何 off-road/raw-point 目标都会变成穿地或落入建筑体内的隐患。
