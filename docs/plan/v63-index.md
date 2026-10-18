# V63 Index

- 主题：城市总规生成范式（先地理、后城市、再做建筑）
- PRD：`docs/prd/PRD-0034-city-plan-generation.md`
- ECN：`docs/ecn/ECN-0044-city-plan-generation.md`
- 计划：`docs/plan/v63-city-plan-generator.md`
- 状态：`M0-M4` done；`M5` doing（切片水面/地标/天台已接，4 点步行 E2E 与地形高度待做）
- 成本档位：`standard`（每里程碑最多 3 轮 Review）

## 愿景

把城市从「沿路撒建筑的均匀贴图」改成「有地理、有历史、有层次、可步行探索的地方」。
成功标准见 PRD-0034 的 7 条 Req ID。

## 里程碑

| 里程碑 | 内容 | DoD（硬） | 验证 | 状态 |
| --- | --- | --- | --- | --- |
| M0 | PRD/ECN/v63 文档与门禁 | 7 条 Req ID、ECN 同步、追溯矩阵齐全、gates pass | `tashan_loop status` | done |
| M1 | 确定性总规 + 地形水系 | 同 seed 哈希一致；河 ≥3000m、宽 40~120m；切片水面 ≥2%；缓存往返一致 | `test_city_plan_determinism.gd`、`test_city_plan_terrain.gd` | done |
| M2 | 历史核心 + 路网 + 铁路 + 区域 | core 距水岸 ≤800m；轴 ≥2；车站 ≥3；每区 ≥3%（waterfront ≥2%）；道路不穿水 | `test_city_plan_history.gd`、`test_city_plan_roads.gd`、`test_city_plan_districts.gd` | done |
| M3 | 街区与地块语法 | 70% 临街立面 ≤8m；oldtown 面宽 ≤12m；downtown ≥24m；巷弄 ≥4m 且连通；oldtown 内院 ≥30% | `test_city_plan_parcels.gd`（含街墙比率） | done |
| M4 | 时代语法 + 3 地标 + 可上天台 | era 匹配 ≥95%；地标唯一且最高 ≥120m；收分 ≤10%；天台可达 | `test_city_plan_era_grammar.gd`、`test_city_plan_landmarks.gd`、`test_city_plan_roof_access.gd` | done |
| M5 | 1km² 切片 + E2E + 性能 + Review | 4 点截图；性能三件套 PASS；切片外回退一致；无 open BLOCKER | `test_city_plan_slice_walkthrough.gd` + 性能三件套 | todo |

## 追溯矩阵

| Req ID | 里程碑 | 测试 | 证据 | 状态 |
| --- | --- | --- | --- | --- |
| REQ-0034-001 | M1 | `test_city_plan_determinism.gd` | PASS 2026-10-19（同 seed 哈希一致、缓存往返一致） | done |
| REQ-0034-002 | M1 | `test_city_plan_terrain.gd` | PASS 2026-10-19（河长 ≥3000m、宽 50~109m、切片水面 ≥2%、高差连续） | done |
| REQ-0034-003 | M2 | `test_city_plan_history.gd`、`test_city_plan_roads.gd` | PASS 2026-10-19（core 在水岸、3 轴、闭环铁路、4 站；干道不穿水） | done |
| REQ-0034-004 | M2/M3 | `test_city_plan_districts.gd`、`test_city_plan_parcels.gd` | PASS 2026-10-19（区域份额、地块宽度、街墙 100%、巷弄 4m+、内院 45%） | done |
| REQ-0034-005 | M4 | `test_city_plan_era_grammar.gd`、`test_city_plan_landmarks.gd`、`test_city_plan_roof_access.gd` | PASS 2026-10-19（era 100%、3 地标唯一、最高 220m、双塔连桥、天台可达 ≥90% 高度） | done |
| REQ-0034-006 | M4/M5 | `test_city_plan_slice_scene.gd`、`test_city_plan_roof_access.gd`、`test_city_plan_slice_walkthrough.gd` | slice_scene + roof_access PASS 2026-10-19；4 点步行 E2E 待做 | doing |
| REQ-0034-007 | M5 | 性能三件套 + 回退抽样 | `chunk_setup` PASS 7348/8500 usec（地标改 compact 后 proxies 2213→722） | doing |

## ECN 索引

| ECN | 摘要 | 状态 |
| --- | --- | --- |
| ECN-0044 | 城市生成从沿路撒建筑改为总规驱动 | PRD/计划已同步；测试待 M1 |

## DoD 硬度自检

- 每条 DoD 均为二元或量化：哈希相等、长度/宽度/占比/阈值、命令 PASS。
- 每条 DoD 绑定命令或测试文件。
- 反作弊条款：切片外 `variant_id` 必须与 v62 基线一致；`plan_hash` 必须跨进程一致；天台可达必须有坐标断言，不能只截图。
- Scope 明确不做：夜景/天气/人流 AI、完整室内、任务链。

## 文档完整性自检

- [x] PRD 7 条 Req ID 均有范围/非目标/验收。
- [x] 每条计划可追溯到 Req ID。
- [x] 每条验收带验证命令或测试文件。
- [x] 术语一致：CityPlan / District / Block / Parcel / Era / Slice。
- [x] ECN-0044 已同步 PRD 与本计划。

## Review 记录

（M1 起每个里程碑完成前追加，格式见塔山 SKILL）

## 触发审计

- expected_review_triggers：M0 文档完成、M1-M5 每个里程碑完成、v63 全完成
- actual_review_runs：0
- skipped_triggers：0
- skip_reasons：—
- mitigation：由 `tashan_loop review` 记录

## 差异列表

（M1 起回写）
