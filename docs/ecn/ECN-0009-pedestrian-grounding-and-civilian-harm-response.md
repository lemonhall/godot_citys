# ECN-0009: Pedestrian Runtime Grounding and Civilian Harm Response

## 基本信息

- **ECN 编号**：ECN-0009
- **关联 PRD**：PRD-0002
- **关联 Req ID**：REQ-0002-002、REQ-0002-005、新增 REQ-0002-008、新增 REQ-0002-009
- **发现阶段**：v6 M5 收口后的手玩验收 / 用户反馈
- **日期**：2026-03-13

## 变更原因

`v6` 的 M1-M5 已完成 lane graph、tiering、streaming/reactivity 与 redline guard，但 2026-03-13 的手玩验收暴露了两项仍然影响产品感知的缺口：

- pedestrian 运行期行走没有稳定贴合真实 chunk 地表；在坡地、roadbed 或局部地形过渡上仍会出现“被地形吞没 / 浮空”的观感问题。
- 玩家开枪、直接命中或投掷手雷时，当前 crowd 只会触发 reaction，不会结算 civilian death，也不会让周边 pedestrian 形成可信的 panic / flee 扩散。

这说明 `PRD-0002` 现有“spawn grounding + limited reactive behavior”口径还不够覆盖真实手玩质量要求。如果继续把 `v6` 视为已经完全收口，会导致 PRD、计划和玩家实际体验再次脱节。

## 变更内容

### 原设计

- `REQ-0002-002` 只要求 spawn anchors、lane graph 与 chunk continuity 正确，没有把“运行期行走时的贴地口径必须与真实 chunk 地表一致”写成独立需求。
- `REQ-0002-005` 只要求近场等待、让路、sidestep、panic / flee 等有限 reactive behavior，没有把 civilian casualty 与 violence-driven flee resolution 写成明确验收。

### 新设计

- 新增 `REQ-0002-008`：要求 active pedestrian 的运行期贴地必须与真实 chunk 地表口径一致，覆盖 spawn、step、tier 升降级和 chunk 回访。
- 新增 `REQ-0002-009`：要求玩家暴力事件能对 direct victims 结算 civilian death，对周边 pedestrian 结算 panic / flee，同时继续服从 crowd budget 和 redline guard。
- `v6` 新开 `M6`，专门承载这两项产品级补口，而不是把它们继续塞进已经关闭的 `M2/M4/M5` 结果描述里。
- `M6` 的死亡表现最低要求是“明确死亡结算 + live crowd 移除 / death state”，不在本轮引入 ragdoll、wanted system 或 civilian combat 扩展。

## 影响范围

- 受影响的 Req ID：
  - REQ-0002-002
  - REQ-0002-005
  - 新增 REQ-0002-008
  - 新增 REQ-0002-009
- 受影响的 vN 计划：
  - `docs/plan/v6-index.md`
  - `docs/plan/v6-pedestrian-runtime-grounding.md`
  - `docs/plan/v6-pedestrian-civilian-casualty-response.md`
- 受影响的测试：
  - `tests/world/test_city_pedestrian_runtime_grounding.gd`
  - `tests/world/test_city_pedestrian_projectile_kill.gd`
  - `tests/world/test_city_pedestrian_grenade_kill_and_flee.gd`
  - `tests/e2e/test_city_pedestrian_combat_flow.gd`
  - `tests/e2e/test_city_pedestrian_performance_profile.gd`
  - `tests/e2e/test_city_runtime_performance_profile.gd`
- 受影响的代码文件：
  - `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
  - `city_game/world/rendering/CityChunkRenderer.gd`
  - `city_game/scripts/CityPrototype.gd`
  - 以及后续 `projectile / grenade / ground sampler` 相关文件

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0009）
- [x] v6 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新
