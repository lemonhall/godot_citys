# V41 Rifle Audio Loop

## Goal

为 `rifle` 接入用户提供的 `M4 Assault rifle Long Burst.wav`，把它放入正式资产目录，并让主世界 `CityPrototype` 与 `SpiderCrawlerLab` 都像 weapon 8 一样，通过各自 `CombatRoot` 下的正式 rifle emitter 播放这段 fire audio。held-fire 期间该 burst 不能依赖 Godot 的 WAV loop，而必须用 `non-loop + 手动续播` 保持连续；松手、切枪、驾驶或控制失效时，音频必须及时停止。

## Dependencies

- 依赖 `v40` 已冻结的 rifle visual / ballistic 主链
- 依赖 `PlayerController.set_primary_fire_active()` 与 `get_weapon_state()` 的 held-fire 输入语义
- 依赖 `CityPrototype` / `SpiderCrawlerLab` 的正式 combat root

## Contract Freeze

- 正式音频资源路径：`res://city_game/assets/weapons/rifles/audio/M4 Assault rifle Long Burst.wav`
- 正式 wrapper scene：`res://city_game/assets/weapons/rifles/audio/RifleFireAudioPlayer.tscn`
- 正式 world-side emitter：`res://city_game/combat/CityRifleFireEmitter.tscn`
- 正式 getters：
  - `get_rifle_audio_state()`
  - `get_player_rifle_audio_debug_state()`
- 正式 debug fields：
  - `emitter_present`
  - `stream_bound`
  - `stream_path`
  - `playing`
  - `engine_playing`
  - `play_trigger_count`
  - `restart_trigger_count`
  - `stop_count`
  - `loop_enabled`

## Scope

做什么：

- 把用户放在仓库根目录的 WAV 归置到正式 rifle audio 资产目录
- 补齐对应 `.import`
- 在 `PlayerController` 上冻结 held-fire 语义与状态暴露
- 在 `CityPrototype` / `SpiderCrawlerLab` 的 `CombatRoot` 下挂一个 dedicated rifle emitter
- 让 held-fire 使用 non-loop + 手动续播 持续播放
- 新增 focused audio contract tests

不做什么：

- 不改 grenade / laser / missile 的音频
- 不拆分单发、三连发、空仓等更多 rifle SFX
- 不改 HUD、mix bus、混响或 occlusion 系统

## Acceptance

1. 自动化测试必须证明：正式 M4 burst WAV 存在于 rifle audio 资产目录。
2. 自动化测试必须证明：`PlayerController` 暴露 `get_rifle_audio_state()`。
3. 自动化测试必须证明：`CityPrototype` 暴露 `get_player_rifle_audio_debug_state()`。
4. 自动化测试必须证明：`SpiderCrawlerLab` 暴露 `get_player_rifle_audio_debug_state()`。
5. 自动化测试必须证明：held-fire 时 rifle world emitter 只在进入时 start 一次，而不是每个 cooldown tick 重播。
6. 自动化测试必须证明：held-fire 超过原始 `2.6s` 样本窗口后仍保持 active，且是通过 `restart_trigger_count` 证明 manual restitch 成立，而不是 Godot WAV loop。
7. 自动化测试必须证明：松手后 rifle audio 及时 stop。
8. 自动化测试必须证明：主世界 rifle / spider lab combat 合同没有被新音频破坏。

## Files

- Create: `docs/plan/v41-index.md`
- Create: `docs/plan/v41-rifle-audio-loop.md`
- Create: `docs/plans/2026-03-23-v41-rifle-audio-loop-design.md`
- Create: `docs/plan/v41-m2-verification-2026-03-23.md`
- Create: `city_game/assets/weapons/rifles/audio/RifleFireAudioPlayer.tscn`
- Create: `city_game/combat/CityRifleFireEmitter.tscn`
- Modify: `city_game/assets/weapons/rifles/audio/M4 Assault rifle Long Burst.wav.import`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/scenes/labs/SpiderCrawlerLab.gd`
- Modify: `city_game/scripts/PlayerController.gd`
- Create: `tests/world/test_city_player_rifle_audio_contract.gd`
- Create: `tests/world/test_city_player_rifle_world_audio_contract.gd`
- Create: `tests/world/test_spider_crawler_lab_rifle_audio_contract.gd`

## Steps

1. TDD Red
   - 先写 rifle audio contract test，锁定 asset path、non-loop、held-fire manual restitch 和 release 行为。
2. Asset formalization
   - 归置 `.wav` 与 `.import`，补 wrapper scene 与 world-side emitter scene。
3. TDD Green
   - 在 `PlayerController` 上实现 held-fire runtime state，并在 `CityPrototype` / `SpiderCrawlerLab` 上接 world-side emitter。
4. Regression
   - 跑 rifle / combat / spider lab focused tests。
5. Closeout
   - 写 fresh verification 文档。
