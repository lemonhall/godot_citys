# V28 Tennis Feedback / Audio Deep Research

## Executive Summary

针对 `v28` 这一版单打网球，额外补的 research 结论很明确：如果只把“合法发球/回球”规则做对，而没有把 `ready / 击球 / 弹地 / 出界 / 得分` 这些关键时刻做成可听、可读、可预判的事件反馈，玩家仍然会把失败感知成“系统没告诉我什么时候该按 E” [1][2][3][4]。

对 `godot_citys` 来说，最值当的增强不是上大体量背景音，而是补一层低成本的事件反馈层：`ready cue`、`point result cue`、`focus message`、`动态 E prompt`，以及轻量但非零的 AI 失误机制，让小游戏既能读懂，也不会陷入“AI 永远不犯错”的死局 [2][3][4][5]。

## Key Findings

- **网球里的音并不只是装饰**：研究显示，球拍触球声会系统性影响玩家对球速和落点的预判；声音不是“附属氛围”，而是 anticipation 的一部分 [2][3]。
- **节奏型击球提示本身就能承载玩法**：`Sonic Tennis` 用拍击声、对手击球声和弹地声驱动节奏同步，说明在网球语境里，事件音本身就足以承担“什么时候该动手”的核心反馈 [1]。
- **可玩性最怕缺 primary cue**：`VI Tennis` 明确区分 primary cues（告诉玩家该做什么、什么时候做）和 secondary cues（强化反馈）；缺少 primary cue 时，玩家不知道何时挥拍，即使球和规则都存在，体验仍然不可玩 [4]。
- **真实网球也把判罚做成显式音频事件**：Hawk-Eye 的电子线审本身就在做“重要事件的清晰声音播报”，说明 `fault / out` 这类事件天然适合做成短促明确的声音反馈，而不是只留在 HUD 文本里 [5]。

## Detailed Analysis

### 1. `ready` 音不是锦上添花，而是接球窗口的确认信号

`Auditory contributions to visual anticipation in tennis` 与后续的 context study 都指出，球拍触球声会改变观察者对球速和落点的估计；尤其在 tennis context 存在时，声音会影响“球会落到哪里”的预判 [2][3]。这意味着对 `v28` 来说，只画一个蓝圈但没有“窗口已开”的强确认，仍然会让玩家在第三人称大场地里凭肉眼猜测时机。

对首版小游戏最有效的做法不是复杂语音播报，而是：

- 当 `strike_window_state` 从 `tracking` 进入 `ready` 时，发一个短促、清晰、带上升感的提示音
- 同时给 HUD 一个短时 focus message，例如“READY，按 E 回球”
- 这个提示必须只在状态边沿触发一次，不能每帧重放

这样玩家会把“现在能打”感知成一个明确事件，而不是持续噪声。

### 2. 结果音应该服务于判罚理解，而不是做热闹

`Sonic Tennis` 把拍击声、对手回击声和弹地声变成核心玩法节拍；`VI Tennis` 则进一步证明，primary cue 的价值在于告诉玩家“刚刚发生了什么，接下来要做什么” [1][4]。对 `v28` 来说，这直接对应：

- `fault / double_fault / out / net / point won / point lost / final`

这些都应当有短小但区分明显的结果音。重点不是拟真，而是状态可分辨：

- `ready`：高频短 beep，强调“现在可击球”
- `good point / player wins point`：较亮的成功音
- `lose point / warning`：更低沉或下行的提示
- `match final`：更完整但仍短的收束音

`Hawk-Eye` 官方资料把 officiating 的 audio solution 直接列为“清晰、准确沟通重要判罚”的能力组成 [5]。因此对 `v28`，把 `out / fault` 做成明确结果音，是贴近网球语义的，不是额外花活。

### 3. 音必须和上下文绑定，不能脱离 court / HUD 语境乱响

2022 年的 context study 一个很重要的结论是：声音对“落点 anticipation”的影响并不是脱离上下文独立成立的；只有当 tennis-specific context 存在时，这类声音才真正帮助判断未来落点 [3]。所以 `v28` 不适合做“无缘无故的 UI 音海洋”，而应做：

- 只有在 tennis runtime 激活且玩家在该场馆链路中时，才启用这组 cue
- `ready` 音只在蓝圈接球链路激活时触发
- `point result` 音只在 point 真正结算时触发
- `focus message` 文案与当下比赛状态一致，而不是固定提示文案

换句话说，音效不能脱离 gameplay state machine 单独存在，它应当是 `match_state / strike_window_state / point_end_reason` 的派生物。

### 4. AI 失误不一定要复杂，但必须存在

这轮用户反馈里最核心的担心之一是：如果 AI 永远合法、永远稳定，而玩家又是单键接球，最后这个游戏会变成“基本必输”。这和 `VI Tennis` 的设计经验是一致的：当输入被压缩后，系统需要通过动态难度、简化 shot family 或辅助 cue 来保持可玩，而不是把 realism 全压给玩家 [4]。

因此对 `v28` 最合理的做法是：

- 前几拍绝对安全，保证回合能建立
- 长回合后引入轻量、确定性的 AI 压力失误
- 失误类型优先做 `out`，不要先做复杂的切削、旋转、擦网
- 玩家侧先保持“安全回球优先”，不要在本轮同时引入大量玩家随机失误

这样做的目的是把小游戏从“AI 无限稳定的考核器”拉回“可玩且可赢的街机化网球”

## Areas of Consensus

- 网球语境里，动作相关声音会影响人对击球质量、球速和落点的判断 [2][3]。
- 高压球类小游戏里，玩家需要明确的 primary cue，告诉他何时该做动作，而不是只在失败后复盘 [1][4]。
- `out / fault` 这类判罚天然适合做成短、清晰、离散的事件播报 [5]。

## Areas of Debate

- **ready 音要不要做得很“拟真”**：研究支持“事件音有效”，但不强制要求一定是真实球场录音；对 `v28` 首版，更重要的是可辨识，而不是高保真采样 [1][4]。
- **玩家侧是否也要引入随机出界**：从 realism 看值得做；但从当前可玩性看，先给 AI 引入轻量失误、玩家保持安全回球更稳妥 [4]。
- **音频是否要空间化**：真实网球当然有空间方向性，但 `v28` 当前更缺的是 state cue；因此首版优先 2D/非空间化提示音，后续再考虑更强的空间音设计 [2][3]。

## Recommended Direction For V28

推荐本轮按以下顺序落地：

1. 在 tennis runtime 暴露 `feedback_event_token / feedback_event_kind / feedback_event_text / feedback_event_tone`
2. HUD 在 token 变化时触发一次 `focus message + short procedural cue`
3. 动态改写共享 `E` 提示文案：
   - `pre_serve` -> `按 E 发球`
   - `ready` -> `按 E 回球`
   - `tracking` -> `跟住蓝圈，等待时机`
4. 给 AI 加入“长回合轻量出界”机制，避免必输感
5. 所有 cue 都必须事件驱动，禁止在 `_process()` 里持续重复播放

## Sources

[1] Baldan, De Götzen, Serafin, “Sonic Tennis: a rhythmic interaction game for mobile devices,” NIME 2013. Audio-only tennis simulation driven by racket hit / opponent hit / bounce cues. https://nime.org/web_archive/2013/program/papers/day2/demo2/288/288_Paper.pdf

[2] Cañal-Bruland et al., “Auditory contributions to visual anticipation in tennis,” Psychology of Sport and Exercise, 2018. Shows louder racket-ball-contact sounds bias estimated trajectory length and anticipation. https://www.sciencedirect.com/science/article/pii/S1469029217307860

[3] Cañal-Bruland, Meyerhoff, Müller, “Context modulates the impact of auditory information on visual anticipation,” Cognitive Research: Principles and Implications, 2022. Shows audio helps landing-location anticipation when tennis context is present. https://link.springer.com/article/10.1186/s41235-022-00425-2

[4] Morelli et al., “VI-Tennis: a vibrotactile/audio exergame for players who are visually impaired,” accessible exergame paper. Distinguishes primary vs secondary cues and emphasizes cue timing/playability tradeoffs. https://www.cs.ucf.edu/courses/cap6121/spr12/readings/vitennis.pdf

[5] Hawk-Eye Innovations, “Officiating.” Official overview of tennis electronic line calling and audio solutions for clear communication of important calls. https://www.hawkeyeinnovations.com/officiating

## Gaps and Further Research

- 还没有专门研究“第三人称大地图角色 + 网球小球”的视认性阈值；后续可单独研究球尺寸、对比色和 motion trail。
- 如果后续加入真实采样音，需要再单独确认版权与素材来源；本轮更适合继续走程序化短音。
- 若要把音效进一步做成空间提示，建议再补一轮“空间化来球音 vs UI 提示音”的设计研究，避免信息冲突。
