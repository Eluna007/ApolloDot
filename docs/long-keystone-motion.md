# Long 灵动岛动画调节

入口为 `Modules/Keystone/Styles/Long/LongIslandFrame.qml`。
peak 与面板展开/收起使用独立动画。只调整 peak 时，修改下面四个参数即可；
面板沿用添加 peak 之前的阻尼响应、收缩曲线和 SDF 融合。

## Peak

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `peekWidth` | 240 px | 鼓包两侧接回条栏的总宽度 |
| `peekDepth` | 8 px | 鼓包中心向屏幕内侧探出的高度 |
| `peekDuration` | 220 ms | 鼓包探出、收回的时长 |
| `peekCurve` | `[0.25, 0, 0.3, 1, 1, 1]` | 不越界的 Bézier 缓入缓出曲线，两端速度为零 |

`peekAmount` 在 0–1 之间独立变化。截面使用 `peekDepth × (1−t²)³`，
t 是中心到边缘的归一化距离，肩部斜率和曲率均为零。调大宽度会展开肩部，
调大深度会增加突出程度；不需要修改面板尺寸或融合参数。

peak 只变形条栏内侧边缘，不推动隐藏面板，也不改变面板的 `progress`、
`childOffset`、`pillWidth/pillHeight` 或 `blendRadius`。
从 peak 点击展开时，鼓包自行收回，面板按既有动画展开；正文不会因 peak 而显示。

Bézier 使用 Qt 的 `[x1, y1, x2, y2, 1, 1]` 格式。修改控制点的横坐标调整加减速分配，
纵坐标保持在 0–1 内。设置中心的悬停延迟发生在动画开始前，不是此处的动画时长。

## 面板展开与收起

这些参数属于原有面板动画。peak 的调节不需要改动本节。

| 位置 | 默认值 | 含义 |
| --- | --- | --- |
| `thickness` | 42 px | 条栏主体厚度 |
| `gap` | 24 px | 面板静止时与条栏之间的间距 |
| `pillWidth/pillHeight` | 横向 220 × 42 px；纵向 42 × 220 px | 面板藏在条栏内时的初始尺寸 |
| `progressAnimation.duration` | 展开 580 ms；收起 210 ms | 面板进入和退出的时间 |
| `travel` 的 `response` | `(0, 6.4, 7.2)` | 面板位移的延迟、衰减、振荡频率 |
| `alongGrowth` 的 `response` | `(0.025, 6.8, 5.8)` | 沿条栏方向的尺寸变化 |
| `inwardGrowth` 的 `response` | `(0.055, 6.4, 5.4)` | 向屏幕内部方向的尺寸变化 |
| `contentOpacity` | `stage(0.12, 0.50)` | 展开时正文淡入区间 |
| `contentOffset` | 最大 10 px | 正文相对面板的入场位移 |
| `openingBlend` 的基础强度 | 56 px | 出场期间平滑并集的融合范围 |
| `openingBlend` 的释放区间 | 0.25–0.65 | 逐渐解除出场融合的进度区间 |
| 收起 `blendRadius` 中的系数 | 56 px | 收起时恢复内凹融合的强度 |
| `childRadius` | 21 → 24 px | 面板圆角，同时受当前尺寸限制 |
| `heldWidth/heldHeight` 的 Behavior | 400 ms、OutCubic | 完全展开后切换内容尺寸的过渡 |

`progressAnimation` 的 Linear 是阻尼函数的时钟，不是最终视觉运动。
`response(delay, decay, frequency)` 使用指数衰减与正弦、余弦形成非线性运动和轻微回弹：

- delay：开始时间，归一化到展开时长。
- decay：振荡衰减速度，增大通常减弱回弹。
- frequency：振荡频率，增大会改变第一次越位的时间与幅度。

位移与两个尺寸方向的响应不同步，形成原有的探出和回弹。
回弹由这些响应自然产生，不叠加固定像素的位移脉冲。
同一 response 的参数在中途转向补偿表达式中也有一份，调节时需保持一致。

收起使用 `closingRemaining = smoothStep(progress / legStart)`，从当前姿态收缩，
同时恢复用于内凹肩部的融合强度。它不倒放展开弹簧。
`legPose` 和 `legStart` 保存转向时的状态，保证动画中途关闭、再打开时姿态连续；
它们不是样式参数。更改时长优先调整 `onExpandedChanged` 中的 duration。

## Shader、模糊和输入区域

源码为 `assets/shaders/keystone/frag/long_split.frag`。
面板融合沿用圆角矩形、主体中央的圆形种子及 `smoothMinimum` 的平滑并集。
面板仍与主体重叠时，两侧肩部进行完整融合；分离后由距离场自然收窄、断开。
没有单独绘制固定宽度的连接柱。

- `contact` 中的 12 px：接触边界由宽融合转向局部融合的距离区间。
- `joinRadius` 中的 0.30：分离后主体连接处的融合比例。
- `edgeSoftness: 0.8`：抗锯齿宽度，不是粘连强度。
- `inwardNormal`：四个屏幕边缘的内向方向。
- `cutoutRect/cutoutRadius`：Dashboard 开孔，不用于调节动画。

peak 的距离场仅与既有面板表面取并集，不插值整张距离场，也不改变面板内部。
其 `peekRegion` 使用 24 条内接窄条供 blur 和鼠标 mask 使用。
面板仍用自己的圆角区域和连接处模糊区域；改变 peak 不会扩大面板的鼠标区域。
修改鼓包截面公式时，需同步 QML 的 `peekHeightAt` 与 shader 的 `arch`。

主体与子面板在同一个 shader 外壳中绘制，再统一应用背景透明度。
阴影留白四周 24 px，DropShadow 半径 14、采样 29、内向偏移 4 px。
`Long.qml` 中的 `edgeMargin: 8` 是屏幕边距，不是鼓包深度。

只改 QML 参数无需重新编译 shader。修改 shader 源码后生成并提交 QSB：

```bash
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 \
  -o assets/shaders/keystone/qsb/long_split.frag.qsb \
  assets/shaders/keystone/frag/long_split.frag
```

修改 QML 后运行 `scripts/dev/format-qml.sh`，然后运行 `scripts/dev/check.sh`。
观察 peak 移入/移出、从 peak 展开、中途关闭再打开，以及上下左右四个位置。
离屏渲染可对照轮廓与动画姿态，桌面 compositor blur 和鼠标体验需在真实会话观察。
