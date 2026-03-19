# V29 Missile Command Research

日期：2026-03-20

## 目标

为 `godot_citys` 的 `v29` 新小游戏确定一个足够稳定的规则基线，避免后续把玩法做成“只是会往天上发射几颗球”的伪实现。

## 原版关键规则抽取

从经典 `Missile Command` 的公开玩法描述里，可以稳定提炼出五个不可丢的核心：

1. 玩家防守的是地面目标，而不是单纯比击落数。
2. 敌方弹头从高处落向城市或发射基地，威胁是持续、成波次出现的。
3. 玩家从被选中的发射基地向指定落点发射拦截弹，不是自动锁敌。
4. 拦截弹到达目标点后会形成可持续一小段时间的爆炸圈；敌方弹头进入爆炸圈会被摧毁，形成“链式清场”。
5. 地面城市与发射基地会被消耗；如果城市全部被毁，游戏失败。

对 `godot_citys` 来说，最重要的不是一比一复刻原街机 UI，而是保住这条玩法骨架：

- `defense targets`
- `enemy waves`
- `selected launch silo`
- `aimed interception`
- `explosion radius chain kill`
- `lose condition tied to defended ground assets`

## 适配到当前项目后的实现判断

### 不选的路线

1. 不做“第三人称人物拿火箭筒往天上打”的自由射击版。
   - 这会把玩法退化成普通 TPS 打靶，丢掉 `selected silo + target-point interception + explosion cloud` 的核心。

2. 不做“打开二维全屏界面、直接点地图”的纯 UI 版。
   - 这会脱离现有 `scene_minigame_venue` authored 世界主链，用户指定的 chunk 落点价值也会被削弱。

3. 不做“继续靠 E 键对着某个物体反复触发”的交互版。
   - 用户已经明确指出这轮不能单靠 `E`；而且 `Missile Command` 的核心是持续瞄准与连发，不是单点交互。

### 推荐路线

做成 **scene_minigame_venue + 固定防空玩法平面 + 玩法态切换**：

- 玩家走进开赛圈后自动进入炮台防空态。
- 玩法期间禁用人物移动，切到场馆自带 camera。
- 鼠标负责旋转准星/视角，左键向准星落点发射拦截弹。
- 右键只做 zoom，不承担攻击语义。
- `Q` 轮换发射井。
- `Esc` 退出玩法态，回到第三人称步行。

## 场景与逻辑分工

遵循 `godot-minigame-scene-first-authoring`：

- 场景负责：
  - 防空平台
  - 三个发射井锚点
  - 三个被保护城市锚点
  - 开赛圈
  - 摄像机 pivot / camera
  - 游戏平面 anchor
  - 记分牌与调优用锚点
- 运行时负责：
  - 波次脚本
  - 敌方弹头生成与落点选择
  - 选井、发射、飞行、爆炸、链式击毁
  - 城市/发射井毁伤状态
  - HUD / 焦点提示 / 玩法态切换

## v29 首版冻结建议

- 场馆 ID：`venue:v29:missile_command_battery:chunk_183_152`
- 位置锚点：`chunk_183_152 / world=(11925.63, -4.74, 4126.84)`
- 首版固定为 `3 silos + 3 cities`
- 首版固定为 `auto-enter battery mode when inside start ring`
- 首版固定为 `3 waves`
- 首版固定为 `left-click fire / right-click zoom / Q cycle silo / Esc exit`
- 首版允许 deterministic wave script，不追求复杂随机弹型
- 首版不做 task 集成、排行榜、音效大系统、BGM 切换

## 结论

`v29` 最稳的实现不是“新武器”，而是“新的 scene_minigame_venue family consumer”。玩法应冻结成：

**在用户指定 chunk 上 author 一个三维防空电池场馆；玩家进入开赛圈后切换到固定炮台视角，用左键向准星落点发射拦截弹，靠爆炸圈保护城市与发射井，完成多波次防御。**
