# PRD-0021 Scene Preview Editor Plugin

## Vision

把 `godot_citys` 的 scene preview 工作流从 `v30` 的“已有通用 harness，但仍要靠命令/wrapper 接线”继续推进到“在 Godot 编辑器里打开一个 3D 场景，点一下 preview 按钮，就能直接进入正式 preview 玩法态”。`v31` 的目标不是再造第三套 preview 系统，也不是把逻辑重新塞回每个 subject 场景，而是把 `v30` 已经冻结好的 `ScenePreviewHarness + wrapper generation + optional subject contract` 资产链抬升成一个正式的 `EditorPlugin`。用户不需要再手工生成 wrapper、不需要再给新场景单独加按钮脚本、不需要再为每个模型口述“加灯、加环境、加相机、加控制器”；只要当前编辑的是一个可预览的 3D 场景，编辑器里就应该出现一个明确的 Preview 按钮，点下去之后插件自动处理当前场景快照、preview wrapper、以及进入运行态预览。

`v31` 的成功标准不是“仓库里多了个 addons 目录”，而是四件事同时成立。第一，编辑器侧必须存在一条正式的 preview 入口，用户不再需要命令行接线。第二，这条入口必须复用 `v30` 主链，而不是在插件里复制一份简化版 preview 舞台。第三，插件必须默认预览“当前编辑状态”，包括未保存的变更，而不是只能跑磁盘上旧版本的场景。第四，这套机制不能污染源码树：插件生成的临时 subject snapshot、wrapper scene、运行态工件，都应该落在临时/缓存位置而不是要求把一堆 preview 文件提交进仓库。

## Background

- `v30` 已经证明通用 `ScenePreviewHarness`、wrapper 生成命令、shared subject contract 是可行的。
- 用户对 `v30` 的真实反馈也很明确：
  - 通用机制是对的
  - 但“先生成 wrapper、再去 F6”仍然不够顺手
  - 未来希望在 Godot editor 里直接点一个按钮完成剩余流程
- 当前主仓库还没有正式 `addons/` 插件基建，但参考区 `refs/godot-road-generator/addons/*` 已经证明这个仓库环境完全可以容纳 Godot `EditorPlugin` 方案。
- `v31` 的关键约束不是“能不能在 editor 里加一个按钮”，而是这个按钮不能退化成：
  - 只能预览已保存磁盘版本
  - 仍要求用户给场景手工挂 preview helper
  - 或者在仓库里到处生成临时 wrapper 文件

## Scope

本 PRD 只覆盖 `v31 scene preview editor plugin`。

包含：

- 一个正式 `addons/scene_preview` 插件
- 一个正式的编辑器 preview 按钮入口
- 基于“当前编辑场景”的 preview eligibility 判定
- 基于当前编辑状态的临时 subject snapshot 生成
- 基于 `v30` harness 的临时 wrapper 生成与播放
- 失败场景下的 editor 侧状态提示/禁用态
- 自动化测试、验证文档与使用说明

不包含：

- 不做复杂 dock 面板、截图录屏面板或 profiler dashboard
- 不做 2D/Control 场景一次性全覆盖
- 不做批量扫描整个仓库并列出所有场景的 preview catalog
- 不做 subject 级别的新脚本模板生成器

## Non-Goals

- `v31` 首版不追求多按钮、多模式、多 preset UI；默认先把“一键 preview 当前 3D 场景”做好
- `v31` 首版不要求把 editor plugin 和 `v30` CLI wrapper 生成命令合并成一个巨石类
- `v31` 首版不要求用户先保存场景后才能预览；如果无法支持未保存编辑态，视为需求未满足
- `v31` 首版不追求替代 `v30` 的通用 harness；插件只是入口升级，不是主链替换

## Requirements

### REQ-0021-001 系统必须提供正式的 Godot EditorPlugin 与可见的 preview 按钮入口

**动机**：如果还要命令行接线，用户体验没有完成闭环。

**范围**：

- 新增正式 `addons/scene_preview/plugin.cfg`
- 新增正式 `addons/scene_preview/plugin.gd`
- 在 Godot 编辑器中提供一个明确的 preview 按钮入口
- 按钮应在 3D scene authoring 语境下可见，而不是埋在隐蔽菜单深处

**非目标**：

- 不要求首版同时支持复杂 dock / inspector / 右键菜单三套入口

**验收口径**：

- 自动化测试至少断言：`plugin.cfg` 存在且正式指向插件脚本。
- 自动化测试至少断言：插件脚本能暴露正式的 preview action contract，而不是只有零散 editor callback。
- 反作弊条款：不得只写一个 `@tool` 脚本但没有 `plugin.cfg`；不得只做工具菜单项文案却没有真实执行链路。

### REQ-0021-002 插件必须一键预览当前编辑的 3D 场景，并默认包含未保存编辑态

**动机**：如果按钮只能跑磁盘上的旧 `.tscn`，就不能替代真实调试流程。

**范围**：

- 插件读取当前 `edited scene root`
- 若当前场景是 `Node3D` 主链，可直接进入 preview
- 插件必须把当前编辑状态 materialize 成临时 preview subject snapshot
- 未保存的 transform/属性修改必须进入 preview 结果

**非目标**：

- 首版不要求支持任意 2D/Control scene

**验收口径**：

- 自动化测试至少断言：当前编辑 scene root 可被转换成临时 subject snapshot。
- 自动化测试至少断言：subject snapshot 不依赖手工保存后的原始 scene 文件刷新。
- 反作弊条款：不得把“点按钮 preview”偷换成“强制先保存场景再运行磁盘版本”。

### REQ-0021-003 插件必须复用 v30 preview 主链，而不是复制第二套 preview 舞台

**动机**：不复用 `v30`，未来会出现 editor preview 和 CLI preview 两套行为漂移。

**范围**：

- 插件必须复用：
  - `ScenePreviewHarness.tscn`
  - `ScenePreviewHarness.gd`
  - wrapper 生成服务或其正式等价物
  - optional subject preview contract
- 插件应只负责 editor 入口、eligibility 判定、snapshot/wrapper orchestration

**非目标**：

- 不要求把全部逻辑都塞进 plugin.gd 本体

**验收口径**：

- 自动化测试至少断言：editor preview request 最终引用正式 harness。
- 自动化测试至少断言：支持 subject contract 的真实资产在 editor preview 下仍会启动 preview 行为。
- 反作弊条款：不得在 `addons/scene_preview` 里复制一份独立 preview light/camera/floor 实现。

### REQ-0021-004 插件必须提供明确的 eligibility/失败反馈，并且不污染源码树

**动机**：按钮如果在不支持的场景里乱亮，或者到处生成临时文件，长期会很恶心。

**范围**：

- 当当前场景不可预览时：
  - 按钮必须禁用或给出明确失败原因
- 临时工件必须落在缓存/临时目录
- 不得要求把临时 wrapper / snapshot 文件提交进仓库

**非目标**：

- 不要求首版做完整历史列表或最近预览记录面板

**验收口径**：

- 自动化测试至少断言：eligibility resolver 能区分“无场景 / 非 3D root / 可预览 3D root”。
- 自动化测试至少断言：临时输出路径落在 `user://` 或正式缓存目录，而不是 `res://` 源码树。
- 反作弊条款：不得把 repo 内新增一堆 `*Preview.tscn` 临时文件当作 editor plugin 的默认输出。

### REQ-0021-005 v31 必须保住 v30 与 Missile Command 真实消费链

**动机**：editor plugin 只是入口升级，不能把已建立的 CLI / runtime 资产破坏掉。

**范围**：

- `v30` 的 CLI wrapper 生成命令仍可用
- `InterceptorMissileVisual` 仍能通过 shared contract 被 preview harness 激活
- Missile Command 正式玩法回归不受污染

**非目标**：

- 不要求本轮迁移所有旧 preview 样例到 editor plugin 专属入口

**验收口径**：

- 自动化测试至少断言：`v30` 现有 preview harness / wrapper tests 继续通过。
- 自动化测试至少断言：Missile Command 受影响回归继续通过。
- 反作弊条款：不得为实现 editor button 而回退 `v30` scene-first 主链。

## Success Metrics

- 新建 3D 组件场景后，默认路径变成“打开场景 -> 点 Preview 按钮 -> 观察”
- 不再需要为每个场景单独创建/提交 preview wrapper
- 编辑器里未保存的视觉调整能直接进入 preview

## Open Follow-Ups

- `v32+` 可考虑 2D/Control preview
- `v32+` 可考虑 preview preset / camera preset / screenshot capture
- `v32+` 可考虑 dock 面板与最近预览历史
