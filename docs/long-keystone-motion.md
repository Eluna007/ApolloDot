# Long 灵动岛动画调节

适用于 long 样式通用面板（媒体、Hub、歌词、工具、提示）的外壳展开与收起。
录屏、录音的内容仍有自己的呈现流程。pill、bangs 和音源徽标动画不使用这组参数。

## 统一时间轴

入口为 `Modules/Keystone/Styles/Long/LongIslandFrame.qml`。
`progress` 是唯一的几何动画进度：收起目标为 0，peak 目标为 `peekStop`，完整展开目标为 1。
鼠标离开、中途点击或反向操作，均从当前进度转向新目标，不重新生成一套姿态。

默认的展开阶段：

1. **0–0.18：水面鼓起。** 仅变形主体的内侧边缘，正文隐藏。peak 在此停住。
2. **0.18–0.66：面板出水。** 圆角面板从鼓包下方长出；其水面以上的部分被裁掉。
3. **0.50–0.76：接触面拉成细颈。** 面板离开主体，基础间距增加至 24 px。
4. **0.66–0.76：正文显现。** 面板已达到最终尺寸、离开主体，封面与正文才一起淡入；同时开始越位回弹。
5. **0.86–1：附着断开并落稳。** 细颈从中央变细、断开，两端退回各自表面；面板回到最终位置。

收起沿同一套几何关系反向经过这些阶段，速度更快。正文先隐藏，再将面板吸回水面。
peak 探出、peak 收回、面板展开和收起分别使用非线性 Bézier 曲线；几何阶段再经过 smoothStep。
面板成形后，沿出水方向额外越位最多 8 px，然后回到 24 px 的静止间距。
回弹只作用于共享位置，不让 `progress` 超出 0–1，也不缩放正文或倒放淡入、断颈阶段。
收起反向经过同一位置曲线，因此中途切换方向不产生位置跳变。

## 可调参数

以下集中在 `LongIslandFrame.qml` 顶部。长度为逻辑像素，时间为毫秒。

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `thickness` | 42 | 主体厚度，也确定水面位置 |
| `gap` | 24 | 最终面板与主体的间距 |
| `peekWidth` | 240 | 鼓包接回水平面的总宽度 |
| `peekDepth` | 10 | 鼓包中心向屏幕内侧探出的高度 |
| `peekDuration` | 200 | 从收起到完整 peak 或反向的时间 |
| `openDuration` | 720 | 从完全收起到完全展开的时间 |
| `closeDuration` | 420 | 从完全展开到完全收起的时间 |
| `reboundDistance` | 8 | 面板出水后的最大越位距离；设为 0 可关闭回弹 |
| `peekStop` | 0.18 | 鼓包达到最大高度、面板开始出水的进度 |
| `emergenceEnd` | 0.66 | 面板达到最终尺寸、正文开始淡入的进度 |
| `separationStart` | 0.50 | 面板开始离开水面的进度 |
| `separationEnd` | 0.76 | 基础间距到位、正文完全显示的进度 |
| `releaseStart` | 0.86 | 细颈开始断开的进度；增大可延长完整出水后的粘连 |
| `shoulderRadius` | 16 | 出水时面板两侧与水面相交处的融合半径 |
| `neckWidth` | 48 | 接触面收窄后的颈部根宽，腰部会更细 |
| `panelRadius` | 24 | 面板圆角，自动受当前宽高限制 |
| `seedWidth` | 64 | 面板开始出水时沿条栏方向的初始宽度 |
| `seedDepth` | 18 | 初始面板埋在水面内的深度，也参与断开时的收缩 |

中途改变目标时，时长按剩余进度比例缩短；例如从 peak 展开只需约 590 ms。
保持 `0 < peekStop < separationStart < emergenceEnd < separationEnd <= releaseStart < 1`，
确保正文显现之前面板已经成形，并留出完全出水后保持粘连的阶段。
设置中心的悬停打开/关闭延迟是动画开始前的等待，不属于上述时长。

四条时间曲线也集中在文件顶部（Qt 的 `[x1, y1, x2, y2, 1, 1]` 格式）：

| 参数 | 默认值 | 用途 |
| --- | --- | --- |
| `peekEnterCurve` | `[0.2, 0, 0.18, 1, 1, 1]` | 鼓包探出，缓起、加速后柔和停止 |
| `peekExitCurve` | `[0.35, 0, 0.35, 1, 1, 1]` | 鼓包收回 |
| `openCurve` | `[0.24, 0, 0.2, 1, 1, 1]` | 面板展开，后段留出回弹和断颈的时间 |
| `closeCurve` | `[0.32, 0, 0.28, 1, 1, 1]` | 面板收起 |

表中的阶段是几何进度，不是经过时间的百分比；Bézier 决定抵达每阶段的时刻。
调整横坐标可以改变加减速时间分配，纵坐标保持在 0–1 内；回弹幅度通过 `reboundDistance`
调节，不通过让阶段进度越界实现。位置回弹从 `emergenceEnd` 开始，以
`16 × t² × (1−t)² × reboundDistance` 形成一次越位后回落，起止位移与速度均为零；
t 是 `emergenceEnd` 到 1 的归一化进度，默认最大越位位于 progress=0.83。

面板最终尺寸由 `Shared/HorizontalKeystoneLayout.qml`、`Shared/VerticalKeystoneLayout.qml`
以及具体内容提供。`heldWidth/heldHeight` 在收起期间保留上一个面板尺寸；面板之间切换时
使用 400 ms、OutCubic 的尺寸过渡。不要以改目标尺寸的方式调节鼓包。

## 曲线、模糊与 shader

`stage(start, end)` 使用 `p²(3−2p)`，保证每阶段起止速度为零。
鼓包截面为 `peekDepth × (1−t²)³`，t 是中心到边缘的归一化距离，肩部斜率、曲率均归零。
鼓包随面板出水消退，shader 对鼓包、面板、细颈取并集，**不插值两套完整轮廓的距离场**。
这保证出水过程中面板内部不会被挖空或撕成两个部分。

颈部是带椭圆内凹边缘的连接体，与两侧水平均相切：

- `neckRoot` 中的 `0.4` 与 `/ 3` 控制宽接触面在分离最初几像素内收窄的程度与速度。
- `neckWaist` 中的 `0.55` 控制随间距增加而变细的程度；过大会提前断开。
- `contactBlend` 中的 `/ 4` 控制分离前 4 px 内两侧融合的消退速度。
- 负的腰部半宽表示中央已经断开，两端仍附着；不是需要钳制的非法值。

源码为 `assets/shaders/keystone/frag/long_split.frag`。
`inwardNormal` 显式指定上下左右方向；不再从面板中心的位移符号推测方向。
`edgeSoftness: 0.8` 是抗锯齿宽度，不是粘连强度。
Dashboard 的 `cutoutRect/cutoutRadius` 用于开孔，不用于调节出场。

主体与面板使用同一 shader 外壳，最终统一应用背景透明度。
`extensionRegion` 同时供 compositor blur 和鼠标 mask 使用：圆角面板先按水面裁剪，
鼓包使用 24 条内接窄条、细颈使用 12 条内接窄条近似轮廓，断开的中央不保留模糊矩形。
修改鼓包或颈部公式时应同步 QML 的 `bulgeAt/neckAt` 与 shader；仅改上述参数无需复制数值。
正文的独立入场位移已删除，位置直接跟随同一面板。

阴影留白为四周 24 px，DropShadow 半径 14、采样 29、内向偏移 4 px。
`Long.qml` 的 `edgeMargin: 8` 控制屏幕边距，不影响 peak 深度。

修改 shader 后重新生成随仓库提交的 QSB；只改 QML 参数无需编译 shader：

```bash
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 \
  -o assets/shaders/keystone/qsb/long_split.frag.qsb \
  assets/shaders/keystone/frag/long_split.frag
```

## 人工调整顺序

1. 先调 `peekWidth/peekDepth`，只观察悬停鼓包。
2. 调 `openDuration/closeDuration` 与四条 Bézier 曲线，再调 `reboundDistance`（建议 4–12 px）。
3. 调 `emergenceEnd/separationEnd/releaseStart`，分配出水、附着停留和断开的时间。
4. 最后调 `neckWidth/shoulderRadius`，每次只改一项，观察关键帧和连续动画。
5. 检查移入、移出、peak 中途展开、展开中途收起再展开、切换不同尺寸面板，以及四个屏幕边缘。
   透明背景下检查封面背景、正文、阴影和模糊区是否一致。

修改 QML 后运行 `scripts/dev/format-qml.sh`，然后运行 `scripts/dev/check.sh`。
离屏关键帧和连续动画能检查几何与反向连续性，compositor blur 和鼠标体验仍需桌面会话观察。
