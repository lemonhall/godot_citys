# MaxTac Combat Traits Research

## Executive Summary

Cyberpunk 2077 的 MaxTac 更像一支高压、分工明确的精英拦截小队，而不是单一的“会闪避的敌人”。较稳定的可提炼特征是：高机动规避、明确角色分工、中远距离高压制火力，以及在近战/远程/黑客之间形成协同压迫。[1][2][3]

对当前 Godot 原型来说，最适合优先落地的不是整支四人 squad，而是把单个敌人先做成更像 MaxTac 的“Assault Operator”：保留高速规避与近身 orbit，同时补上中距离压制点射。这样实现成本最低，但辨识度提升最大。[1][3]

## Key Findings

- **MaxTac 是按角色分工运作的 SPAR 小队**：2077 版资料明确列出 Assault、Mantis、Heavy、Netrunner、Sniper 等定位，而不是同质敌人海。[1]
- **高机动规避是核心共同点**：资料明确提到 MaxTac 常规使用 Sandevistan Mk.3 与 Kerenzikov，狙击手更频繁使用 Sandevistan。[1]
- **中远距离压制火力是 MaxTac 辨识度的重要来源**：Assault/Heavy 以 Ajax、Defender 等高火力武器形成压制，Sniper 则保持远距威胁。[1][3]
- **近战与黑客只是角色层面的扩展，不应一次性全塞进单原型**：Mantis、Netrunner 是强辨识度角色，但对当前单敌人原型来说，优先级低于“压迫火力 + 机动规避”。[1][2][3]

## Detailed Analysis

### Squad Structure And Threat Model

Cyberpunk Wiki 的 MaxTac 条目把 2077 版 MaxTac 描述为按角色分工运作的 squad，并明确列出 Assault、Mantis、Heavy、Netrunner、Sniper 五类 operator。[1] 这意味着 MaxTac 的压迫感来自“多角色叠加”，而不只是某一项技能数值高。

Gfinity 对 2.0 版 MaxTac operator 的拆解也强化了这一点：Assault 负责高伤害突击，Heavy 用重机枪形成笨重但强力的正面压制，Mantis 以高机动近战突脸，Netrunner 用 Overheat / System Collapse / Cripple Movement 之类的 quickhack 改写战场节奏，Sniper 则远程架枪与投掷手雷。[3]

结论：当前项目如果只做单个敌人，最合理的不是“伪装成完整 squad”，而是从 Assault Operator 开始，预留 role 字段，为后续扩展到 Mantis / Netrunner / Sniper 做接口准备。

### Mobility, Dodge, And Cyberware

Cyberpunk Wiki 明确写到 2077 版 MaxTac 常规使用 Sandevistan Mk.3 与 Kerenzikov，而 Sniper 更显著地依赖 Sandevistan。[1] 这和游戏里玩家对 MaxTac 的直观感受一致：它们不是慢吞吞吃伤害的重兵，而是具备超常规反应速度与位移能力的 elite hunter。

Gamepressure 在 MaxTac miniboss 指南里进一步指出：当 operator 被 stun 之前，它们会“avoid your fire or move quickly to another place”；被暂时击晕后，才会失去这种快速规避能力。[2] 这正好解释了为什么“瞬身闪避”是适合保留在当前原型里的高价值特征。

结论：现有的瞬移/侧闪 dodge 保留是对的；后续不要把它删成普通 strafing AI。更稳的扩展方向，是在 dodge 之外补“火力压迫”，而不是生造一个证据不稳的能力。

### Firepower And Player Pressure

Cyberpunk Wiki 直接给出了 2077 版 MaxTac 的武器组合：Assault 使用 Ajax / Defender，Heavy 使用 Defender，Mantis 有 Omaha 作为近战之外的备武，Sniper 使用 Ashura。[1] 这说明火力压迫不是附加属性，而是角色设计的一部分。

Gfinity 对 Assault/Heavy 的描述也聚焦在高伤害自动武器；Gamepressure 则建议玩家必须利用车辆和墙体做 cover，并特别警惕 Sniper 与 hacker，后者甚至可以 shut V's system down。[2][3] 这些信息共同指向一个稳定结论：MaxTac 战斗体验的关键不是“只会追你”，而是“迫使你持续移动、找掩体、处理中近远多源威胁”。

结论：在当前单敌人版本中，最应该新增的 MaxTac trait 是中距离 burst / suppressive fire。这样玩家终于会被迫处理“规避 + 被点射 + 被压走位”的组合压力。

## Areas of Consensus

- MaxTac 是 Night City 的高等级 elite response force，目标是高强度镇压而不是普通执法。[1]
- 2077 版 MaxTac 不是单模板敌人，而是由多角色 operator 组成的小队。[1][3]
- 其威胁不仅来自高血量，还来自机动规避与高输出火力。[1][2][3]
- 玩家对抗 MaxTac 时必须频繁移动并利用掩体，说明 suppressive fire 是体验核心之一。[2][3]

## Areas of Debate

- **具体人数和角色表述**：Cyberpunk Wiki 列出五类 operator，但同一处文本又写 squad of four，说明“类别总数”和“单次编成数”是两个概念。[1]
- **资料权威性层级**：Fandom/Wiki 与攻略站的整理存在二手转述成分；不过几家在“多角色 + 高机动 + 高压火力”这个结论上基本一致。[1][2][3]
- **是否应加入光学迷彩**：本轮没有找到足够稳的 MaxTac 专属来源支持它作为核心 trait，因此当前不纳入实现范围。

## Implementation Decision

本轮原型决定先做以下两项，不做整支 squad：

1. 给当前敌人补 `role_id = "assault"` 元数据，明确这是 MaxTac Assault Operator 原型。
2. 给 Assault Operator 增加中距离压制点射，让玩家必须持续移动，而不是只盯闪避。

暂缓：

- Netrunner quickhack
- Sniper 远程架枪
- Mantis 近战突刺
- 多敌人 squad 协同

## Sources

[1] Cyberpunk Wiki / Fandom, “MaxTac.” 2026 年 3 月抓取，含 2077 版角色分工、武器与 cyberware 条目。https://cyberpunk.fandom.com/wiki/MaxTac

[2] gamepressure, “Cyberpunk Phantom Liberty: How to defeat the MaxTac Operators?” 2023-10-04，2026 年 3 月抓取。描述了 operator 的快速规避、stun 窗口、掩体与 hacker/sniper 威胁。https://www.gamepressure.com/cyberpunk-2077/maxtac-operators/z510f86

[3] Gfinity Esports, “All new MaxTac types in Cyberpunk 2077 2.0.” 2023-10-09，2026 年 3 月抓取。给出 Assault / Heavy / Mantis / Netrunner / Sniper 的行为定位。https://www.gfinityesports.com/article/cyberpunk-2077-maxtac-types

## Gaps and Further Research

- 后续如果要做完整 MaxTac squad，需要继续补 Netrunner 与 Sniper 的更细颗粒行为证据。
- 若要做“被 stun 后失去高速规避”的机制，需要再查更直接的一手来源，而不是只依赖攻略总结。
