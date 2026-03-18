# V27 M4 Verification - 2026-03-18

## Status Note

- 本文记录的是 `2026-03-18` 早前一轮 `M4` 功能通过快照。
- 用户随后继续手工实测，仍观察到 `03:15 -> 0:7` 这类一边倒比分、keeper live-play 行为失真，以及另一方向上的 `0:0` 过度收球局面。
- 因此本 verification 现阶段只能作为历史快照，不再代表当前 closeout 口径；`M4` 已 reopen，必须以后续新的 fresh rerun 证据覆盖。

## Reopened Design Principles

- `M4` 后续实现必须把随机性放进真实对抗节点，而不是放进比分或隐藏球轨迹：
  - keeper 抱球/分球成功率
  - 持球方被断球概率
  - 分球方向、压迫积极度与风险取舍
- 所有随机性都必须受正式 runtime contract 与 match seed 约束，能够被测试和 debug state 观测；不得以 hidden score buff / hidden auto-goal / hidden suction 形式作弊。
- 体力必须同时影响：
  - 跑动速度
  - 持续压迫能力
  - 护球稳定性
  - 被抢断概率
  - keeper 关键抱球信心
- AI 需要表现出“何时继续高压、何时放缓恢复体力”的真实取舍；任何前锋或 keeper 都不得被实现成无限体力、全时满强度的脚本角色。
- keeper 的正式行为链仍冻结为 `goalkeeper_intercept -> goalkeeper_secure_ball -> goalkeeper_distribute_ball`，但抱球成功率不能做成僵硬的绝对开关，必须受来球速度、线路、门前中央性、接触距离、体力与 match-seeded 扰动共同影响。

## Scope

- `v27` M4 live-play gold standard verification
  - 完整 `5:00` 自主比赛必须打出真实进球
  - `10` 场采样比分结果不能 `10/10` 完全一致
  - 单队单场不得达到两位数比分，单场分差不得超过 `6`
- `v27` 足球主链回归
  - AI kick / final scoreboard / reset-on-exit / e2e match flow
- 受影响 `v25/v26` 足球主链回归
  - ball kick / minigame goal flow

## Gold Standard Result

### Gold Standard 1

- `res://tests/e2e/test_city_soccer_5v5_full_match_score_contract.gd` -> PASS
- 结论：
  - 完整 `5:00` 自主比赛不再固定卡死在 `0:0`
  - 单场比分没有冲到两位数
  - 单场分差没有超过 `6`

### Gold Standard 2

- `res://tests/e2e/test_city_soccer_5v5_score_sampling_contract.gd` -> PASS
- 结论：
  - `10` 场完整比赛采样结果不是 `10/10` 完全一致
  - 采样过程中也未触发“两位数比分 / 超大分差”护栏

### Gold Standard 3

- 已并入上述两条慢验证：
  - `test_city_soccer_5v5_full_match_score_contract.gd`
  - `test_city_soccer_5v5_score_sampling_contract.gd`
- 结论：
  - 当前实现已满足“不得出现任一队 `>= 10` 球，且单场分差不得 `> 6`”的现实比分护栏

## Fresh Regression Reruns

- `res://tests/world/test_city_soccer_match_ai_kick_contract.gd` -> PASS
- `res://tests/world/test_city_soccer_match_final_scoreboard_contract.gd` -> PASS
- `res://tests/world/test_city_soccer_match_reset_on_exit_contract.gd` -> PASS
- `res://tests/e2e/test_city_soccer_5v5_match_flow.gd` -> PASS
- `res://tests/world/test_city_soccer_ball_kick_contract.gd` -> PASS
- `res://tests/e2e/test_city_soccer_minigame_goal_flow.gd` -> PASS

## Implementation Notes Verified

- 比赛不再靠“720 帧内进球”这类短窗 smoke 作为正式验收。
- 正式验收现在以完整 `5:00` 比赛和 `10` 场采样为准。
- 为了避免固定比分与夸张连刷分，当前实现新增了：
  - match-level team profile 扰动
  - 进球/出界后的 restart + kickoff 保护窗口
  - 真实比分护栏对应的慢验证脚本

## Remaining Blocker

- `M4` 的 live-play 功能金标准当前已通过
- 但这轮改动仍然触及 `CitySoccerVenueRuntime.gd` 的每帧比赛逻辑
- 因此最终 closeout 仍需 fresh rerun profiling 三件套：
  - `res://tests/world/test_city_chunk_setup_profile_breakdown.gd`
  - `res://tests/e2e/test_city_first_visit_performance_profile.gd`
  - `res://tests/e2e/test_city_runtime_performance_profile.gd`

## Closeout Call

- `M4` live-play gold standard: green
- `M4` regression reruns: green
- `M4` final closeout: pending fresh profiling guard
