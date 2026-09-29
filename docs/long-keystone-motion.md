# Long 灵动岛动画调节

适用于 long 样式的 peak、媒体、Dashboard、歌词和工具界面的通用展开/收起。
录屏、录音还有独立的呈现流程，不全部由本文参数控制。

## 调整入口

`Modules/Keystone/Styles/Long/LongIslandFrame.qml` 顶部集中参数：

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `peekDepth` | 9 px | peak 弧形鼓包中心向内侧探出的高度 |
| `peekWidth` | 120 px | 弧形鼓包两侧接回主体的总宽度；越宽越舒展 |
| `peekBlend` | 12 px | 从 peak 转入完整展开时的 SDF 融合半径；静止 peak 不使用融合凸起 |
| `peekDuration` | 220 ms | peak 探出与收回的时长 |
| `openDuration` | 580 ms | 完整展开的时长 |
| `closeDuration` | 210 ms | 完整收起的时长 |
| `fusionRadius` | 56 px | 展开/收起过程中粘连的最大基础强度；太大可能鼓包 |
| `seedMorphEnd` | 0.35 | 展开进度到此值时，椭圆完全过渡为圆角面板；范围建议 0.2–0.5 |

`peekDepth` 必须大于 0，`seedMorphEnd` 应在 0–1 内且大于 0。
peak 的 easing 在 `Behavior on peekAmount` 中，默认 `Easing.OutCubic`；
改为 `InOutCubic` 会让起步更缓。peak 目前没有额外的弹簧回弹。
设置中心的悬停打开/关闭延迟是**开始动画前的等待时间**，不是动画时长。

## 完整展开和收起

以下仍在同一个 QML 文件中。它们是归一化进度参数，不是秒数：

| 位置 | 默认值 | 含义 |
| --- | --- | --- |
| `thickness` | 42 px | 主体厚度，同时决定椭圆的短轴 |
| `gap` | 24 px | 完全展开后主体与面板之间的距离 |
| `travel` 的 `response` | `(0, 6.4, 7.2)` | 面板离开主体的运动 |
| `alongGrowth` 的 `response` | `(0.025, 6.8, 5.8)` | 沿条栏方向的尺寸增长 |
| `inwardGrowth` 的 `response` | `(0.055, 6.4, 5.4)` | 向屏幕内部方向的尺寸增长 |
| `childRadius` | 21 + 3 × 增长进度 | 面板圆角从约 21 增至 24 px，并受尺寸限制 |
| `contentOpacity` | `stage(0.12, 0.50)` | 内容从 12% 进度开始淡入，50% 时完成 |
| `contentOffset` | 10 px | 内容的入场位移幅度 |
| `openingBlend` | 起点 0.25，跨度 0.40 | 粘连从 25% 进度开始退去，到 65% 完全断开 |
| `Behavior on heldWidth/heldHeight` | 400 ms，OutCubic | 完全展开后切换内容尺寸的过渡 |

`response(delay, decay, frequency)` 是阻尼振荡函数：
- `delay` 增大：这一部分更晚开始。
- `decay` 增大：振荡更快衰减，通常回弹更弱。
- `frequency` 增大：振荡更快，第一次回弹更早；与 decay 联合影响回弹幅度。
- 每个 response 在两处出现（目标与中途转向修正），修改时保持同一组数值一致。

完整收起使用 `closingRemaining` 的 smoothStep，从当前姿态缩回，不是倒放展开弹簧。
若只想收起慢一点，改 `closeDuration`，不要改 `legStart`、`legPose` 或 `progress`。
这些是中途反向时保持连续的运行状态，不是风格参数。
`progressAnimation` 的 Linear 也不是最终视觉曲线；实际曲线由 response/smoothStep 计算。
改变内容淡入区间时，要同步修改同一表达式内的 0.12 和 0.38（0.50−0.12）。

面板最终尺寸由 `Shared/HorizontalKeystoneLayout.qml`、
`Shared/VerticalKeystoneLayout.qml` 和具体内容的 implicit size 提供，
`targetWidth/targetHeight` 接收这些目标并按屏幕尺寸限制。不要用峰值动画参数改变内容尺寸。

## Shader 的调节项

源码：`assets/shaders/keystone/frag/long_split.frag`。
QML 中的 `MorphShader` 把尺寸、中心、圆角及融合半径传给 shader。

- `seedEllipse`：椭圆与圆角矩形距离场的混合权重，由 `seedMorphEnd` 自动控制。
- `edgeSoftness`（QML 中 0.8）：边缘抗锯齿宽度，不是粘连强度。
- `smoothMinimum`：距离场的平滑并集；其 radius 控制融合范围。
- `contact` 中的 `12.0`：分离后肩部融合退化为细颈的距离区间。
- `joinRadius` 中的 `0.30`：分离后的细颈融合比例；增大会加粗粘连。
- `mainRadius`、`satelliteRadius`：主体、子面板的圆角，优先从 QML 改。
- `cutoutRect/cutoutRadius`：Dashboard 开孔，通常不用于动画调参。

修改 shader 后需重新生成随仓库提交的 QSB；仅修改 QML 参数不需要编译 shader：

```bash
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 \
  -o assets/shaders/keystone/qsb/long_split.frag.qsb \
  assets/shaders/keystone/frag/long_split.frag
```

## 建议的人工调节顺序

1. 先调 `peekWidth`（80–120）、`peekDepth`（4–8），确定静态轮廓。
2. 再调 `peekBlend`（8–18），观察肩部，而非只看凸起中心。
3. 调 peak 时长；然后调完整展开/收起时长。
4. 最后小幅调整 response 的衰减和频率，每次只动一组。
5. 保存后使用项目现有重载入口观察。检查移入、移出、动画中途点击展开、
   展开中途收起，以及上下左右四个位置；透明背景下也检查阴影与 blur。

修改 QML 后运行 `scripts/dev/format-qml.sh`，然后 `scripts/dev/check.sh`。
渲染截图只能确认轮廓，仍应在桌面检查运动与鼠标交互。

其他视觉与交互常量：`morphSurface` 四周 24 px 是阴影绘制留白，
DropShadow 的 `radius: 14`、`samples: 29` 和内向偏移 4 px 控制阴影；
调整阴影范围时确保留白足够。`neckBlur` 的 12 px 宽度、
`blendRadius > separation * 2.8` 决定粘连处的模糊区域，需与大幅修改后的形状一起核对。
主内容在 `Shared/KeystoneSurface.qml` 中使用 0.02 的进度门槛启用交互，
peak 使用独立的 `peekHovered`，不显示面板正文。
屏幕边距 `edgeMargin` 在 `Long.qml` 中为 8 px；它不是 peak 的探出距离。

静止 peak 现在直接变形主体内侧边缘：`height * (1 - t²)³`，其中 t 为归一化横向距离。中心圆滑、两侧斜率和曲率归零，形成连续弧形鼓包。展开前段再平滑切回原来的粘连 shader。
