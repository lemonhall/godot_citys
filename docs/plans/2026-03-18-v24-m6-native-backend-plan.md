# V24 M6 Native Radio Backend Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 用原生 `GDExtension + C++` 在进程内落下真实 vehicle radio live playback backend，替换当前 `mock backend`，并保持 `B` browser / `O` quick overlay 只作为控制面而不是播放器本体。

**Architecture:** 继续保留现有 GDScript 主链：`CityPrototype.gd -> CityVehicleRadioController.gd -> backend interface`。新建 `city_game/native/radio_backend/*` 原生层，负责网络拉流、解码、重连、元数据与 PCM 输出；GDScript catalog/browser/resolver 只负责目录、选台、lifecycle 与 compact runtime state，不直接解码也不直接参与主线程拉流。

**Tech Stack:** Godot 4.6、GDExtension、godot-cpp、C++17、SCons、MSVC x64、FFmpeg（`libavformat` / `libavcodec` / `libswresample` / `libavutil`，LGPL-only build）、`AudioStreamGeneratorPlayback`、GDScript contract tests + Windows manual sample verification。

---

## 真实现状（2026-03-18）

- 现有 browser/catalog 主链已经不是写死 demo list：
  - `CityRadioCatalogRepository.gd` 已接入 countries index / country station page lazy sync
  - `CityPrototype.gd` 已修到 `B` 可全局开关 browser、`O` 对应 quick overlay、`Esc` / 再按 `B` 可关闭
  - 非 headless 运行时会拒绝测试 fixture 残留的 `China / Japan / Quick2` 假目录/假 session
- 现有 controller / session / quick overlay / browser flow 已能把 `selected_station_id / selected_station_snapshot / power_state / playback_state` 串起来
- **真问题仍然存在**：
  - `CityRadioMockBackend.gd` 仍是当前真实 backend
  - `playback_state=playing` 目前只代表 runtime state，**不代表真的有 live audio decode/output**
  - 还没有任何 in-process native decode path，也没有 direct / playlist / HLS 的真播验证

## 选型冻结

### 硬冻结

- 不允许外部 helper / ffplay / mpv / VLC / 独立进程桥接
- 不允许把 browser UI 生命周期绑回播放链
- 不允许“下载整段文件再播放”去冒充直播电台
- 不允许在主线程做网络阻塞拉流或音频解码

### Native Backend 正式选型

- 原生接入方式：**Godot 4.6 GDExtension + C++**
- 传输/解码库：**FFmpeg**
  - `libavformat`
  - `libavcodec`
  - `libswresample`
  - `libavutil`
- 授权口径：**LGPL-only build**
  - 不开启 `--enable-gpl`
  - 不引入 `libfdk_aac` 之类会抬高授权复杂度的组件
- Godot 音频出口：**`AudioStreamGeneratorPlayback` + 原生 ring buffer**
  - backend 解码线程持续产出 `stereo / 48kHz / float32 PCM`
  - Godot 主线程只做低成本 `push_buffer()` 驱动与状态轮询
- 协议/格式支持：
  - direct `http/https` 音频流
  - 由现有 `CityRadioStreamResolver.gd` 展开的 `PLS / M3U / ASX / XSPF`
  - HLS 最终 URL 交给 FFmpeg input 处理
- 明确排除：
  - `miniaudio` 作为主解码方案
  - `libVLC` / `GStreamer`
  - 任意本地代理/`127.0.0.1` 假设

## Full-Scope Exit Criteria

`M6` 不是“能出一点声音”的最小实现，DoD 直接按完整链路冻结：

1. 点击 browser station row 后，native backend 真正开始拉流/解码/输出，而不只是 runtime state 变成 `playing`
2. `B` 关闭 browser 后，播放继续；quick overlay / browser 都只是 control surface
3. driving 中切台、关机、下车都能稳定停止或切换 native backend，不泄漏线程/句柄/音频播放器
4. direct / playlist-wrapped / HLS 三类样本都能走通正式 backend
5. 出错时必须可解释：
   - connect failed
   - decode failed
   - stream ended
   - unsupported codec
   - reconnecting / retry exhausted
6. backend runtime state 继续通过现有 compact contract 向 GDScript 暴露：
   - `backend_id`
   - `playback_state`
   - `buffer_state`
   - `resolved_url`
   - `metadata`
   - `latency_ms`
   - `underflow_count`
   - `error_code`
   - `error_message`
7. browser / HUD 必须能看到真实 backend 的 buffer / error / metadata，而不是 mock 常量
8. 所有网络 IO 与解码都不占主线程；UI 关闭不会停播；主线程只保留状态轮询与音频出口写入

## Task 1: Native Skeleton And Build Closure

**Files:**
- Create: `city_game/native/radio_backend/SConstruct`
- Create: `city_game/native/radio_backend/radio_backend.gdextension`
- Create: `city_game/native/radio_backend/src/register_types.cpp`
- Create: `city_game/native/radio_backend/src/register_types.h`
- Create: `city_game/native/radio_backend/src/CityRadioNativeBackend.h`
- Create: `city_game/native/radio_backend/src/CityRadioNativeBackend.cpp`
- Create: `city_game/native/radio_backend/src/CityRadioNativeBridge.h`
- Create: `city_game/native/radio_backend/src/CityRadioNativeBridge.cpp`
- Create: `city_game/native/radio_backend/thirdparty/README.md`
- Modify: `docs/plan/v24-index.md`
- Modify: `docs/plan/v24-vehicle-radio-system.md`

**Steps:**
1. 建立 `godot-cpp` / `extension_api.json` / `.gdextension` 最小闭环
2. 先做到 Godot 能加载扩展且 `ClassDB.class_exists("CityRadioNativeBridge")`
3. GDScript 侧先能 `new()` 出 native bridge 并调用 `ping()` 之类的 smoke API
4. 提交一次“扩展可编译、可加载、可实例化”的独立 commit

## Task 2: Backend Interface Replacement Without UI Drift

**Files:**
- Modify: `city_game/world/radio/backend/CityRadioStreamBackend.gd`
- Modify: `city_game/world/radio/backend/CityRadioMockBackend.gd`
- Create: `city_game/world/radio/backend/CityRadioNativeBackend.gd`
- Modify: `city_game/world/radio/CityVehicleRadioController.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Test: `tests/world/test_city_vehicle_radio_backend_interface_contract.gd`
- Test: `tests/world/test_city_vehicle_radio_drive_mode_contract.gd`
- Test: `tests/world/test_city_vehicle_radio_session_recovery_contract.gd`

**Steps:**
1. 保持现有 backend interface contract 不变
2. 新增 `CityRadioNativeBackend.gd`，只做 GDScript <-> GDExtension 薄适配
3. `CityPrototype.gd` 加 capability switch：优先 native backend，失败时明确暴露 `backend_unavailable`
4. controller 不知道 FFmpeg 细节，仍只知道 `play / stop / get_state`
5. 提交一次“native backend 接口替换但 UI/controller 不分叉”的 commit

## Task 3: FFmpeg Transport / Demux / Decode Core

**Files:**
- Modify: `city_game/native/radio_backend/src/CityRadioNativeBackend.h`
- Modify: `city_game/native/radio_backend/src/CityRadioNativeBackend.cpp`
- Create: `city_game/native/radio_backend/src/ffmpeg/CityRadioFfmpegSession.h`
- Create: `city_game/native/radio_backend/src/ffmpeg/CityRadioFfmpegSession.cpp`
- Create: `city_game/native/radio_backend/src/ffmpeg/CityRadioDecodeThread.h`
- Create: `city_game/native/radio_backend/src/ffmpeg/CityRadioDecodeThread.cpp`

**Steps:**
1. 后台线程完成 `avformat_open_input`、stream select、`avcodec_send_packet/receive_frame`
2. 用 `swresample` 统一输出到 `48kHz / stereo / float32`
3. 把 direct、playlist-resolved、HLS 都纳入同一 decode path
4. 记录 `resolved_url / codec / sample_rate / channel_layout / reconnect state`
5. 提交一次“FFmpeg decode core 可跑 sample URL”的 commit

## Task 4: Godot Audio Sink And Ring Buffer

**Files:**
- Modify: `city_game/native/radio_backend/src/CityRadioNativeBridge.h`
- Modify: `city_game/native/radio_backend/src/CityRadioNativeBridge.cpp`
- Modify: `city_game/world/radio/backend/CityRadioNativeBackend.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Test: `tests/world/test_city_vehicle_radio_backend_interface_contract.gd`

**Steps:**
1. backend 自己维护 PCM ring buffer 和 underflow 计数
2. Godot 侧创建 `AudioStreamPlayer` + `AudioStreamGenerator`
3. 主线程只负责把 ring buffer 中的 PCM 推给 `AudioStreamGeneratorPlayback`
4. 关 browser 不会停；停播/下车/切台会主动 drain / reset sink
5. 提交一次“真 PCM 已进入 Godot 音频出口”的 commit

## Task 5: Reconnect / Error / Metadata / Buffer State

**Files:**
- Modify: `city_game/native/radio_backend/src/ffmpeg/CityRadioFfmpegSession.cpp`
- Modify: `city_game/native/radio_backend/src/CityRadioNativeBackend.cpp`
- Modify: `city_game/world/radio/backend/CityRadioNativeBackend.gd`
- Modify: `city_game/ui/CityVehicleRadioBrowser.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Test: `tests/world/test_city_vehicle_radio_backend_interface_contract.gd`
- Test: `tests/e2e/test_city_vehicle_radio_browser_flow.gd`

**Steps:**
1. 支持 reconnect/backoff/abort
2. 统一 `buffer_state`：`idle / connecting / buffering / ready / stalled / error`
3. 读取可用 metadata（如 station name / stream title / codec）
4. browser 详情面与 HUD 直接显示真实 backend 状态
5. 提交一次“错误与缓冲状态正式进入 UI/runtime contract”的 commit

## Task 6: Full Browser-To-Playback Chain

**Files:**
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/ui/CityVehicleRadioBrowser.gd`
- Modify: `city_game/world/radio/CityVehicleRadioController.gd`
- Test: `tests/world/test_city_vehicle_radio_browser_state_contract.gd`
- Test: `tests/world/test_city_vehicle_radio_hud_idle_contract.gd`
- Test: `tests/e2e/test_city_vehicle_radio_browser_flow.gd`
- Test: `tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd`

**Steps:**
1. browser station click 直接进入 native playback，不再只是 mock state
2. quick overlay confirm 同样走 native backend
3. session recovery 恢复真实 selected station，但不在非法状态下偷偷假播
4. browser hidden / quick overlay hidden 时不得触发大列表刷新或全量扫描
5. 提交一次“browser/quick/lifecycle 与 native backend 全链打通”的 commit

## Task 7: Windows Real Sample Verification

**Files:**
- Create: `docs/plan/v24-m6-native-backend-verification-2026-03-18.md`
- Modify: `docs/plan/v24-index.md`

**Steps:**
1. 准备三类真实样本：
   - direct stream
   - playlist-wrapped stream
   - HLS stream
2. 在 Windows 主线环境下记录：
   - open success / first audio latency
   - reconnect behavior
   - stop / switch station behavior
3. 把失败样本与 error_code 一并写回 verification doc
4. 提交一次“native backend Windows 样本验证”commit

## Task 8: M7 Handoff And M8 Gate

**Files:**
- Modify: `docs/plan/v24-index.md`
- Modify: `docs/plan/v24-vehicle-radio-system.md`

**Steps:**
1. 把 `M7` 明确冻结为“全链收口与体验 closeout”，不再让 playback/backend 和 browser/lifecycle 混在一个 milestone 里
2. 把原来的 profiling/verification 收口整体后移到 `M8`
3. `M8` 前置条件：
   - native backend 真播成立
   - browser -> station -> detail -> playback 完整闭环成立
   - direct / playlist / HLS 样本证据已经落文档

## M7 预留范围（冻结）

`M7` 不是新的“最小实现”，而是 `v24` 全链收口：

- browser 详情面显示真实 backend metadata / buffer / error
- favorites / recents / presets / session_state 全部走 native backend 真播链
- driving enter / exit / hijack / power toggle / quick switch 都验证 native backend 行为
- 去掉任何“mock path 看上去像在播”的歧义
- 准备进入 `M8 profiling + regression + closeout`

## Risks

- 最大风险不是 UI，而是 Windows 下 FFmpeg + GDExtension + Godot 音频出口三者的线程边界
- 如果 `AudioStreamGeneratorPlayback` 在持续直播场景下出现明显 underflow 或调度抖动，需要在同一 extension family 内升级为 custom `AudioStream`，但仍不允许外部 helper
- 如果不冻结 LGPL-only build，后续分发会留下授权债
- 如果继续保留 mock backend 为默认路径太久，团队会再次把“状态变成 playing”误判成“真播已完成”
