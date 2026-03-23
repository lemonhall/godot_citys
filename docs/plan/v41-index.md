# V41 Index

## 愿景

设计入口：[2026-03-23-v41-rifle-audio-loop-design.md](../plans/2026-03-23-v41-rifle-audio-loop-design.md)

依赖入口：

- [v40-index.md](./v40-index.md)

`v41` 的目标不是再改 rifle 的视觉和弹道，而是把 rifle 的正式音频链补齐。用户已经提供了 `M4 Assault rifle Long Burst.wav`，`v41` 最终冻结为“正式 asset 归置 + world-side rifle emitter”方案：主世界 `CityPrototype` 与 `SpiderCrawlerLab` 都像 weapon 8 一样，在各自 `CombatRoot` 下持有一个 dedicated rifle audio emitter。按住左键时它先启动一次，随后按 `2.55s` restart window 手动续播，松手、切枪、失控或驾驶时立刻停，避免每个 cooldown tick 都把同一段长 burst 重新触发一遍，也绕开 Godot WAV loop 的静音问题。

## 决策冻结

- 正式 rifle fire audio asset：
  - `res://city_game/assets/weapons/rifles/audio/M4 Assault rifle Long Burst.wav`
- 正式 rifle fire wrapper：
  - `res://city_game/assets/weapons/rifles/audio/RifleFireAudioPlayer.tscn`
- 正式 world-side emitter scene：
  - `res://city_game/combat/CityRifleFireEmitter.tscn`
- 正式 debug getters：
  - `PlayerController.get_rifle_audio_state()`
  - `CityPrototype.get_player_rifle_audio_debug_state()`
  - `SpiderCrawlerLab.get_player_rifle_audio_debug_state()`
- 长按左键语义冻结为：
  - 持续按住时只 start 一次
  - sample 走 non-loop + manual restitch
  - 松手后 promptly stop

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | `v41` plan / design 冻结 | 文档链完整，asset path 与 hold-loop 合同明确 | `rg -n "M4 Assault rifle Long Burst|get_player_rifle_audio_debug_state|CityRifleFireEmitter" docs/plan/v41-index.md docs/plan/v41-rifle-audio-loop.md docs/plans/2026-03-23-v41-rifle-audio-loop-design.md` | done |
| M1 asset + hold semantics | 正式资产归位、Player held-fire runtime 语义 | held-fire 只 start 一次，release/context exit 立停 | `tests/world/test_city_player_rifle_audio_contract.gd` | done |
| M2 world-side emitter | main-world / spider lab 都接入 weapon-8 风格的 rifle emitter | 两条正式世界链都暴露 rifle emitter debug state，并复用同一 M4 asset | `tests/world/test_city_player_rifle_world_audio_contract.gd`、`tests/world/test_spider_crawler_lab_rifle_audio_contract.gd` | done |
| M3 regression | rifle / main-world / spider lab 回归 | rifle 新音频不打坏既有 projectile / vfx / spider lab combat 主链 | `tests/world/test_city_player_rifle_audio_contract.gd`、`tests/world/test_city_player_rifle_world_audio_contract.gd`、`tests/world/test_city_player_rifle_vfx_and_ballistics.gd`、`tests/world/test_city_player_combat.gd`、`tests/world/test_city_player_grenade.gd`、`tests/world/test_city_player_missile_launcher.gd`、`tests/world/test_city_player_vehicle_drive_mode.gd`、`tests/world/test_spider_crawler_lab_rifle_audio_contract.gd`、`tests/world/test_spider_crawler_lab_rifle_feedback_contract.gd`、`tests/world/test_spider_crawler_lab_combat_contract.gd`、`tests/e2e/test_spider_crawler_lab_combat_flow.gd` | done |

## 计划索引

- [v41-rifle-audio-loop.md](./v41-rifle-audio-loop.md)

## 追溯矩阵

| Req ID | V41 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0041-001 | `v41-rifle-audio-loop.md` | `tests/world/test_city_player_rifle_audio_contract.gd` | `--script res://tests/world/test_city_player_rifle_audio_contract.gd` | [v41-m2-verification-2026-03-23.md](./v41-m2-verification-2026-03-23.md) | done |
| REQ-0041-002 | `v41-rifle-audio-loop.md` | `tests/world/test_city_player_rifle_world_audio_contract.gd` | `--script res://tests/world/test_city_player_rifle_world_audio_contract.gd` | [v41-m2-verification-2026-03-23.md](./v41-m2-verification-2026-03-23.md) | done |
| REQ-0041-003 | `v41-rifle-audio-loop.md` | `tests/world/test_spider_crawler_lab_rifle_audio_contract.gd`、`tests/world/test_spider_crawler_lab_rifle_feedback_contract.gd` | `--script res://tests/e2e/test_spider_crawler_lab_combat_flow.gd` | [v41-m2-verification-2026-03-23.md](./v41-m2-verification-2026-03-23.md) | done |
| REQ-0041-004 | `v41-rifle-audio-loop.md` | `tests/world/test_city_player_vehicle_drive_mode.gd`、`tests/world/test_city_player_grenade.gd`、`tests/world/test_city_player_missile_launcher.gd`、`tests/world/test_spider_crawler_lab_combat_contract.gd` | focused regression run | [v41-m2-verification-2026-03-23.md](./v41-m2-verification-2026-03-23.md) | done |

## Closeout 证据口径

- `v41` 不能只凭耳朵感觉“好像有声音了”；必须有 fresh test 证明：
  - formal asset path
  - player held-fire single-start behavior
  - non-loop + manual restitch behavior
  - main-world rifle emitter contract
  - spider-lab rifle emitter contract
  - release stop behavior

## ECN 索引

- 暂无
