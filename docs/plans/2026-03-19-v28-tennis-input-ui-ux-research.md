# V28 Tennis Input / UI / UX Deep Research

## Executive Summary

针对主机与 PC 网球游戏的交互研究显示，成熟作品几乎都不会把玩家击球直接暴露成“朝摄像机前方施加一个裸物理冲量”。它们普遍采用“合法 shot family + timing + 适度自动跑位/预判 + 可读的落点/风险提示”的组合：输入先表达击球意图，再由规则与物理共同决定结果 [1][4][5][6]。

对 `godot_citys v28` 来说，这意味着当前 `按 E -> 球立刻按通用 impulse 飞走` 的方案方向就错了。要让网球 playable，玩家发球和接球都必须进入 tennis runtime 的规则层：发球默认被约束到对角合法 service box；回球默认被约束到对方半场的可达落点；同时通过自动跑位、落点预判、击球窗口与击球质量反馈降低“看见球但接不住”的挫败感 [1][2][3][5][6][7]。

## Key Findings

- **主流网球游戏先表达击球意图，再交给物理求解**：TopSpin 2K25 用 Timing Meter 把“何时放键”变成核心；AO Tennis 2 用 press-and-hold 蓄力并配合时机点颜色反馈；Tennis Elbow 4 则明确规定“不输入方向就打向对方场地中央” [1][4][5]。
- **接发/接球普遍依赖辅助预判，而不是完全裸手动**：Tennis Elbow 4 提供 Service Preview、Danger Zone、AutoPos；Mario Tennis Aces 在 Swing Mode 里直接自动朝球移动，并允许取消蓄力和用慢动作应对难球 [5][6][7]。
- **风险回报必须被明确可视化**：TopSpin 2K25 的 patch notes 明确把 wide serve、低体力长回合、flat power 的失误风险与 timing 窗口挂钩；AO Tennis 2 也用绿色/橙色/红色时机反馈让玩家知道是 timing 问题，不是“游戏乱飞” [2][3][4]。
- **对新手友好的 tennis UX 通常允许“物理真实，但输入被规则纠偏”**：Tennis Elbow 4 甚至提供 Arcade mode、Footwork Boost、CPU serve speed 降速与自动回位建议；Nintendo 也持续调返球距离、trick shot 消耗与球可见性 [5][7]。

## Detailed Analysis

### 1. 发球交互：不能是“按 E 往前打一拳”

TopSpin 2K25 把发球做成显式的 risk-vs-reward 系统：官方 gameplay report 强调 Timing Meter 是击球准确度核心，而 2024-07 patch 又进一步把 wide serve、perfect timing 窗口与站位限制绑定起来，说明“发球”在现代网球游戏里不是一个泛化击球动作，而是一种被单独约束、单独反馈的输入流程 [1][2]。AO Tennis 2 也不是把按键直接映射成物理冲量；它要求先走 press-and-hold 蓄力，再根据释放时机给出绿/橙/红反馈 [4]。

对 `v28` 的直接启示是：

- `pre_serve` 状态下，`E` 不该触发通用 interactive prop impulse。
- 玩家先进入“发球准备”，然后由 runtime 把 shot target 约束在“合法对角 service box”。
- 没有额外方向输入时，默认瞄准对角 service box 的安全中心，而不是让球朝玩家朝向裸飞。
- 如果后续要加入风险层，应该是：
  - `E` = 安全/控制发球
  - 长按 `E` 或第二输入 = 更快但更冒险的发球
  - 风险体现为落点散布变宽、过网高度更吃 timing，而不是“无规则地直接飞出界”

换句话说，`v28` 首要修复不是“把 impulse 调小一点”，而是把玩家发球从 generic prop interaction 升级为 `tennis-legal serve planner`。

### 2. 接球 UX：必须给预判、跑位和击球窗口

Tennis Elbow 4 的文档把“接发球为什么难”说得很直接：反应时间太少，所以需要 Service Preview、Danger Zone、AutoPos，甚至建议玩家在发球前预按击球键，让系统先帮角色朝正确方向缓慢启动 [5]。Mario Tennis Aces 则在 Swing Mode 下直接自动向球移动，同时用可取消蓄力、Trick Shot、Zone Speed 这些机制，把“我眼睛看到了但手来不及”变成“系统给我一个能追上的解法” [6][7][8]。

这说明 `v28` 不能只修 AI 回球逻辑，还得给玩家一套“可读、可追、可接”的 UX。至少应该包含：

- **落点预判**：
  - AI 已回球后，在玩家半场显示一个早期落点 marker
  - 落点 marker 需要随来球速度/旋转风险变化，至少分出“安全窗”和“危险窗”
- **自动跑位**：
  - 玩家进入 tennis 活动半径且球来向自己时，自动朝“理想击球槽位”收拢
  - 不是全自动接球，而是降低最后 1-2 米对位成本
- **击球窗口**：
  - 只有在“可合法击球窗口”里，`E` 才会出手
  - 过早/过晚应给出明确 HUD 提示，而不是让球乱飞后由玩家自己猜
- **默认安全回球**：
  - 无方向输入时，回向对方半场的安全中深区
  - 有方向输入时，再做左右偏移/更激进落点

主流作品的共同点不是把辅助做没，而是把辅助做成“你仍在打球，但系统帮你先站到能打球的位置” [5][6][7]。

### 3. 风险、容错与反馈：玩家要知道自己为什么失误

TopSpin 2K25 在官方说明里持续强调 timing、stamina 与 shot risk 的耦合：长回合和低 Rally Energy 会让 Timing Meter 更难卡、Flat Power 更容易失误，而 volley 在慢来球时又会更容易上手 [1][3]。AO Tennis 2 直接把时机好坏染成绿/橙/红；Tennis Elbow 4 也用 Danger Zone、Aiming Zone 与 off-center hit 指示告诉玩家：是站位不好、准备太晚，还是危险来球导致失误 [4][5]。

这对 `v28` 很关键。当前用户感知到的是：“我按了 E，但我不知道为什么它往外飞。” 这类体验本质上不是单纯难，而是反馈缺失。要修成可玩版，建议最少补四类反馈：

- **Serve legality feedback**：当前发球目标是否合法，是否在对角 service box
- **Strike quality feedback**：`perfect / early / late / off-center`
- **Incoming ball readability**：玩家半场落点 marker + 可选危险圈
- **Result feedback**：`fault / double fault / net / out / good return`

这样一来，即便仍然保留物理误差，玩家也会把失败归因为“我 timing 晚了”或“我没站进击球窗”，而不是“系统乱给我一个冲量”。

### 4. 主机/PC 常见输入模式，适合 `v28` 的是哪一种

综合 TopSpin、AO Tennis、Tennis Elbow 与 Mario Tennis，可以把主流交互大致分成三类：

1. **Timing-first realism**
   代表：TopSpin 2K25、Tennis Elbow 4  
   特征：时机、站位、击球类型决定结果；有辅助，但不把规则拿掉 [1][5]

2. **Press-and-hold accessible simulation**
   代表：AO Tennis 2  
   特征：蓄力 + 时机反馈 + 相对直接的 shot map，容易理解 [4]

3. **Arcade assist / spectacle tennis**
   代表：Mario Tennis Aces  
   特征：自动靠球、慢动作、防守特技、极高可读性 [6][8]

对 `godot_citys v28`，最合适的不是照搬其中单一一类，而是做一个 **“realistic-arcade hybrid”**：

- 规则层遵循真实网球：
  - 对角发球
  - 过网
  - 单次 bounce
  - in/out
- 输入层借鉴街机/易上手设计：
  - 自动收拢跑位
  - 默认安全目标
  - 落点 marker
  - 清晰 timing 反馈

这和用户当前反馈完全一致：不是不要物理，而是“要让规则先约束输入，再让物理在规则里发挥”。

### 5. 对 `v28` 的直接设计建议

基于以上研究，建议把当前 `v28` 立刻改成下面这条 UX 主链：

#### Serve

- 进入 `pre_serve` 后，球自动吸附到 server anchor
- HUD 显示：
  - `server_side`
  - `expected_service_box`
  - `serve_target_marker`
  - `timing_window`
- `E`：
  - 若未开始蓄力：开始蓄力
  - 若在击球窗：按“安全控制发球”出手，默认打向对角 service box 中心
- 可选方向输入：
  - 只做 service box 内的左右偏移，不允许偏到非法区

#### Receive / Rally

- AI 击球后：
  - 立即在玩家半场生成 early landing marker
  - 玩家自动向理想击球点轻度收拢
- 玩家 `E`：
  - 在合法击球窗内，触发 tennis runtime 规划回球
  - 默认回到对方场地安全中深区
  - 有方向输入才做侧向偏移
- 如果没赶上：
  - 给出 `late / bad position / danger zone` 明确理由

#### Difficulty / Assist

- `v28` 首版建议默认开启：
  - `auto_footwork_assist = medium`
  - `serve_preview = on`
  - `return_landing_marker = on`
  - `default_shot_family = control`
- 以后再考虑做更硬核模式

## Areas of Consensus

- 主流网球游戏不会把击球做成完全裸物理输入；都会加 shot family、timing 或 charge 语义 [1][4][5]。
- 接发球/接球体验如果没有预判辅助，很容易让玩家觉得“不可能接得到”，所以通常会补 auto-positioning、落点预判或时间缓冲 [5][6][7]。
- 风险必须被可视化；宽角度发球、强力击球、长回合疲劳，都会被映射到更严格的 timing 或更大的失误散布 [1][2][3][5]。

## Areas of Debate

- **辅助量该多大**：Tennis Elbow 4 这种偏 simulation 的作品倾向提供可选辅助，而 Mario Tennis Aces 明显更主动地帮玩家追球和处理高压回球 [5][6]。
- **默认 shot 是否应该强约束到合法落点**：更硬核的作品允许你自己失误；更偏街机/主机向的作品往往先帮你守住合法基线，再把风险放到更激进输入上 [1][4][6]。
- **是否需要慢动作/Zone Speed 级别的超能力辅助**：Nintendo 明显接受这种表达；写实系更常用的是 preview、timing meter 和站位辅助 [5][6][8]。

## Recommended Direction For V28

推荐方案：**规则约束下的上下文击球 + 中等自动跑位辅助**

原因：

- 它最符合用户当前反馈：你不是要一个“更真实的乱弹球”，而是要一个“我能看懂、追得上、接得住”的网球交互。
- 它能保住已有物理系统，不需要把网球退回成完全脚本动画。
- 它也能沿 `scene_interactive_prop + tennis runtime` 主链继续扩展，而不是把所有逻辑塞回通用球 prop。

具体落地优先级建议：

1. 把玩家 `E` 击球从 `TennisBallProp.gd` 的裸 impulse 升级为 `CityTennisVenueRuntime.gd` 的合法 shot planner  
2. 给 `pre_serve` 加对角 service box 目标 marker 与合法性约束  
3. 给 AI 回球加玩家半场落点 marker + auto-footwork assist  
4. 给 HUD 加击球时机/结果反馈  
5. 按用户反馈把场地整体抬高并放大到更适合第三人称城市角色的 arcade 尺度

## Sources

[1] 2K, “Centre Court Report - Gameplay | TopSpin 2K25,” official gameplay article. Emphasizes Timing Meter, improved serves, and rally control. https://topspin.2k.com/en-GB/2k25/centre-court-report/gameplay/  

[2] 2K Support, “TopSpin 2K25: Patch Update - July 15, 2024,” official patch notes. Documents wider-serve risk, tighter perfect-serve timing, reduced pre-serve lateral drift, and return-of-serve animation changes. https://support.2k.com/hc/en-us/articles/31140636748563-TopSpin-2K25-Patch-Update-July-15-2024  

[3] 2K Support, “TopSpin 2K25: Patch Update - December 9, 2024,” official patch notes. Documents timing-meter difficulty tied to long rallies and low rally energy, plus easier volley timing on slower incoming balls. https://support.2k.com/hc/en-us/articles/36285067828115-TopSpin-2K25-Patch-Update-December-9-2024  

[4] Big Ant Support, “AO Tennis 2 Controls Guide for Nintendo Switch,” official support article. Describes press-and-hold shot building, release timing, and green/orange/red timing feedback. https://support.bigant.com/support/solutions/articles/48001143097-ao-tennis-2-controls-guide-for-nintendo-switch  

[5] Mana Games, “Tennis Elbow 4 - Documentation,” official game documentation. Covers AutoPos, Footwork Boost, aiming rules, Danger Zone, service preview, and return-of-serve guidance. https://www.managames.com/tennis/doc/Tennis_Elbow-Tennis_Game.html  

[6] Play Nintendo, “5 Essential Mario Tennis Aces Tips,” official Nintendo tips article. Covers charge shots, cancelable charge, trick shots, slow-motion defense, timing-based pull/push shots, and auto-move toward the ball in Swing Mode. https://play.nintendo.com/news-tips/tips-tricks/mario-tennis-aces-tips-tricks/  

[7] Nintendo Support, “How to Update Mario Tennis Aces / update history,” official support log. Shows Nintendo shipping balance changes for return distance, trick-shot cost, ball visibility, and AI behavior. https://en-americas-support.nintendo.com/app/answers/detail/a_id/29137/  

[8] Nintendo, “Mario Tennis Aces for Nintendo Switch,” official store page. Describes Zone Speed, Zone Shot, simple motion controls, and control-mastery framing. https://www.nintendo.com/us/store/products/mario-tennis-aces-switch/  

## Gaps and Further Research

- 还可以继续补一轮“现代第三人称运动小游戏”的横向研究，特别是非网球但同样依赖接球预判的游戏，例如棒球/羽毛球/排球中的落点提示设计。
- 如果后续要给 `v28` 做手柄适配，最好再补一轮“主机版手柄键位 vs PC 键鼠键位”的映射研究。
- 若未来要做更硬核模式，可再研究 TopSpin Academy / Tennis School 一类教程设计，把辅助从“默认打开”变成“可训练后逐步关闭”。
