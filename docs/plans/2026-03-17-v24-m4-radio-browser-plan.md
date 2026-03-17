# 2026-03-17 V24 M4 Radio Browser Plan

## Goal

把 `v24` 的 `M4 radio browser UX` 从设计文档推进到正式实现主链，先收最小 browser state contract，再逐步补交互流、国家目录 drill-down 与 preset/favorite 编辑链。

## Current Slice

本轮先做 `M4` 的第一刀，不试图一次做完整浏览器：

- 在 `CityPrototype.gd` 上冻结 browser surface 的最小 contract：
  - `open_vehicle_radio_browser()`
  - `close_vehicle_radio_browser()`
  - `get_vehicle_radio_browser_state()`
- browser 默认 tab 冻结为 `browse`
- tab 家族冻结为：
  - `now_playing`
  - `presets`
  - `favorites`
  - `recents`
  - `browse`
- `Browse` 根节点只显示 `countries` 目录，不预先铺出 station rows
- HUD 上先接一个最小 full-screen browser view 壳，证明浏览器状态面已经进入正式 UI 主链

## Out Of Scope For This Slice

- 国家目录 drill-down 到 `top 200` station page
- local keyword filter
- browser 内新增/移除 favorite
- browser 内编辑 preset slot
- browser e2e flow

这些都留给 `M4` 后续切片继续推进。

## Tests

本轮最小 red/green contract：

- `tests/world/test_city_vehicle_radio_browser_state_contract.gd`

聚焦回归：

- `tests/world/test_city_vehicle_radio_quick_overlay_contract.gd`
- `tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd`
- `tests/world/test_city_vehicle_radio_catalog_cache_contract.gd`
- `tests/world/test_city_vehicle_radio_preset_persistence.gd`
- `tests/world/test_city_hud_mouse_passthrough_contract.gd`
- `tests/world/test_city_prototype_ui.gd`

## Exit Criteria

满足以下条件即可把本 slice 记为 `M4 in_progress`：

- browser state contract 通过
- quick overlay / quick switch e2e 不回退
- browser shell 已进入 HUD 主链
- `v24-index` 已同步更新 `M4 / REQ-0014-003` 口径
