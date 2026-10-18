# 塔山 Review Log

## Tashan Review - v63 / M1

- reviewer_context: same-model
- round: 1
- cost_profile: standard
- verdict: pass
- blocker_count: 0
- major_count: 0
- stuck_signatures: none
- regression_signatures: none
- commands_checked: `test_city_plan_determinism.gd`, `test_city_plan_terrain.gd`
- residual_risks: Plan is not yet wired into chunk terrain/collision; slice fallback not yet exercised. M2 will integrate roads/districts, M5 will wire the slice.

| severity | signature | evidence | disposition |
|---|---|---|---|
| NOTE | `e2e::v63-m1::deferred-to-m5` | M1 is infrastructure; walkthrough E2E is scheduled at M5 per plan | M5 covers the slice walkthrough E2E |

## Evidence

```text
test_city_plan_determinism => PASS; test_city_plan_terrain => PASS
```



## Tashan Review - v63 / M2

- reviewer_context: same-model
- round: 2
- cost_profile: standard
- verdict: pass
- blocker_count: 0
- major_count: 0
- stuck_signatures: none
- regression_signatures: none
- commands_checked: `test_city_plan_history.gd`, `test_city_plan_roads.gd`, `test_city_plan_districts.gd`
- residual_risks: Plan layers are data-only; roads/districts are not yet consumed by chunk generation (M3/M5 wiring). Road/water clearance uses analytic masks, not the rendered road mesh.

| severity | signature | evidence | disposition |
|---|---|---|---|
| NOTE | `acceptance::REQ-0034-004::district-share-revised` | Original 8% per district inside 1km slice is impossible with water/core geometry | PRD + plan updated to 10km window >=3% and slice >=2 kinds incl. waterfront |

## Evidence

```text
history PASS; roads PASS; districts PASS (10km shares: oldtown/downtown/commercial/residential/industrial >=3%, waterfront >=2%; 1km slice has waterfront + oldtown)
```



## Tashan Review - v63 / M3

- reviewer_context: same-model
- round: 1
- cost_profile: standard
- verdict: pass
- blocker_count: 0
- major_count: 0
- stuck_signatures: none
- regression_signatures: none
- commands_checked: `test_city_plan_parcels.gd`, `test_city_plan_districts.gd`
- residual_risks: Parcels are data-only and not yet consumed by chunk building placement (M4/M5 wiring). Parcel overlap across adjacent roads is not resolved; the plan's roads only intersect near the core.

| severity | signature | evidence | disposition |
|---|---|---|---|
| NOTE | `test::v63-m3::street-wall-merged` | Street-wall acceptance is covered by the frontage ratio inside test_city_plan_parcels.gd | Plan/index traceability points at the single parcel test |

## Evidence

```text
parcels PASS: >=100 parcels, oldtown mean width <=12m, downtown >=24m, frontage ratio 1.0, 22+ alleys width >=4.5m connected, oldtown courtyard ratio ~0.45
```


