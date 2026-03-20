# V31 Scene Preview Editor Plugin Design

## Summary

`v31` 采用“薄插件入口 + 复用 v30 harness”的方案。插件只负责三件事：识别当前编辑场景是否可预览、把当前编辑态 materialize 成临时 subject snapshot、再驱动 `v30` 的 harness/wrapper 播放链。这样做的关键好处是，`v30` 已经验证过的 preview 舞台、自由飞行、FPS overlay、subject contract 都继续复用；`v31` 增加的是 editor ergonomics，而不是再造一套 preview 运行时。

## Options

### Option A: Editor Toolbar Button + Transient Snapshot + v30 Harness

推荐方案。

- 在 `addons/scene_preview` 提供正式 `EditorPlugin`
- 按钮出现在 3D 编辑器菜单/工具条里
- 点击时读取 `edited scene root`
- 将当前编辑态打包到 `user://scene_preview/editor_subjects/*.tscn`
- 再生成临时 wrapper 到 `user://scene_preview/editor_wrappers/*.tscn`
- 最后调用 editor play custom scene 进入 preview

优点：

- 用户只点一个按钮
- 不污染 `res://`
- 未保存编辑态也能进 preview
- 完整复用 `v30` harness

缺点：

- 需要增加 `addons/` 基建
- editor shell 自动化测试比 `v30` 更难

### Option B: Bottom Dock / Preview Panel

不推荐作为首版。

优点：

- 可扩展更多控制项

缺点：

- UI 面过大
- 首版需求只是“一个按钮”
- 会把 `v31` 范围抬高

### Option C: 继续生成 repo 内 wrapper 并让插件只当快捷入口

不采用。

原因：

- 还是会污染源码树
- 用户仍要处理 wrapper 文件资产
- 与“点击按钮后剩下的自动完成”相冲突

## Frozen Design

`v31` 冻结为以下正式口径：

- 新增正式插件目录：
  - `addons/scene_preview/plugin.cfg`
  - `addons/scene_preview/plugin.gd`
- 新增 editor orchestration 服务：
  - `addons/scene_preview/ScenePreviewEditorSessionBuilder.gd`
  - `addons/scene_preview/ScenePreviewEditorEligibility.gd`
- 继续复用：
  - `res://city_game/preview/ScenePreviewHarness.tscn`
  - `res://city_game/preview/ScenePreviewHarness.gd`
  - `res://tools/scene_preview/generate_scene_preview_wrapper.gd` 或正式抽出的共用服务
- 临时产物路径冻结为：
  - `user://scene_preview/editor_subjects/`
  - `user://scene_preview/editor_wrappers/`

## UX Freeze

- 当前编辑 scene root 为 `Node3D` 时：
  - Preview 按钮可见且可用
- 当前编辑 scene root 不可 preview 时：
  - 按钮禁用或提示原因
- 点击 Preview 后：
  1. materialize 当前编辑态 subject snapshot
  2. 生成/刷新临时 wrapper
  3. 调用 editor play custom scene
  4. 进入与 `v30` 一致的 preview 玩法态

## Testability Strategy

editor plugin 本体要尽量薄，把大部分逻辑压到可 headless 测试的纯服务层：

- `ScenePreviewEditorEligibility`
  - 负责判断当前 scene 是否可 preview
- `ScenePreviewEditorSessionBuilder`
  - 负责 snapshot path、wrapper path、preview request 组装
- `plugin.gd`
  - 只负责按钮、editor callback、调用服务、触发播放

这样自动化测试至少可以锁住：

- plugin manifest contract
- eligibility contract
- snapshot/wrapper orchestration contract
- `v30` harness 复用 contract

## Why This Fits The Repo

- 满足用户的真实目标：以后不再手工接线
- 满足 `scene-first`：preview 舞台仍是正式场景，不是插件里硬编码 geometry/light
- 满足 `v30 -> v31` 演进逻辑：按钮只是入口升级，不会造成两套 preview 主链
