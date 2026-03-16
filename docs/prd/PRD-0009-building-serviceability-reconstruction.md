# PRD-0009 Building Serviceability Reconstruction

## Vision

把 `v15` 冻结下来的 `building_id + generation locator` 真正推进成一条可执行的服务化链路：玩家先用激光指示器锁定一栋楼，在有效 inspection 窗口内按一次小键盘 `+`，系统就异步导出该建筑的独立场景与生成参数 sidecar，并在下一次进入城市或 chunk 重新 mount 时，用同一个 `building_id` 把原 procedural building 替换成可继续编辑的功能建筑场景。

成功标准不是“把一栋楼另存为一个文件”这么简单，而是同时满足四件事：一，导出行为有正式的输入、状态与 Toast 反馈；二，导出的独立场景能稳定重建出同款建筑；三，导出结果能跨 session 持久存在并回到城市里生效；四，整条链继续守住 `v15` inspection、chunk streaming 和 profiling 红线。

## Background

- `PRD-0008` 已经在 `v15` 正式冻结了 `building_id / display_name / generation_locator`，并且 runtime 能按 `building_id` 找回当前 streamed building 的 generation contract。
- 当前仓库仍然没有把单栋建筑导出为独立场景的正式链路，也没有把外部功能建筑场景重新挂回城市的 override registry。
- `CityChunkRenderer` 现有 terrain/surface prepare 已经使用 `Thread` 做后台 CPU 准备，再把结果主线程 commit；`v16` 需要沿用这个“后台 prepare，前台轻 commit”的模式，而不是在主线程里一次性重建/保存整个场景。
- 当前 `CityChunkScene` 的 near building 构建点是正式 mount 链路；这是最自然、最省性能的 override 挂点。

## Scope

本 PRD 只覆盖 `v16 building serviceability reconstruction`。

包含：

- 在有效 building inspection 窗口内，支持小键盘 `+` 触发独立建筑场景导出
- 导出链必须异步启动，并向 HUD Toast 报告 `开始导出 / 重构完成 / 导出失败`
- 系统必须导出：
  - 独立建筑场景 `PackedScene`
  - 原始生成参数 sidecar
  - `building_id -> scene_path` override registry
- 默认优先写入可编辑的源码目录；若当前运行环境无法保存到源码目录，则自动回退到 `user://`
- 下一次进入城市或 chunk 重新 mount 时，系统按 `building_id` 把原 procedural building 替换为导出的功能建筑场景
- 替换必须沿现有 chunk mount 链完成，不得引入 per-frame 全量扫描

不包含：

- 不在 `v16` 内交付独立建筑编辑器 UI
- 不在 `v16` 内交付“当前 session 立即热替换正在显示的楼”
- 不在 `v16` 内交付 mid/far HLOD 级别的功能建筑专用代理
- 不在 `v16` 内交付 NPC/任务/交互组件自动注入

## Non-Goals

- 不追求在 `v16` 内让用户直接在游戏里编辑导出的场景
- 不追求把所有导出资产都变成完整的城市存档系统
- 不追求靠暂停 streaming、冻结世界或跳过 profiling 来换功能完成
- 不追求另起第二套 building identity / routing / marker 栈

## Requirements

### REQ-0009-001 有效 building inspection 必须支持小键盘 `+` 触发一次正式的异步导出请求

**动机**：如果导出只停留在调试命令、编辑器菜单或同步卡顿逻辑里，这条链就不算正式玩法入口。

**范围**：

- 玩家必须先通过 `v15` building inspection 取得正式 `building_id`
- 在 inspection 有效窗口内按小键盘 `+` 才允许触发导出
- 导出请求必须有明确状态：`idle / running / completed / failed`
- 导出开始与结束必须复用现有 HUD Toast
- 同一时刻最多允许一个 building export job 运行

**非目标**：

- 不做连续批量导出模式
- 不做新的菜单页或 modal

**验收口径**：

- 自动化测试至少断言：只有最近一次 inspection 为 `building` 且仍在有效窗口内时，小键盘 `+` 才会启动导出。
- 自动化测试至少断言：导出开始后 runtime 会进入 `running` 状态，结束后进入 `completed` 或 `failed`。
- 自动化测试至少断言：HUD Toast 会显示开始导出与完成/失败结果，而不是只写日志。
- 反作弊条款：不得通过同步阻塞主线程、只打印日志、或 headless-only 特判来宣称完成。

### REQ-0009-002 系统必须把目标建筑重建为独立场景，并保留生成参数 sidecar

**动机**：未来编辑链需要的不只是一个文件路径，还要有原始 generation contract，确保功能建筑有稳定来源。

**范围**：

- 导出产物至少包含：
  - 可加载的 `PackedScene`
  - 包含 `building_id / display_name / generation_locator / source building contract` 的 sidecar
- 独立场景默认要重建出与当前 procedural building 一致的几何/颜色/碰撞主形态
- 独立场景的局部原点必须稳定，可作为未来编辑锚点
- 默认优先保存到 `res://city_game/serviceability/buildings/generated/`
- 若保存到 `res://` 失败，必须自动回退到 `user://serviceability/buildings/generated/`

**非目标**：

- 不要求 sidecar 现在就能覆盖后续所有 NPC/功能模块配置
- 不要求导出产物立即进入 git

**验收口径**：

- 自动化测试至少断言：导出完成后，scene 文件与 sidecar 文件都实际存在。
- 自动化测试至少断言：导出的 scene 能被 `PackedScene` 再次加载并实例化。
- 自动化测试至少断言：sidecar 保留非空 `building_id` 与原始 `generation_locator`。
- 自动化测试至少断言：导出的 scene 初始形态仍然含有同款 building shell，而不是空场景。
- 反作弊条款：不得通过只生成空目录、空 scene、空 manifest 或把 contract 写死在测试里来宣称完成。

### REQ-0009-003 系统必须在下一次城市进入或 chunk 重新 mount 时，用稳定锚点替换原 procedural building

**动机**：导出链真正有价值的前提，是回到城市时它能重新接管原建筑的位置与身份。

**范围**：

- registry 的正式 key 为 `building_id`
- registry entry 至少包含 `building_id / scene_path / manifest_path`
- chunk mount 时，若当前 building 有 registry entry，则 near building 走 override scene instantiate
- override scene 必须复用原 building 的稳定锚点与 yaw
- 替换逻辑必须收敛在 mount / rebuild 事件链，不允许每帧全量查 registry

**非目标**：

- 不要求当前已经显示在屏幕上的楼即时热替换
- 不要求 mid/far proxy 现在就长出功能建筑专用外观

**验收口径**：

- 自动化测试至少断言：同一 registry 路径下，第二次 world session 能加载到先前导出的 override entry。
- 自动化测试至少断言：目标 `building_id` 在 next session 的 near chunk mount 里会实例化 override scene，而不是继续走 procedural root。
- 自动化测试至少断言：override 实例保留原 building 的稳定锚点与朝向。
- 自动化测试至少断言：没有 override entry 的建筑仍走原 procedural contract。
- 反作弊条款：不得通过每帧扫描整城 buildings、强制 remount 全部 chunk、或开第二套隐藏 building graph 来宣称完成。

### REQ-0009-004 `v16` 不得破坏现有 v15 inspection、streaming 与性能红线

**动机**：这是服务化扩展，不是允许回退现有主链的豁免令。

**范围**：

- `v15` 激光 inspection / HUD / clipboard contract 继续成立
- 新增 export/override contract tests 与至少一条 e2e flow
- profiling 三件套仍需串行通过

**非目标**：

- 不要求 `v16` 重写整套 chunk renderer
- 不要求 `v16` 现在就新增功能建筑专属 HLOD

**验收口径**：

- 受影响的 `v15` world/e2e tests 必须继续通过。
- 新增 `v16` world/e2e tests 必须通过。
- 串行运行 `test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 仍需过线。
- 反作弊条款：不得通过 profiling 时禁用 override 查找、跳过 scene save、或关闭 HUD Toast 来宣称达标。

## Open Questions

- `v16` 是否要求当前 session 导出完成后立刻把眼前这栋楼热替换。当前答案：不做，保持“下次进城或 remount 生效”的硬边界。
- `v16` 是否要求 mid/far HLOD 立即显示功能建筑外观。当前答案：不做，near mount 替换优先。
