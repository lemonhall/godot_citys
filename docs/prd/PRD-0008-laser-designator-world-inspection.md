# PRD-0008 Laser Designator World Inspection

## Vision

把 `godot_citys` 从“玩家只有自动步枪和手榴弹两种直接伤害武器”推进到“玩家能切换一个非伤害型的激光指示器，对着建筑或地面做世界语义采样”的状态。成功标准不是再做一把会造成爆炸或伤害的武器，而是让现有 `v12` 地址语义、chunk streaming contract 和 HUD 主链，长出一条最小但完整的 `切换 -> 激光点选 -> 世界解析 -> 屏幕提示 -> 复制结果 -> 自动消失` 玩法闭环。

本 PRD 的核心价值不是新增 combat DPS，而是建立一条正式的 `building identity` 主链：玩家点中建筑后，不只看到地址，还能拿到唯一建筑名字与 `building_id`，让这条 inspection 结果以后能继续服务于“按唯一建筑 ID 找生成参数 -> 独立场景重建 -> 编辑功能/NPC -> 下次进城替换原建筑”的后续能力。

## Background

- `PRD-0004` 已完成 `rifle / grenade / hijack / driving` 的基本武器与载具交互链。
- `PRD-0006` 已完成 canonical road name、地址语法、`place_query / resolved_target` 与地图导航主链。
- 当前近景建筑 collider 仍然只是渲染/碰撞载体，没有正式暴露给玩家的“命中即显示地址/唯一身份”交互层。
- 当前 HUD 已有 crosshair 与 debug/status 区，但没有正式的短时提示条。
- 当前没有正式冻结的建筑替换锚点；`v15` 需要先把唯一建筑 identity contract 立起来。

## Scope

本 PRD 只覆盖 `v15 laser designator world inspection`。

包含：

- 新增第三种武器 `laser designator`
- 玩家按 `0` 切换到激光指示器
- 左键触发一次绿色激光束
- 激光命中近景建筑时，屏幕显示该建筑的唯一建筑名字
- 建筑 inspection payload 暴露正式 `building_id`
- 激光命中地面/道路/桥面等静态表面时，屏幕显示 chunk 信息
- 每次 inspection 结果复制到 Windows 剪贴板
- 在 `10` 秒消息窗口内再次点选时，HUD 与剪贴板都必须立即刷新为最新结果
- HUD、tests、verification artifacts 暴露正式 inspection contract

不包含：

- 不做激光伤害、爆炸、导航锁定、空袭标记或 AI 联动
- 不做中文地址本地化重写；显示文本默认复用现有 `v12` address grammar
- 不做独立的 scan mode UI 页面
- 不在 `v15` 内完成“持久化 city JSON / 功能建筑替换 / 独立场景编辑器”整条后续产品链

## Non-Goals

- 不追求 `v15` 立刻完成完整的功能建筑替换系统
- 不追求让行人、车辆、敌人也产生命中说明文本
- 不追求把 debug HUD 文本直接包装成“已完成交互提示”
- 不追求通过关闭现有 crosshair/HUD 或减少 building count 来换功能完成

## Future Serviceability

`v15` 的建筑 identity contract 必须直接为以下未来链路服务：

1. 用户告诉系统某个建筑的唯一地址/唯一名字或 `building_id`
2. 系统按该 `building_id` 找回该建筑的生成参数
3. 系统按这些参数把建筑重建到独立场景
4. 用户在该独立场景里继续建设、加 NPC、加功能
5. 用户再次进入城市时，系统以稳定锚点把原生成建筑替换为功能建筑场景

`v15` 不要求现在就交付这 5 步，但必须把 `building_id + generation locator` 作为正式后续锚点冻结下来。

## Requirements

### REQ-0008-001 系统必须支持 `laser designator` 武器模式与绿色激光发射

**动机**：没有正式武器模式、输入口径与可见激光束，就不存在可验证的玩家交互入口。

**范围**：

- 玩家可通过 `0` 切换到 `laser designator`
- `laser designator` 左键触发一次绿色激光束
- `laser designator` 不得继续发射 rifle projectile 或 grenade
- `laser designator` 允许继续复用现有 crosshair / ADS 口径

**非目标**：

- 不做持续按住的激光持续照射模式
- 不做独立 ammo、热量或冷却系统

**验收口径**：

- 自动化测试至少断言：玩家可切换到正式 `laser designator` 模式。
- 自动化测试至少断言：`laser designator` 模式下左键不会继续生成 projectile 或 grenade。
- 自动化测试至少断言：每次触发都会生成一次可见绿色激光束或等价 beam state。
- 反作弊条款：不得通过只改 HUD 文案、不产生 beam、或继续复用 bullet/grenade 节点来宣称完成。

### REQ-0008-002 激光命中建筑时必须显示唯一建筑名字，并暴露正式 `building_id`

**动机**：用户要的是“点建筑就能读到这栋楼的唯一身份”，而不只是一个随便拼出来的 inspection label。

**范围**：

- 近景建筑 collider 必须暴露正式 inspection payload
- payload 至少包含 `building_id / display_name / address_label / place_id / chunk_id / chunk_key`
- `display_name` 冻结为用户可见的唯一建筑名字；默认基于 `v12` 地址 grammar 再拼接稳定 building code
- `building_id` 冻结为 deterministic building identity，后续可作为建筑替换锚点
- payload 必须保留足够的 generation locator，供未来按 `building_id` 找回生成参数

**非目标**：

- 不要求一栋 visual building 对应现实级官方门牌登记
- 不要求 `v15` 就做完整的 persistent city JSON registry UI

**验收口径**：

- 自动化测试至少断言：激光命中建筑时返回 `building` inspection kind。
- 自动化测试至少断言：building inspection payload 暴露非空 `building_id` 与唯一 `display_name`。
- 自动化测试至少断言：在当前 mounted city window 内，`building_id` 与 `display_name` 都不允许重复。
- 自动化测试至少断言：相同 seed 下同一 sample building 的 `building_id` 与 inspection 文本稳定。
- 自动化测试至少断言：可通过 `building_id` 反查到当前 streamed building 的 generation contract。
- 反作弊条款：不得通过给所有建筑显示同一个假地址、只显示技术 node name、或把地址写死在测试里来宣称完成。

### REQ-0008-003 激光 inspection 必须刷新 HUD/剪贴板，地面命中显示 chunk 信息，并在 `10` 秒后自动消失

**动机**：inspection 结果不仅要可见，还要能连续点、连续更新、连续复制，方便后续外部记录与设计工作流。

**范围**：

- 激光命中地面、道路、桥面等静态表面时，显示 chunk 信息
- chunk 提示至少包含 `chunk_id` 与 `chunk_key`
- 提示必须是正式 HUD 短时消息，而不是只写进 debug overlay
- 每次 inspection 结果都要复制到 Windows 剪贴板
- 在 `10` 秒消息窗口内再次点选时，HUD 与剪贴板必须立刻替换为最新结果
- 消息存活 `10` 秒后自动清除

**非目标**：

- 不做消息历史面板
- 不做多条 inspection 消息并排堆叠

**验收口径**：

- 自动化测试至少断言：激光命中静态地面时返回 `chunk` inspection kind。
- 自动化测试至少断言：HUD 会显示 chunk message，而不是只更新内部状态不出现在屏幕层。
- 自动化测试至少断言：第二次 inspection 会立即替换第一次 HUD/clipboard 结果，而不是锁死 `10` 秒。
- 自动化测试至少断言：建筑 inspection 的 clipboard 文本包含 `building_id`。
- 自动化测试至少断言：消息在 `10` 秒后自动清空。
- 反作弊条款：不得通过永久常驻文本、只在 debug expanded 时可见、或只打印日志来宣称完成。

### REQ-0008-004 `v15` 不得破坏现有 combat / HUD / streaming / performance contract

**动机**：这是一个玩家可见交互功能，但不能以回退现有 combat、HUD 或 chunk runtime 为代价。

**范围**：

- 现有 rifle / grenade / ADS / crosshair contract 继续成立
- building collider 与 chunk payload 扩展必须保持 deterministic
- HUD 新增消息层后，性能三件套仍需通过

**非目标**：

- 不要求 `v15` 重写整套 HUD
- 不要求 `v15` 重新规划 chunk profile signature 体系

**验收口径**：

- 受影响 combat / HUD tests 必须继续通过。
- 新增 inspection tests 与至少一条 e2e flow 必须通过。
- 串行运行 `test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 仍需过线。
- 反作弊条款：不得通过 profiling 时关闭 beam、关闭 HUD 消息、或做 headless-only 特判来宣称达标。

## Open Questions

- `v15` 是否需要把地址显示改成中文“路名 + 门牌号 + 号”的本地化顺序。当前答案：不做，继续复用现有 `v12` address grammar。
- `v15` 是否需要把激光指示器接进任务/导航主链。当前答案：不需要，只做 inspection。
