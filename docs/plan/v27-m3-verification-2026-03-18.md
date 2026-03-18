# V27 M3 Verification - 2026-03-18

## Scope

- `v27` M3 functional closeout:
  - red/blue `5v5` match AI
  - final scoreboard winner highlight
  - leave-release-ring full reset
- `REQ-0017-006` affected regression reruns:
  - `v25` soccer ball interaction chain
  - `v26` venue reset / ambient freeze / goal flow chain
- profiling follow-up:
  - touched soccer match runtime tick, so profiling three-piece rerun is required

## Functional Changes Verified

- red/blue teams no longer share one generic chase script:
  - each side now exposes a live `press_ball` runner
  - off-ball teammates switch between `support_run` and `collapse_defense`
  - goalkeeper stays in `goal_guard` by default and upgrades to `goalkeeper_intercept` when the ball enters its box
- AI kick logic now branches by situation:
  - outfield attackers drive/shoot toward the opponent goal
  - defenders and goalkeepers clear the ball upfield instead of reusing the same forward shot vector
- the strengthened AI contract test now asserts:
  - both teams present active ball pressure
  - support runners remain on both sides during open play
  - home goalkeeper enters intercept mode near its own goal
  - at least one home outfielder collapses into defensive cover while the goalkeeper steps out

## Fresh Functional Reruns

### V27 match suite

- `res://tests/world/test_city_soccer_match_asset_contract.gd` -> PASS
- `res://tests/world/test_city_soccer_match_roster_contract.gd` -> PASS
- `res://tests/world/test_city_soccer_match_start_contract.gd` -> PASS
- `res://tests/world/test_city_soccer_match_countdown_contract.gd` -> PASS
- `res://tests/world/test_city_soccer_match_ai_kick_contract.gd` -> PASS
- `res://tests/world/test_city_soccer_match_final_scoreboard_contract.gd` -> PASS
- `res://tests/world/test_city_soccer_match_reset_on_exit_contract.gd` -> PASS
- `res://tests/e2e/test_city_soccer_5v5_match_flow.gd` -> PASS

### Affected V25/V26 regressions

- `res://tests/world/test_city_soccer_ball_kick_contract.gd` -> PASS
- `res://tests/e2e/test_city_soccer_ball_interaction_flow.gd` -> PASS
- `res://tests/world/test_city_soccer_ball_reset_contract.gd` -> PASS
- `res://tests/world/test_city_soccer_venue_ambient_freeze_contract.gd` -> PASS
- `res://tests/world/test_city_soccer_venue_ambient_freeze_hysteresis_contract.gd` -> PASS
- `res://tests/world/test_city_soccer_venue_radio_survives_ambient_freeze.gd` -> PASS
- `res://tests/e2e/test_city_soccer_minigame_goal_flow.gd` -> PASS

## Profiling Guard Status

### Sequential official order

- `res://tests/world/test_city_chunk_setup_profile_breakdown.gd` -> PASS
- `res://tests/e2e/test_city_first_visit_performance_profile.gd` -> PASS
- `res://tests/e2e/test_city_runtime_performance_profile.gd` -> FAIL

### Warm runtime failure

- failing sample:
  - `wall_frame_avg_usec = 11667`
  - threshold:
    - `<= 11000`
- interpretation:
  - `v27` M3 functional work is green
  - `v27` M4 guard closeout is not green yet
  - isolated rerun of `test_city_runtime_performance_profile.gd` later passed at `wall_frame_avg_usec = 10411`, which suggests jitter, but that does not replace the required ordered three-piece closeout evidence

## Closeout Call

- `M0` docs freeze: done
- `M1` asset + roster mount: done
- `M2` match start + HUD timer: done
- `M3` AI + final/reset loop: done
- `M4` e2e + guard verification: blocked on ordered profiling three-piece fresh rerun
