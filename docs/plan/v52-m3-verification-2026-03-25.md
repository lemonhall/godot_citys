# V52 M3 Verification - 2026-03-25

## Summary

`v52` 已完成 docs freeze、shared ballistic utility、howitzer payload / live shell integration 与 focused verification。当前默认弹型正式冻结为 `m795_he`，gameplay 射程 envelope 为 `1500m~22500m`；forward prediction、inverse solve 与 live shell runtime 共用 `CityArtilleryBallistics.gd`。

## Commands

### 1. Docs Freeze

```powershell
rg -n "REQ-0029-014|REQ-0029-015|REQ-0029-016|REQ-0029-017|1500|22500|CityArtilleryBallistics|forward|inverse|round-trip" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0036-artillery-gameplay-ballistic-solver.md docs/plan/v52-index.md docs/plan/v52-artillery-gameplay-ballistic-solver.md docs/plans/2026-03-25-v52-artillery-gameplay-ballistic-solver-design.md
```

Result: `PASS`

- `PRD-0029` 已新增 `REQ-0029-014` 到 `REQ-0029-017`
- `ECN-0036`、`v52-index`、`v52 plan` 与 `design` 文档全部命中
- `1500 / 22500 / CityArtilleryBallistics / forward / inverse / round-trip` 口径全部落文档

### 2. Focused + Regression Tests

```powershell
$tests=@(
  'res://tests/world/test_city_artillery_ammo_profile_contract.gd',
  'res://tests/world/test_city_artillery_ballistics_forward_solver_contract.gd',
  'res://tests/world/test_city_artillery_ballistics_inverse_solver_contract.gd',
  'res://tests/world/test_city_artillery_ballistics_round_trip_contract.gd',
  'res://tests/world/test_city_m777_howitzer_ballistic_profile_payload_contract.gd',
  'res://tests/world/test_city_artillery_shell_shared_ballistic_model_contract.gd',
  'res://tests/world/test_city_artillery_shell_visual_orientation_contract.gd',
  'res://tests/world/test_city_m777_howitzer_firing_solution_contract.gd',
  'res://tests/world/test_city_world_howitzer_ballistics_contract.gd',
  'res://tests/e2e/test_city_world_howitzer_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

Result: `PASS`

Verified:

- ammo profile contract
- forward ballistic solver contract
- inverse ballistic solver contract
- round-trip contract
- howitzer payload carries shell profile / solver velocity
- live shell runtime follows shared ballistic model
- shell visual orientation regression still green
- world howitzer ballistic runtime regression still green
- end-to-end world howitzer flow still green

### 3. Parse Check

```powershell
& $godot --headless --rendering-driver dummy --path $project --quit
```

Result: `PASS`

## Research Artifact

- Markdown: [2026-03-25-v52-artillery-gameplay-ballistics-research.md](E:/development/godot_citys/docs/plans/2026-03-25-v52-artillery-gameplay-ballistics-research.md)
- PDF: [2026-03-25-v52-artillery-gameplay-ballistics-research.pdf](E:/development/godot_citys/docs/plans/2026-03-25-v52-artillery-gameplay-ballistics-research.pdf)

## Traceability

| Req ID | Evidence | Status |
|---|---|---|
| REQ-0029-014 | `test_city_artillery_ammo_profile_contract.gd`; 本文档 | done |
| REQ-0029-015 | `test_city_artillery_ballistics_forward_solver_contract.gd`; 本文档 | done |
| REQ-0029-016 | `test_city_artillery_ballistics_inverse_solver_contract.gd`; `test_city_artillery_ballistics_round_trip_contract.gd`; 本文档 | done |
| REQ-0029-017 | `test_city_m777_howitzer_ballistic_profile_payload_contract.gd`; `test_city_artillery_shell_shared_ballistic_model_contract.gd`; `test_city_world_howitzer_ballistics_contract.gd`; `test_city_world_howitzer_flow.gd`; 本文档 | done |
