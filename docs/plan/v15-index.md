# V15 Index

## 愿景

PRD 入口：[PRD-0008 Laser Designator World Inspection](../prd/PRD-0008-laser-designator-world-inspection.md)

设计入口：[2026-03-16-v15-laser-designator-design.md](../plans/2026-03-16-v15-laser-designator-design.md)

依赖入口：

- [PRD-0004 Vehicle Hijack Driving](../prd/PRD-0004-vehicle-hijack-driving.md)
- [PRD-0006 Landmark Navigation System](../prd/PRD-0006-landmark-navigation-system.md)
- [v12-index.md](./v12-index.md)

`v15` 的目标不是给 combat 再塞一把伤害武器，而是让现有城市语义链真正能被玩家在 3D 世界里点读：按 `0` 切到激光指示器，左键打一束绿色激光，命中建筑就读到唯一建筑名字与 `building_id`，命中地面就读到 chunk 信息，结果同步复制到剪贴板，消息 `10` 秒后自动消失，并且整个链路继续守住 combat、HUD、chunk streaming 与 profiling 红线。

## 决策冻结

- `v15` 的建筑显示文本默认复用 `v12` 的 address grammar，不单独重写中文本地化格式。
- `v15` 允许使用 `visual building -> nearest deterministic frontage address` 映射，但映射结果必须冻结成正式 `building_id + display_name + generation locator` contract，而不是“只是 inspection label”。
- `v15` 不允许把 inspection 文本塞进 debug overlay 充当交付；必须是正式 HUD 消息层。
- `v15` 的 building clipboard text 必须包含 `building_id`，并且第二次 inspection 要立即覆盖第一次结果。
- `v15` 不允许复用 bullet/grenade 节点冒充绿色激光束。
- `v15` 是未来“按唯一建筑 ID 找生成参数 -> 独立场景重建 -> 编辑功能建筑 -> 回城替换原建筑”链路的锚点版本。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 武器模式与激光发射 | `0` 切换、左键触发绿色激光、beam state | `laser designator` 正式接入 weapon mode；不会继续生成 projectile/grenade；beam state 可被测试读取 | `tests/world/test_city_player_laser_designator.gd` | done |
| M2 建筑 identity、chunk inspection 与 clipboard | building collider payload、chunk inspection、HUD/clipboard message | 建筑命中返回非空 `building_id` 与唯一 `display_name`；地面命中返回 chunk 信息；第二次 inspection 会立即刷新 HUD/clipboard；HUD 消息 `10` 秒后自动消失 | `tests/world/test_city_player_laser_designator.gd`、`tests/e2e/test_city_laser_designator_flow.gd` | done |
| M3 回归与性能复验 | combat/HUD 回归、profiling 三件套 | 现有 rifle/grenade/crosshair 不回退；性能三件套串行通过 | `tests/world/test_city_player_grenade.gd`、`tests/world/test_city_combat_crosshair.gd`、`tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | done |

## 计划索引

- [v15-laser-designator-world-inspection.md](./v15-laser-designator-world-inspection.md)

## 追溯矩阵

| Req ID | v15 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0008-001 | `v15-laser-designator-world-inspection.md` | `tests/world/test_city_player_laser_designator.gd` | `--script res://tests/world/test_city_player_laser_designator.gd` | [v15-m3-verification-2026-03-16.md](./v15-m3-verification-2026-03-16.md) | done |
| REQ-0008-002 | `v15-laser-designator-world-inspection.md` | `tests/world/test_city_player_laser_designator.gd` | `--script res://tests/e2e/test_city_laser_designator_flow.gd` | [v15-m3-verification-2026-03-16.md](./v15-m3-verification-2026-03-16.md) | done |
| REQ-0008-003 | `v15-laser-designator-world-inspection.md` | `tests/world/test_city_player_laser_designator.gd` | `--script res://tests/e2e/test_city_laser_designator_flow.gd` | [v15-m3-verification-2026-03-16.md](./v15-m3-verification-2026-03-16.md) | done |
| REQ-0008-004 | `v15-laser-designator-world-inspection.md` | `tests/world/test_city_player_grenade.gd`、`tests/world/test_city_combat_crosshair.gd`、`tests/world/test_city_player_laser_designator.gd` | `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | [v15-m3-verification-2026-03-16.md](./v15-m3-verification-2026-03-16.md) | done |

## Closeout 证据口径

- `v15` closeout 必须以 fresh tests + fresh profiling 为准，统一落在 `docs/plan/v15-mN-verification-YYYY-MM-DD.md`。
- 只改聊天记录或只改 debug overlay 文案，不算 `v15` 证据。
- 性能三件套必须严格串行执行。

## ECN 索引

- [ECN-0021-v15-building-identity-anchor.md](../ecn/ECN-0021-v15-building-identity-anchor.md)

## 差异列表

- `v15` 正式承诺唯一建筑名字与 `building_id` contract；不再接受“只有 inspection label、没有 formal building identity”的口径。
- `v15` 首版不做中文地址显示格式重排，继续复用现有 `v12` canonical address grammar。
