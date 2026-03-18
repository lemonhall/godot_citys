# PRD-0015 Soccer Ball Interactive Prop

## Vision

把 `godot_citys` 从“世界里只有可看、可导航、可对话的 authored 内容”推进到“世界里出现第一类正式可互动道具”的状态。`v25` 的首个 consumer 是一个足球：它不是 building override，也不是 landmark，而是一个独立 authored 的 `scene_interactive_prop`。玩家走近后，会看到正式的交互提示；按下 `E` 后，足球会基于玩家当前站位与朝向获得一次真实物理 impulse，开始滚动、弹跳、减速，形成最小但真实的“踢球”反馈。

`v25` 的成功标准不是“世界里摆了一个球模型”，也不是“某个脚本能把一个球瞬移出去”，而是同时满足五件事。第一，仓库要正式拥有 `scene_interactive_prop` 这条 sibling family，它与 `scene_landmark` 共享 authored placement 思路，但语义明确是“可互动道具”，不是“可发现地标”。第二，足球模型要从仓库根目录归置到正式资产路径，并通过 `registry -> manifest -> near chunk mount -> scene` 接入世界。第三，足球必须准确落在用户给定的 `chunk_129_139` 地面探针位置附近，并以正式的 ground-anchor contract 保留这次 authored 摆放输入。第四，玩家靠近后必须能通过正式交互链路触发踢球，而不是只靠撞一下或调试命令。第五，这个新 family 不得污染现有 `scene_landmark`、地图 pin、NPC 对话和 streaming/performance 纪律。

## Background

- `PRD-0012` 与 `v21` 已冻结 `scene_landmark registry -> manifest -> near chunk mount -> optional full_map_pin` 主链，证明“独立于 building_id 的 authored 世界内容”可以正式接入大世界。
- `PRD-0010` 与其后续实现已冻结 `E` 键交互、HUD prompt、场景内可交互对象 contract 的最小模式，但当前只服务 NPC dialogue。
- 当前仓库还没有一条正式的“可互动道具” family；如果把足球塞进 `scene_landmark`，语义会立刻错位，因为足球的核心价值不是“被看见/被导航到”，而是“被推动/被踢动”。
- 用户已经提供了明确摆放输入：
  - `chunk_id = chunk_129_139`
  - `chunk_key = (129,139)`
  - `lod = near`
  - `world_position = (-1877.94, 2.52, 618.57)`
  - `chunk_local_position = (-29.94, 2.52, -93.43)`
  - `surface_normal = (-0.02, 1.00, -0.02)`
- 用户还明确给出了体验约束：
  - 首版只要极简可互动，不需要完整足球竞技玩法
  - 不走 building override
  - 也不继续滥用 `scene_landmark`
  - 最好是独立 scene 文件，可像 landmark 一样被正式挂进世界

## Scope

本 PRD 只覆盖 `v25 soccer ball interactive prop`。

包含：

- 新增正式 `scene_interactive_prop` family
- 新增独立于 `scene_landmark` 的 interactive prop registry / manifest / runtime 主链
- 把根目录的足球 `glb` 归置到正式资产目录
- 新增首个 consumer：足球
- 足球通过 near chunk mount 挂进 `chunk_129_139`
- 足球提供正式交互 prompt 与 `E` 键踢球行为
- 足球本体采用真实物理 body，而不是纯脚本插值位移
- 补齐 manifest / runtime / interaction / e2e 回归测试

不包含：

- 不做球门、计分、射门判定、比赛规则或 AI 对手
- 不做 full map pin、minimap pin、导航、fast travel 或 autodrive
- 不做跨 session 的足球位置持久化
- 不做跨 chunk 长距离滚动后的 ownership 迁移
- 不做“头球、停球、带球、传球”等复杂足球动作系统

## Non-Goals

- 不追求把足球伪装成 landmark，只为了复用已存在的名词
- 不追求只靠玩家碰撞自然挤球来冒充“可踢”
- 不追求把所有互动道具一次性抽成复杂通用玩法框架
- 不追求为首版互动道具引入第二套地图/任务/UI 体系

## Requirements

### REQ-0015-001 系统必须支持独立于 landmark 的 `scene_interactive_prop` 主链

**动机**：足球、路锥、箱子、篮球之类物体都不是地标。它们需要独立身份、独立挂载和独立交互语义。

**范围**：

- 新增正式 registry：`scene_interactive_prop`
- registry entry 最小字段冻结为：
  - `prop_id`
  - `feature_kind`
  - `manifest_path`
  - `scene_path`
- `feature_kind` 在 `v25` 冻结为 `scene_interactive_prop`
- manifest 最小字段冻结为：
  - `prop_id`
  - `display_name`
  - `feature_kind`
  - `anchor_chunk_id`
  - `anchor_chunk_key`
  - `world_position`
  - `surface_normal`
  - `scene_root_offset`
  - `scene_path`
  - `manifest_path`
- chunk near mount 时，若当前 chunk 命中相关 interactive prop entry，则实例化 prop scene
- mount 必须是事件驱动的 chunk mount，不允许 per-frame 全量扫描 registry

**非目标**：

- 不要求 `v25` 首版支持 far visibility / persistent mount
- 不要求 `v25` 首版支持跨多个 chunk 的大型互动道具

**验收口径**：

- 自动化测试至少断言：interactive prop registry 能正式加载并按 chunk 索引 entry。
- 自动化测试至少断言：目标 chunk near mount 时，prop scene 会被实例化并带有稳定 `prop_id` 元数据。
- 自动化测试至少断言：没有 registry entry 的 chunk 不会凭空多挂 prop scene。
- 自动化测试至少断言：interactive prop mount 只发生在 chunk mount / remount 链路，不需要每帧扫全量 registry。
- 反作弊条款：不得把足球偷偷绑回 fake `landmark_id` 或 `building_id`；不得在 `_process()` 里全量扫 registry 来宣称完成。

### REQ-0015-002 足球资产必须被正式归置并准确落在用户指定的 authored 地面锚点（[已由 ECN-0024 变更](../ecn/ECN-0024-v25-soccer-ball-scale-readability.md)）

**动机**：首版 consumer 不是“任意一个球”，而是用户已经放到根目录、并给出 ground probe 的这个足球。

**范围**：

- 根目录足球模型必须归置到正式项目资产目录
- 足球 consumer 的正式 `prop_id` 冻结为 `prop:v25:soccer_ball:chunk_129_139`
- 足球 manifest 必须保留以下 authored placement 输入：
  - `anchor_chunk_id = chunk_129_139`
  - `anchor_chunk_key = (129,139)`
  - `world_position = (-1877.94, 2.52, 618.57)`
  - `surface_normal = (-0.02, 1.00, -0.02)`
- `world_position` 语义冻结为“地面 authored anchor”，不是球心
- `scene_root_offset` 用于把真实物理球心抬离地面，避免把用户给的 probe `y` 改写成另一个语义
- `v25` 当前冻结的足球玩法尺寸不是“真实足球大小”，而是面向可读性的 oversized 尺寸：
  - `target_diameter_m = 1.20`
  - `scene_root_offset.y = 0.60`
- 足球 scene 必须是独立 `.tscn`，不能把 `glb` 直接散落在根目录继续被 runtime 直接引用

**非目标**：

- 不要求 `v25` 首版把球埋进 place query / 搜索系统
- 不要求 `v25` 首版做足球专属地图图标

**验收口径**：

- 自动化测试至少断言：registry / manifest / scene path 三者口径一致，且指向正式足球 scene。
- 自动化测试至少断言：manifest 保存了用户给定的 chunk / position / normal authored anchor。
- 自动化测试至少断言：足球 mounted 后视觉包围盒尺寸达到冻结的 oversized 可读范围，且 visual bottom 与地面高度基本对齐。
- 反作弊条款：不得直接把根目录 `glb` 留在原位继续作为正式运行时入口；不得把 `world_position.y` 私自改成球心高度后仍宣称保留了用户给定落点。

### REQ-0015-003 玩家必须能通过正式交互链路踢球，且踢球结果由真实物理 impulse 产生

**动机**：足球的核心体验不是“能看到”，而是“能踢动”。

**范围**：

- 玩家靠近足球后，HUD 必须出现正式交互 prompt
- 玩家按下 `E` 时，若足球是当前最近的 primary interaction candidate，则触发 kick
- kick 最小 contract 冻结为：
  - 基于玩家到球的平面方向或玩家朝向求出 impulse 方向
  - 给球一个明确的向前 impulse
  - 给球一个可读的向上 lift，避免像死物一样贴地滑行
- 足球本体必须是正式物理 body，可持续滚动、减速、被再次踢动
- 非交互范围内不应误触 kick
- driving mode 中不应触发踢球 prompt 或 kick 行为

**非目标**：

- 不要求 `v25` 首版做脚部 IK、踢球动画或专门踢腿动作
- 不要求 `v25` 首版支持手柄震动或复杂音效系统

**验收口径**：

- 自动化测试至少断言：玩家靠近足球时会看到带 `E` 的交互 prompt。
- 自动化测试至少断言：触发 kick 后，足球的 `linear_velocity` 或位移会显著变化，而不是只改一个调试标志。
- 自动化测试至少断言：远离交互半径时，prompt 会消失，且 `E` 不会误踢远处足球。
- 自动化测试至少断言：driving mode 下不会把足球抢成主交互对象。
- 反作弊条款：不得把“踢球”实现成 `teleport_to`、关键帧动画、或直接写死终点位置；不得只靠玩家自然碰撞偶然挤动球就宣称已经有正式踢球交互。

### REQ-0015-004 `v25` 不得破坏现有 NPC 交互、scene landmark 与 streaming/performance 纪律

**动机**：互动道具是新 family，不是把现有交互链和 chunk runtime 再搅乱一次的借口。

**范围**：

- 现有 NPC 对话 prompt / `E` 键链继续成立
- `scene_interactive_prop` 与 `scene_landmark` 分开注册、分开 runtime，不得互相污染
- 足球不生成 full map / minimap pin
- 受影响的 streaming 与 mount guard 必须继续成立

**非目标**：

- 不要求 `v25` 首版补 profiling 三件套 closeout 文档
- 不要求 `v25` 首版解决仓库里其他历史性能 debt

**验收口径**：

- 受影响的 NPC interaction、scene landmark mount 与 streaming 相关测试必须继续通过。
- 新增 interactive prop contract / interaction / e2e tests 必须通过。
- 至少补一条 world contract test 与一条 e2e 流程测试覆盖足球链路。
- 反作弊条款：不得为了让足球出现而关闭 NPC prompt、关闭 scene landmark loader、或把 interactive prop 混进地图 pin runtime。

## Open Questions

- 足球是否需要跨 session 记住上次停留位置。当前答案：`v25` 不做，先固定 authored spawn。
- 足球滚出 anchor chunk 后是否需要转移 ownership。当前答案：`v25` 不做，先接受 near-window 道具语义。
- 后续互动道具是否都共用一个 base class。当前答案：先冻结 contract 与 family，不要求首版抽象过度。

## Future Direction

- `scene_interactive_prop` 后续可以扩到：
  - 篮球
  - 路锥
  - 可推动箱子
  - 简单物理机关
- 如果未来出现跨 chunk 长距离滚动道具、可存档道具、或需要地图标注的特殊互动道具，应在 `v25` 基础上单独立项，而不是回写本版的极简 contract。
