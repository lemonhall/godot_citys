# V41 Rifle Audio Loop Design

## Summary

`v41` 最终采用“正式 asset 归置 + Player held-fire state + world-side rifle emitter”的方案。`M4 Assault rifle Long Burst.wav` 会被放到 `city_game/assets/weapons/rifles/audio/`，并继续保留一个小的 `RifleFireAudioPlayer.tscn` wrapper；但真正负责主世界与蜘蛛 lab 发声的，是模仿 weapon 8 链路放在战斗侧的 `CityRifleFireEmitter.tscn`。`PlayerController` 只负责维护 held-fire runtime state 与 context-exit stop 语义；`CityPrototype` 与 `SpiderCrawlerLab` 则各自在 `CombatRoot` 下持有一个 dedicated rifle emitter，在 held-fire 激活时先触发一次 `play()`，随后按 `2.55s` 的 restart window 手动续播，直到 release/context exit 再 `stop()`。

## Why This Design

直接把 `play()` 放在 `request_primary_fire()` 上会有一个问题：步枪 cooldown 是 `0.12s`，而用户给的是一段 `2.6s` 的长 burst。如果每次发射都触发一次 `play()`，最终听起来就会是同一段长音频被不断重头打断，效果非常假。把这段音频视为“持续压枪循环音”才符合素材的性质。

同时，用户明确要求“抄按键 8”，而 weapon 8 的可闻链路是战斗侧正式节点而不是 `PlayerController` 私有本地节点。因此 `v41` 把真正的 rifle emitter 也下放到 `CityPrototype` / `SpiderCrawlerLab` 的 world combat chain，避免把 audible result 绑死在玩家节点自身。

另外，调试里已经证明这份 M4 资源一旦走 Godot 的 `AudioStreamWAV.LOOP_FORWARD`，混音能量会塌到几乎为零；同一资源改成 non-loop 则波形正常。因此 `v41` 明确禁用 Godot WAV loop，改成 emitter 侧的手动续播。

同时，headless 下 `AudioStreamPlayer3D.playing` 的表现并不总足够稳定，不能把“是否已经启动过 loop / restart”完全押在引擎内部状态上。所以 `v41` 在 world-side 维护 runtime active 与 elapsed 秒数来驱动 start/stop/restart 计数，这样自动化测试可以稳定验证：

- hold 期间 `play_trigger_count == 1`
- 长按超过样本窗口后 `restart_trigger_count >= 1`
- release 后 `stop_count >= 1`

## Data Flow

`InputEventMouseButton(left down)`
-> `set_primary_fire_active(true)`
-> `request_primary_fire()` 继续走原 projectile 主链
-> `PlayerController.get_weapon_state().primary_fire_active = true`
-> `CityPrototype._update_player_rifle_audio_emitter()` / `SpiderCrawlerLab._update_player_rifle_audio_emitter()`
-> first active edge: world-side emitter `play()`
-> hold continues: sync emitter position; if elapsed passes `2.55s` window, emitter `play()` again
-> `InputEventMouseButton(left up)` or weapon/context exit
-> `PlayerController` clears held-fire state
-> world-side emitter `stop()`

## Test Strategy

- focused：
  - `tests/world/test_city_player_rifle_audio_contract.gd`
  - `tests/world/test_city_player_rifle_world_audio_contract.gd`
  - `tests/world/test_spider_crawler_lab_rifle_audio_contract.gd`
- regression：
  - `tests/world/test_city_player_rifle_vfx_and_ballistics.gd`
  - `tests/world/test_city_player_combat.gd`
  - `tests/world/test_city_player_grenade.gd`
  - `tests/world/test_city_player_missile_launcher.gd`
  - `tests/world/test_city_player_vehicle_drive_mode.gd`
  - `tests/world/test_spider_crawler_lab_rifle_feedback_contract.gd`
  - `tests/world/test_spider_crawler_lab_combat_contract.gd`
  - `tests/e2e/test_spider_crawler_lab_combat_flow.gd`
