# 构建与验证

## 依赖

- Apple Silicon Mac；当前构建只在 macOS 27.0.1 验证。
- Python 3。
- macOS 编译工具：`clang`、系统 SDK 和 `codesign`。
- 本地安装的 ARM64 Raycast **1.104.31**，原始可执行文件 SHA-256 必须为：

```text
c8ff6219fa4122ca35c646fa23638a219c69abcc6d2db81bf6931a92cbec1e95
```

构建需要从这个安装包读取原版模块和资源；仓库没有包含这些原厂二进制文件。原安装包仅用于构建输入，构建过程不会修改它。不同版本或不同哈希会停止构建，不能通过简单替换版本号继续使用。

## 构建

在仓库根目录运行：

```sh
./scripts/build-app.sh
```

默认输出到 `dist/RayNote.app`。目标目录必须不存在，脚本不会覆盖已有应用。构建过程使用系统 `assetutil` 裁剪资源库，并通过 Swift/AppKit 和 `iconutil` 生成应用图标。

也可以指定输入和输出：

```sh
python3 extract.py \
  --source /Applications/Raycast.app \
  --output "/另一个目录/RayNote.app"
```

构建产物包含运行所需模块和资源，运行时不要求 Raycast 处于运行状态。应用使用本地临时签名，没有 Apple 公证。

## 校验

```sh
python3 verify.py
python3 tests/run.py --app dist/RayNote.app
```

使用自定义输出目录时：

```sh
python3 verify.py --app "/另一个目录/RayNote.app"
python3 tests/run.py --app "/另一个目录/RayNote.app"
```

`verify.py` 检查原始文件和模块哈希、记录的指令修改、其余原生代码的一致性、原版编辑器资源的一致性，以及应用签名；还逐项核对 6,864 条导入记录，确认只有目标框架的 455 个弱导入标志变化，库序号保持不变。应用内的 `Contents/Resources/ExtractionManifest.json` 记录每一处修改的地址、字节和用途。

`tests/run.py` 在临时目录使用测试数据，检查密钥文件权限、跨进程恢复、改名后沿用旧密钥、损坏文件拒绝和已有数据库缺失密钥拒绝。这些密钥测试不读取用户的笔记或真实密钥。传入 `--app` 时，另行在临时进程中加载成品核心并检查 Notes 类存在、两个已移除框架未加载。

传入 `--app` 也会加载主图标库和 `NotesGlyphs.bundle`，检查所有保留图标可读取，并将 Action Panel、置顶/取消置顶和关闭按钮图标绘制到位图，确认具有非透明像素。补充包以原名注册图片，避免 `assetutil` 的单个保留列表长度限制导致图标静默丢失。

`ResourceManifest.json` 记录资源裁剪前后的大小、删除项、保留的资源包和图标。0.3 不再打包 SplineRuntime 和 SoulverCore。构建器保留原库序号，将这两个库及对应导入标为可选；不能只删除目录而保留强依赖。内部类名、包标识和原版编辑器资源路径保留，界面显示名称由宿主适配为 RayNote。

## 静态依赖审计

可选审计需要 Node.js（本机使用 v24.18.0），只解析原版 Web 编辑器，不执行其中代码：

```sh
python3 audit_dependencies.py > docs/DependencyAudit.json
```

报告记录已知 Notes 区间和宿主启动入口的直接调用图、chained imports 引用，以及 HTML / CSS / 静态 ESM 资源闭包。当前覆盖 6,240 个通过直接分支可达的函数，未发现到这两个框架的引用。6,110 处间接调用或跳转未被解析，结果不能作为全程序无依赖的证明。最终仍需独立的启动、存储、编辑、导出和重启测试。详见 [依赖审计说明](DEPENDENCIES.md)。
