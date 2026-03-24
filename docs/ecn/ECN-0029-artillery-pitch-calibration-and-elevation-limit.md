# ECN-0029: Artillery Pitch Calibration And Elevation Limit

## 基本信息

- **ECN 编号**：ECN-0029
- **关联 PRD**：PRD-0029
- **关联 Req ID**：REQ-0029-004、REQ-0029-006
- **发现阶段**：v44 调试阶段
- **日期**：2026-03-24

## 变更原因

当前 M777 模型的炮管在视觉放平时，runtime `pitch` 读数约为 `14.7°`，说明 `pitch` API 直接暴露了模型内部偏置角，而不是用户真正关心的炮口仰角。同时真实 M777 俯仰射界需要限制在 `0-71°`，不能继续允许无界调角。

## 变更内容

### 原设计

`pitch` API 只要求能驱动 `PitchPivot`，但没有冻结“零位口径”和“仰角限位”。

### 新设计

- `pitch` 的对外口径改为“校准后的真实仰角”：
  - 炮口放平时为 `0°`
  - 正值表示抬高炮口
  - 最大仰角为 `71°`
- 模型内部允许保留一个模型专属零位偏置量，用于把 AI 模型的内建歪斜角校准回正式口径。
- lab HUD 与 lab API 统一显示校准后的真实仰角，而不是内部生硬旋转角。

## 影响范围

- 受影响的 Req ID：
  - `REQ-0029-004`
  - `REQ-0029-006`
- 受影响的 vN 计划：
  - `docs/plan/v44-artillery-howitzer-scene-and-lab.md`
  - `docs/plan/v44-index.md`
- 受影响的测试：
  - `tests/world/test_city_m777_howitzer_scene_contract.gd`
  - `tests/world/test_city_m777_howitzer_lab_scene_contract.gd`
- 受影响的代码文件：
  - `city_game/combat/artillery/CityM777Howitzer.gd`
  - `city_game/scenes/labs/M777HowitzerLab.gd`

## 处置方式

- [x] PRD 已同步更新
- [x] v44 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新
