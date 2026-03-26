# V57 M3 Verification - 2026-03-26

## 范围

- 版本：`v57`
- 需求：
  - `REQ-0027-010`
  - `REQ-0027-011`
- 日期：`2026-03-26`

## TDD Red 边界

在实现前，先运行新增 red tests。首个失败边界为：

- 命令：
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_drone_squadron_single_strike_dispatch_contract.gd'`
- 失败摘要：
  - `Single wingman strike dispatch must keep camera/input ownership on the leader`

这证明旧链路当时仍把左键默认解释成 leader 自爆，而不是僚机 dispatch。

## Fresh Verification

### M0 Docs Freeze

- 命令：
  - `rg -n "REQ-0027-010|REQ-0027-011|12m|0.6s|MOUSE_BUTTON_LEFT|MOUSE_BUTTON_MIDDLE|NO SIGNAL" docs/prd/PRD-0027-drone-flight-foundation.md docs/ecn/ECN-0041-drone-squadron-strike-orders.md docs/plan/v57-index.md docs/plan/v57-drone-squadron-strike-orders.md docs/plans/2026-03-26-v57-drone-squadron-strike-orders-design.md`
- 结果：
  - `exit code 0`
  - 命中文档链：`PRD-0027`、`ECN-0041`、`v57-index`、`v57 plan`、`v57 design`

### V57 Focused Tests

- 命令：
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_drone_squadron_single_strike_dispatch_contract.gd'`
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_drone_squadron_area_strike_command_contract.gd'`
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_player_drone_squadron_strike_flow.gd'`
- 结果：
  - 全部 `PASS`

覆盖点：

- 有僚机时左键只派 1 架僚机，不让长机进入 `strike_committed`
- 单架僚机 strike 结束后，`active_total_count / desired_total_count` 正式减 `1`
- 长机在僚机 strike 期间持续保留 `camera_owner=input_owner=drone`
- 中键 area strike 会生成多个落点，且全部保持在 `12m` 半径内
- 中键 area strike 的 dispatch 波次满足 `1 -> 2 -> 3`
- 相邻 area strike 波次首发间隔不少于 `0.6s`
- 只剩长机时，左键仍回退到旧 leader kamikaze + `NO SIGNAL`

### Regressions

- 命令：
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_drone_suicide_strike_contract.gd'`
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_player_drone_kamikaze_flow.gd'`
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_drone_squadron_summon_contract.gd'`
- 结果：
  - 全部 `PASS`

回归点：

- leader-only 自爆旧链仍保留
- `NO SIGNAL` closeout 仍只在最后一架 leader 自爆时出现
- 机群召唤/回收与总数上限合同未退化

### Headless Parse Check

- 命令：
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --quit`
- 结果：
  - `exit code 0`

## 备注

- 全部 fresh runs 期间都出现同一条预存 warning：
  - `res://city_game/combat/artillery/CityM777Howitzer.tscn:8 - ext_resource, invalid UID ... CityArtilleryLanyardLine.gd`
- 该 warning 与 `v57` 无人机机群打击改动无直接耦合；本轮未处理。

## 结论

- `REQ-0027-010`：通过
- `REQ-0027-011`：通过
- `v57` closeout：通过
