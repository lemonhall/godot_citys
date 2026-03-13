# V6 Pedestrian Character Model Replacement

## Goal

把 pedestrian 从“近景行为是对的，但视觉仍是盒子/竖棍占位”的状态，推进到“`Tier2 + Tier3` 使用真实 civilian `glb` 模型和 walk/run/death 动画，近景不再抽象”的状态，同时保持 `Tier1` 的轻量批渲染和 `16.67ms/frame` 红线纪律不被打穿。

## PRD Trace

- REQ-0002-012

## Scope

做什么：

- 把用户提供的 7 个 civilian `glb` 归档到项目内正式资产目录，并统一为稳定可引用的路径
- 落一份 pedestrian visual manifest，固定每个模型的 `idle / walk / run / death` 动画名，并显式记录逐模型 `source_height_m / source_ground_offset_m`，把尺寸不一致的 `glb` 归一化到统一 pedestrian 身高/贴地口径
- 把 `Tier2 + Tier3` 从当前 `BoxMesh` 占位切换到真实 character scene / model 实例
- 让 ambient movement 至少播放 `walk` 动画，`panic / flee` 优先使用 `run` 动画；如个别模型缺失 `run`，必须有统一 fallback
- 让被 projectile / explosion 判定为死亡的近景 pedestrian 通过短暂 death visual 播放 `death/dead` clip，而不是继续“命中即无”
- 保持 `Tier1` 继续走 batched 轻量表示，不在本轮重写远景 crowd 表示层

不做什么：

- 不在 `M8` 里把 `Tier1` 改成全动画骨骼 crowd
- 不在 `M8` 里做完整动画状态机、IK、ragdoll 或复杂 blend tree
- 不在 `M8` 里引入全新的美术导入流水线、材质重烘焙或大规模骨骼 retargeting 系统

## Acceptance

1. 自动化测试必须证明：这 7 个 civilian `glb` 已从仓库根目录归档到 `city_game/assets/pedestrians/civilians/`，manifest 中每个模型都绑定了稳定的 `walk / run / death` 动画名，并显式记录 `source_height_m / source_ground_offset_m` 归一化字段。
2. 自动化测试必须证明：`Tier2 + Tier3` 不再生成当前 `BoxMesh` 占位 pedestrian，而是实例化真实 civilian model 节点，并能解析到 `AnimationPlayer` 或等价动画入口。
3. 自动化测试必须证明：ambient pedestrian 至少播放 `walk` 动画；`panic / flee` 至少播放 `run` 或等价加速 locomotion 动画；casualty death visual 至少播放 `death/dead` clip，不允许继续看起来像静态盒子平移或命中即消失。
4. 自动化测试必须证明：`Tier1` 继续保持轻量 batched representation，本轮不会把远景 crowd 升级成高成本骨骼实例海。
5. `tests/e2e/test_city_pedestrian_performance_profile.gd` 与 `tests/e2e/test_city_runtime_performance_profile.gd` 必须继续 `PASS`，不得因为近景真模型替换把运行期红线打穿。
6. 反作弊条款：不得通过“只给单个 demo ped 换模型”“只在测试场景手工摆模型”“保留盒子但把材质改得更像人”或“击杀后直接瞬时删除近景行人”来宣称 M8 完成。

## Files

- Create: `city_game/assets/pedestrians/civilians/pedestrian_model_manifest.json`
- Create: `city_game/world/pedestrians/rendering/CityPedestrianVisualCatalog.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianReactiveAgent.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Create: `tests/world/test_city_pedestrian_character_asset_manifest.gd`
- Create: `tests/world/test_city_pedestrian_character_scale_normalization.gd`
- Create: `tests/world/test_city_pedestrian_tier2_visual_instances.gd`
- Create: `tests/world/test_city_pedestrian_tier3_visual_instances.gd`
- Create: `tests/e2e/test_city_pedestrian_character_visual_presence.gd`
- Verify: `tests/e2e/test_city_pedestrian_performance_profile.gd`
- Verify: `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 写失败测试（红）
   - `test_city_pedestrian_character_asset_manifest.gd` 断言 manifest 覆盖 7 个模型、路径有效、`walk / run / death` 动画名不为空，并带 `source_height_m / source_ground_offset_m`。
   - `test_city_pedestrian_character_scale_normalization.gd` 断言 7 个 `glb` 的原始高度与脚底偏移已被准确写入 manifest，且 runtime visual instance 会按这些字段把模型归一化到 pedestrian `height_m`。
   - `test_city_pedestrian_tier2_visual_instances.gd` 与 `test_city_pedestrian_tier3_visual_instances.gd` 断言近景行人不再是 `BoxMesh` 占位，而是带动画入口的真实 character scene，且能切到 `walk / run / death`。
   - `test_city_pedestrian_character_visual_presence.gd` 断言 live world 近景里能看到非占位 pedestrian model，并在 casualty 后留下 death visual。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是当前 `Tier2 + Tier3` 仍在 [CityPedestrianCrowdRenderer.gd](../../city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd) 和 [CityPedestrianReactiveAgent.gd](../../city_game/world/pedestrians/simulation/CityPedestrianReactiveAgent.gd) 中直接生成 `BoxMesh`。
3. 实现（绿）
   - 新增 visual catalog / manifest loader，把 archetype 或 seed 映射到这 7 个 civilian model。
   - 用真实 model scene 替换 `Tier2 + Tier3` 占位 mesh，并接通 `walk / run / death` 动画播放。
4. 跑到绿
   - 资产 manifest、Tier2/Tier3 视觉实例、live visual presence 与 death visual 全部 PASS。
5. 必要重构（仍绿）
   - 收敛 visual catalog 与 animation clip 选择逻辑，避免 `Tier2`、`Tier3` 各自维护一套模型加载分支。
6. E2E / Profiling
   - isolated 重新运行 `test_city_pedestrian_performance_profile.gd` 与 `test_city_runtime_performance_profile.gd`，确认真模型替换没有把近景 crowd 成本打穿红线。

## Risks

- 如果直接把 `Tier1` 也切成真实动画模型，本轮很容易从“换近景视觉”失控成“重写整套 crowd 表示层”。
- 如果模型路径、动画名和 archetype 映射不先固化到 manifest，后续实现就会退化成硬编码字符串和猜动画名。
- 如果 `Tier2` / `Tier3` 各自单独加载、单独选动画，后续视觉修复和性能回归会迅速失控。
- 如果 casualty 继续“命中即无”，即使模型替换完成，玩家对街头暴力反馈的观感仍会停留在抽象层。
- 如果只看视觉不做 fresh profiling，很容易把“竖棍没了”换成“近景掉帧更多”。
