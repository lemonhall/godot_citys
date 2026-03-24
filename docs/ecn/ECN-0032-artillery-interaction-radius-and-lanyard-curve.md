# ECN-0032: Artillery Interaction Radius And Lanyard Curve

## 基本信息

- **ECN 编号**：ECN-0032
- **关联 PRD**：PRD-0029
- **关联 Req ID**：
  - `REQ-0029-007`
  - `REQ-0029-008`
- **发现阶段**：v47 closeout 后的实机回归
- **日期**：2026-03-24

## 变更原因

用户在实机调试中给出了两个明确反馈：

1. howitzer 的 `5m` 进入半径过于紧，靠近火炮时很容易因为轻微走位进不去或刚进就丢提示，实际操作体验偏“贴脸才行”，不符合“逼真但不硬核”的交互目标。
2. 现有 `LanyardLine` 继续复用了钓鱼 minigame 的 `FishingLineVisual.gd`。该实现本质上是三点折线，并且下垂量在 howitzer scene 的父级缩放链下被放大，导致操炮态长绳出现“折线贴地”的错误视觉。

## 变更内容

### 原设计

- `M777HowitzerLab` 的正式 enter radius 冻结为约 `5m`
- `LanyardLine` 只要求“可见”，没有冻结成火炮专用 rope curve contract

### 新设计

- howitzer enter radius 从约 `5m` 提升到 `7m`；`20m` 操炮保活半径保持不变
- `LanyardLine` 改为正式 artillery 专用 rope visual，不再复用 fishing line
- rope visual 必须满足：
  - baseline 与操炮态 operator rope 都以连续曲线呈现
  - 不能退回三点折线
  - 下垂语义必须保持为稳定 world-scale 量级，不能被父级缩放放大到贴地

## 影响范围

- 受影响的 Req ID：
  - `REQ-0029-007`
  - `REQ-0029-008`
- 受影响的 vN 计划：
  - `docs/plan/v48-index.md`
  - `docs/plan/v48-artillery-interaction-polish.md`
- 受影响的测试：
  - `tests/world/test_city_m777_howitzer_scene_contract.gd`
  - `tests/world/test_city_m777_howitzer_lab_interaction_contract.gd`
  - `tests/world/test_city_m777_howitzer_fire_contract.gd`
- 受影响的代码文件：
  - `city_game/scenes/labs/M777HowitzerLab.gd`
  - `city_game/combat/artillery/CityM777Howitzer.tscn`
  - `city_game/combat/artillery/CityM777Howitzer.gd`
  - `city_game/combat/artillery/CityArtilleryLanyardLine.gd`

## 处置方式

- [x] PRD 已同步更新
- [x] v48 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新
