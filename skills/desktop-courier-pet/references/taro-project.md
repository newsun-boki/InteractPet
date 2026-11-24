# 接入本次 Taro 原生工程

仅当工作区确有 `work/octopus-pet` 时使用。先核对实际代码，以下是 2026-11-23 v0.9.0 的结构快照，不要求将来保持完全一致。

| 相对工程路径 | 责任 |
| --- | --- |
| `Sources/App.swift` | 菜单、偏好、输入回调、窗口、健康信息 |
| `Sources/CaretTracker.swift` | AX 目标与事件监听 |
| `Sources/Skins.swift`、`Assets/Skins/skins.json` | 外观目录、资源与配色 |
| `Sources/Motion.swift` | 角色形态、肢体分配、弹簧、字符状态 |
| `Sources/BoundaryMotion.swift` | 屏幕边界路线与开关 |
| `Sources/Locomotion.swift` | 关节/步态姿态 |
| `Sources/Renderer.swift`、`CharacterRendering.swift` | 角色、递送器官和字牌 |
| `Sources/CatTailMotion.swift`、`CatTailRendering.swift` | 常驻尾巴 spline、递送与卷尾夹持、尾纹 |
| `Sources/RigMesh.swift` | 纹理网格变形 |
| `Sources/FiveCatsMotion.swift`、`FiveCatsRendering.swift` | 五猫共享时钟、个体网格与递送根部 |
| `Sources/CatFormation.swift`、`CatSkeleton.swift` | 群体编排与四肢 IK、头耳骨骼、脊柱/尾巴曲线 |
| `Tests/` | 动画、输入顺序、开关和原生预览 |
| `build.sh`、`Info.plist` | 构建、资源复制、版本与签名 |

在工程目录用 `TARO_APP_OUTPUT='/明确的暂存输出/Taro Octopus.app' zsh build.sh`。`build.sh` 可能未设置可执行位，显式调用 zsh 即可。不要硬编码用户主目录或历史进程号。

新增外观在 `skins.json` 配置唯一 id、name、note、kind 与八个十六进制配色，PNG 为 `Skins/<id>.png`。`original` 由内置目录使用 `mantle.png`。新增形态需检查 enum 的全部 switch、armCount、根部、可巡游性、渲染和适配宽度。新增群体不可沿用单角色窄绘制范围。

素材检查，从工作区根目录运行：

```bash
python3 /path/to/desktop-courier-pet/scripts/validate_pet_assets.py work/octopus-pet/Assets --strip five-kittens:5
```

Foundation 动画测试当前需要共同编译 `Sources/Motion.swift Sources/BoundaryMotion.swift Sources/Locomotion.swift Sources/FiveCatsMotion.swift Sources/CatFormation.swift Sources/CatSkeleton.swift Sources/CatTailMotion.swift`，再加一个带 `@main` 的测试文件。不要同时编译多个测试入口。相关测试：MotionTests、CharacterMotionTests、ContinuousLetterTests、BoundaryMotionTests、LocomotionTests、ConcurrentMotionTests、FiveCatsTests、CatGroupTests、CatTailTests。按改动选择，不能仅因为新增一张图就重复所有重测试。

编译后的原生可执行文件支持 `--verify-skins --health-file <path>` 和 `--verify-boundary --health-file <path>`，验证不安装输入监听，并在结束时恢复原有偏好。前者检查全部角色菜单和五猫摇摆开关的重启恢复。启动应用可用 `--health-file <path>`，健康文件不含输入文本。`--skin five-kittens` 是本次进程的覆盖参数，持久角色选择由实际菜单保存。

`Tests/FiveCatsPreview.swift` 导出真实渲染的 12 秒示例：待机、连续输入和关闭摇摆。输出路径从命令参数传入；需要本地 ffmpeg。该示例是合成输入的渲染证据，不能证明微信 AX 兼容。

已有成果在 `output/pet-collection-20/` 与 `output/five-kittens/`，版本发布包应保留可回退旧包。名称中的 20 是历史目录名，不是当前角色总数。对外文档的总数、版本与资源清单应从当前代码核对。


v0.8 新增 `--verify-cat-group --skin five-kittens --health-file <path>`，验证真实菜单触发跟随/扒边、关闭后的平滑回座、禁用期间手动动作无效与新进程恢复关闭。群体沿用 `boundaryPlay` 偏好，`fiveCatsSway` 独立保存。

`Tests/CatGroupPreview.swift` 支持 `assets-directory output-directory --video`，生成 30 秒原生视频和骨骼叠加关键帧；去掉 `--video` 只生成预览帧。共同编译渲染器、动作模块、Skins 与一个测试入口，不能同时加 App.swift 的入口。结果在 `output/five-kittens-rig/`。


v0.9 五猫改由尾根伸出尾巴递字。`--verify-skins` 同时验证尾巴小动作开关与新进程恢复关闭。`Tests/CatTailPreview.swift` 导出两段原生示例：`assets-directory output-directory --video --detail` 为 18 秒放大尾巴动作，省略 `--detail` 为 28 秒边走/攀爬边送字；省略 `--video` 可先抽帧审看。预览编译需加 `CatTailRendering.swift`。结果在 `output/five-kittens-tails/`。
