# 构建与验证

## 依赖

- Apple Silicon Mac；当前构建只在 macOS 27.0.1 验证。
- Python 3。
- macOS 编译工具：`clang`、系统 SDK 和 `codesign`。
- 本地安装的 ARM64 Raycast **1.104.31**，原始可执行文件 SHA-256 必须为：

```text
c8ff6219fa4122ca35c646fa23638a219c69abcc6d2db81bf6931a92cbec1e95
```

构建需要从这个安装包读取原版模块、框架和资源；仓库没有包含这些原厂二进制文件。原安装包仅用于构建输入，构建过程不会修改它。不同版本或不同哈希会停止构建，不能通过简单替换版本号继续使用。

## 构建

在仓库根目录运行：

```sh
./scripts/build-app.sh
```

默认输出到 `dist/Native Notes.app`。目标目录必须不存在，脚本不会覆盖已有应用。

也可以指定输入和输出：

```sh
python3 extract.py \
  --source /Applications/Raycast.app \
  --output "/另一个目录/Native Notes.app"
```

构建产物包含运行所需模块和资源，运行时不要求 Raycast 处于运行状态。应用使用本地临时签名，没有 Apple 公证。

## 校验

```sh
python3 verify.py
python3 tests/run.py
```

使用自定义输出目录时：

```sh
python3 verify.py --app "/另一个目录/Native Notes.app"
```

`verify.py` 检查原始文件和模块哈希、记录的指令修改、其余原生代码的一致性、原版编辑器资源的一致性，以及应用签名。应用内的 `Contents/Resources/ExtractionManifest.json` 记录每一处修改的地址、字节和用途。

`tests/run.py` 在临时目录使用测试数据，检查密钥文件权限、跨进程恢复、损坏文件拒绝和已有数据库缺失密钥拒绝。测试不读取用户的笔记或真实密钥。
