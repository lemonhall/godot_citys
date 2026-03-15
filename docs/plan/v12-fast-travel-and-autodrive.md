# V12 Fast Travel and Autodrive

## Goal

让同一个 `resolved_target + route_result` 同时支持一键瞬移和 player-only 自动驾驶，并把 auto-drive 明确限定为 route consumer，而不是第二套 route solver。

## PRD Trace

- REQ-0006-007
- REQ-0006-008

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
4. 自动化测试必须证明：开启 auto-drive 后，相关 profiling 仍不过线。
5. 反作弊条款：不得通过“瞬移绕过 target parser”“自动驾驶重新求另一条简化路径”“只在空场景下证明能到达”来宣称完成。

## Files

- Modify: `city_game/scripts/PlayerController.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/navigation/CityChunkNavRuntime.gd`
- Create: `city_game/world/navigation/CityAutodriveController.gd`
- Create: `tests/world/test_city_fast_travel_target_resolution.gd`
- Create: `tests/e2e/test_city_fast_travel_map_flow.gd`
- Create: `tests/e2e/test_city_autodrive_flow.gd`
- Modify: `docs/plan/v12-index.md`

## Steps

1. 写失败测试（红）
   - fast travel target resolution、autodrive flow、manual interrupt 三类测试先写。
2. 运行到红
   - 预期失败点是当前没有正式 fast travel/auto-drive consumer。
3. 实现（绿）
   - 新建 `CityAutodriveController`，只消费 route result。
   - 在 `PlayerController/CityPrototype` 里接入 fast travel 与 auto-drive 状态机。
4. 运行到绿
   - fast travel/autodrive tests 与相关 driving flow tests 通过。
5. 必要重构（仍绿）
   - target resolution、vehicle control、UI trigger 解耦。
6. E2E
   - 串行跑 `test_city_fast_travel_map_flow.gd`、`test_city_autodrive_flow.gd` 与性能三件套。

## Risks

- 如果 auto-drive 直接绑在 route solver 里，后续 reroute 与 HUD 会互相污染。
- 如果 teleport 与 auto-drive 不共用同一目标解析，地图选点体验会分裂成两套入口。
- 如果 auto-drive 逻辑默认扩展到 ambient traffic，会直接越出 `v12` 边界。
