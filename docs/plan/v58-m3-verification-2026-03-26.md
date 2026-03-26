# V58 M3 Verification - 2026-03-26

## 范围

- 版本：`v58`
- 需求：
  - `REQ-0027-012`
  - `REQ-0027-013`
- 日期：`2026-03-26`

## TDD Red 边界

在实现前，先运行新增 red tests。首个失败边界为：

- 命令：
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_drone_squadron_wingman_impact_presentation_contract.gd'`
- 失败摘要：
  - `Wingman impact presentation contract requires at least one resolved strike event`

这证明旧链路当时虽然能派出僚机，但还没有把 resolved impact presentation summary 正式回写到可验证的事件载荷里。

## Fresh Verification

### M0 Docs Freeze

- 命令：
  - `rg -n "REQ-0027-012|REQ-0027-013|impact FX|爆炸音效|path_seed|deterministic|俯冲弧线" docs/prd/PRD-0027-drone-flight-foundation.md docs/ecn/ECN-0042-drone-wingman-strike-presentation.md docs/plan/v58-index.md docs/plan/v58-drone-wingman-strike-presentation.md docs/plans/2026-03-26-v58-drone-wingman-strike-presentation-design.md`
- 结果：
  - `exit code 0`
  - 命中文档链：`PRD-0027`、`ECN-0042`、`v58-index`、`v58 plan`、`v58 design`

### V58 Focused Tests

- 命令：
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_drone_squadron_wingman_impact_presentation_contract.gd'`
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_drone_squadron_wingman_dive_profile_contract.gd'`
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_player_drone_squadron_strike_presentation_flow.gd'`
- 结果：
  - 全部 `PASS`

覆盖点：

- 僚机 resolved strike event 会回写 `impact_fx_played = true`
- 僚机 resolved strike event 会回写爆炸环、爆炸球、爆炸音效触发次数与非空音频资源路径
- 僚机 resolved strike event 会回写非零 `path_seed`
- 僚机 resolved strike event 会回写非零曲线偏移、非零垂向弧线偏移、非恒速 speed envelope
- area strike 的多架僚机不会共享同一条 clone track

### V57 Regressions

- 命令：
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_drone_squadron_single_strike_dispatch_contract.gd'`
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_drone_squadron_area_strike_command_contract.gd'`
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_player_drone_squadron_strike_flow.gd'`
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_drone_suicide_strike_contract.gd'`
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_player_drone_kamikaze_flow.gd'`
- 结果：
  - 全部 `PASS`

回归点：

- single wingman dispatch 合同未退化
- middle-click area strike 的波次与落点合同未退化
- leader-only kamikaze fallback 仍保留
- `NO SIGNAL` 仍只属于最后一架 leader 自爆旧链

### Stability Guard

- 命令：
  - 连续 `5` 次运行：
    - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_drone_squadron_wingman_dive_profile_contract.gd'`
- 结果：
  - `5 / 5 PASS`

说明：

- fresh rerun 期间暴露过一次 flaky 边界：短路径或提早 `impact` 时，旧的 debug 采样只记录了 step 起点速度，偶发把真实的加速段低估成“接近恒速”。
- 本轮已把 speed envelope 采样修到 step 起点和终点两端，因此稳定性 rerun 不再出现该误判。

### Headless Parse Check

- 命令：
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --quit`
- 结果：
  - `exit code 0`

## 备注

- 全部 fresh runs 期间都出现同一条预存 warning：
  - `res://city_game/combat/artillery/CityM777Howitzer.tscn:8 - ext_resource, invalid UID ... CityArtilleryLanyardLine.gd`
- 该 warning 与 `v58` 无人机机群 strike presentation 改动无直接耦合；本轮未处理。

## 结论

- `REQ-0027-012`：通过
- `REQ-0027-013`：通过
- `v58` closeout：通过
