# RayNote

随时打开，随手记录。RayNote 将浮动笔记窗口、富文本编辑和快捷搜索放在一起，让写作与查阅触手可及。笔记自动保存在本机，离线也能使用。

RayNote 基于 Raycast Notes，由 Codex（GPT-6.1 Sol）提取并封装为独立的本地笔记应用。

## 开始使用

从 [Releases](https://github.com/Raysance/RayNote/releases/latest) 下载应用，解压后将 `RayNote.app` 拖入“应用程序”文件夹，打开即可写作。

## 编辑与整理

- **快速记录**：新建多篇笔记，在列表中搜索和切换，随时查找正文内容。
- **富文本编辑**：通过底部工具栏设置标题、加粗、斜体、下划线、列表和链接。
- **代码笔记**：插入代码块，使用语法高亮阅读代码。
- **笔记管理**：打开操作菜单，复制、删除笔记或选择其他操作。
- **文件导出**：将当前笔记保存为 Markdown、HTML 或纯文本。
- **窗口设置**：调整菜单栏入口和 Escape 键行为。

## 快捷键

| 快捷键 | 功能 |
| --- | --- |
| `⌘ N` | 新建笔记 |
| `⌘ P` | 浏览和搜索笔记 |
| `⌘ F` | 查找当前笔记 |
| `⌘ K` | 打开操作菜单 |
| `⌘ ⇧ E` | 选择格式并导出笔记 |
| `⌘ ,` | 打开设置 |
| `⌘ Q` | 退出应用 |

## 备份与恢复

在 Finder 中按 `⌘ ⇧ G`，输入以下路径：

```text
~/Library/Application Support/NativeNotesExtracted/
```

备份时先退出 RayNote，再复制整个目录，包含读取笔记所需的密钥文件 `PrivateCredentials.plist`。恢复或换机时，退出应用，将完整备份放回同一路径，再打开 RayNote。

问题与建议可提交至 [Issues](https://github.com/Raysance/RayNote/issues)。
