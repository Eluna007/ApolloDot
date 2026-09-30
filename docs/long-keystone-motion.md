# Long 灵动岛动画调节

本轮实验的恢复基线为 `a205039`，标签 `long-keystone-baseline-a205039`。
实验位于 `codex/long-caelestia-motion` 分支。入口为
`Modules/Keystone/Styles/Long/LongIslandFrame.qml`。

## 运动模型

参考 Caelestia 的 dashboard：面板从条栏内侧边缘滑出，接触处使用圆形平滑并集，
形成与两侧表面相切的内凹肩部。靠近条栏的面板圆角临时填平，避免内凹肩部下面
再出现凸起的折痕。来源版本与许可证见 `licenses/README.md`。

Clavis 的补充是等比缩放和最终脱离：正文、封面背景、Dashboard 开孔、面板外壳
共用一套位置和缩放值。隐藏部分裁切在条栏内侧，不经过时钟或条栏外侧。
间距增大时，宽接触面逐渐收窄并断开，最终停在条栏内侧 24 px 处。
不存在独立的连接柱或圆形种子。

`progress` 是直接经过 Bézier 曲线后的位姿进度，不再是传入另一组阻尼函数的线性时钟。
0 为完全埋入，1 为完全展开；展开曲线允许略大于 1，因此位移和缩放一起越位、回弹。
这里采用 Caelestia 的 expressive spatial Bézier，不包含其原生速度形变求解器。

## 可调参数

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `thickness` | 42 px | 主条栏厚度 |
| `gap` | 24 px | 展开静止时的间距，同时界定粘连残余消失的位置 |
| `panelRadius` | 24 px | 面板原始圆角，随面板等比缩放 |
| `seedLength` | 220 px | 完全隐藏时沿条栏方向的面板长度；小面板不放大 |
| `filletRadius` | 20 px | 接触时内凹肩部的圆弧半径及粘连范围 |
| `peekExposure` | 2 px | peak 时面板前缘越过条栏内侧的距离；平滑融合后的可见鼓包会更深一些 |
| `openDuration` | 500 ms | 展开与回弹的完整时长 |
| `openCurve` | `[0.38, 1.21, 0.22, 1, 1, 1]` | Caelestia expressive spatial 曲线，带小幅越位 |
| `closeDuration` | 320 ms | 从展开状态收回、或收回到 peak 的时长 |
| `closeCurve` | `[0.4, 0, 0.2, 1, 1, 1]` | 收缩缓入缓出，不倒放展开回弹 |
| `peekDuration` | 220 ms | 隐藏与 peak 之间的时长 |
| `peekCurve` | `[0.25, 0, 0.3, 1, 1, 1]` | 克制、无越位的 peak 曲线 |
| `contentOpacity` 的区间 | `peekProgress` 后 0.3 | 正文随出场逐渐显现；peak 时保持隐藏 |
| `heldWidth/heldHeight` 的 Behavior | 400 ms、OutCubic | 展开后切换不同内容尺寸时的过渡 |

Bézier 使用 Qt 的 `[x1, y1, x2, y2, 1, 1]` 格式。横坐标影响加减速分配；
纵坐标超过 1 可产生越位。要降低回弹，先把 `openCurve` 的 1.21 向 1 调小；
要放慢整体展开，增加 `openDuration`。不要额外叠加固定像素的回弹脉冲。

调 peak 深度修改 `peekExposure`，调初始宽度修改 `seedLength`；后者也会影响面板
初始缩放。peak 是同一个面板的临界姿态，点击展开直接从当前姿态继续。
设置中心的悬停延迟发生在动画之前，不包含在 `peekDuration` 中。

## 几何和粘连

`heldWidth/heldHeight` 保存内容布局尺寸，收起时不会被时钟尺寸替换。
初始比例为 `min(1, seedLength / 沿条栏方向的布局尺寸)`，随后按 `progress` 变到 1。
`childOffset` 把整块面板从隐藏位置移到 `thickness + gap`。
`peekProgress` 根据尺寸解出前缘恰好露出 `peekExposure` 的位置，不是固定时间点。

`retarget()` 从当前进度起步。快速收起、重开不会先复位到隐藏位置；若收起到 peak
时布局尺寸还在过渡，peak 目标会跟随修正，保持露出深度。

粘连由距离场决定：

- `blendRadius` 随 `separation / gap` 平滑衰减，最终为零。
- `junctionRadius()` 在分离时按沿条栏位置逐渐减弱两侧融合，接触区从两侧向内断开。
- `facingRadius` 只在面板朝向条栏的角靠近条栏时减小，离开后恢复原圆角。
- `burial = filletRadius + 1` 保证进度为零时，融合也不会留下鼓包。

更宽的内凹肩部可增大 `filletRadius`；增大前应一起观察 peak 的深度，以及不同宽度
面板的分离。`gap` 太小可能在最终姿态残留粘连，因此不要只改 shader 中的半径。

## Shader、裁切、模糊与输入区域

Shader 源码为 `assets/shaders/keystone/frag/long_split.frag`。
`circularMinimum` 生成圆形相切连接；它只添加融合部分，不插值整张面板距离场。
面板与条栏使用同一背景透明度，阴影留白四周 24 px，半径 14，内向偏移 4 px。
`edgeSoftness: 0.8` 是抗锯齿宽度，不是粘连强度。

`KeystoneSurface.qml` 中 `longContentViewport` 裁切正文，`layoutOffset` 补偿等比缩放
的中心原点。不要另给正文增加偏移，也不要让封面背景单独缩放。
`cutoutBlur` 将 Dashboard 开孔映射到同一缩放后的坐标。

`surfaceRegion` 包含裁切后的圆角面板和 32 行内接粘连区域，供 compositor blur
和鼠标 mask 共用。行宽使用与 shader 相同的距离场，断开的透明间隙不会吃掉鼠标。
`junctionDistance()` / `junctionRadius()` 与 shader 的轮廓公式须同步维护。
完整面板仍使用原生圆角 Region，不按行采样整块面板。

仅修改 QML 参数无需编译 shader。修改 shader 源码后生成并提交 QSB：

```bash
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 \
  -o assets/shaders/keystone/qsb/long_split.frag.qsb \
  assets/shaders/keystone/frag/long_split.frag
```

修改 QML 后运行 `scripts/dev/format-qml.sh`，再运行 `scripts/dev/check.sh`。
视觉检查覆盖 peak 移入/移出、peak 展开、中途收回重开、大小面板切换、Dashboard
开孔及四个边缘方向。离屏渲染可检查轮廓和变换；真实 compositor blur 和鼠标体验
仍需在桌面会话确认。
