# LaunchPad

LaunchPad是一个macOS应用程序，提供快速启动和搜索应用的功能。

## 功能特点

- 快速搜索和启动应用程序
- 简洁的用户界面
- 支持多语言本地化[ToDo]
- 全屏无边框窗口

## 安装指南

## macOS安全设置问题解决方案

由于macOS的安全机制，首次运行从互联网下载的应用程序时可能会遇到"无法打开应用程序"的警告。

该程序未签名，必须移通过终端移除应用程序的quarantine属性

```bash
# 导航到应用程序所在目录
cd /Applications

# 移除quarantine属性
xattr -d com.apple.quarantine LaunchPad.app

# 或者，如果应用程序在其他位置，请使用完整路径
xattr -d com.apple.quarantine /path/to/LaunchPad.app
```

### 方法一：直接下载

1. 从[发布页面](https://github.com/wurui1994/launchpad/releases/latest)下载最新的`LaunchPad.zip`文件
2. 解压缩下载的文件
3. 将`LaunchPad.app`拖动到应用程序文件夹

### 方法二：从源代码构建

1. 克隆仓库：`git clone https://github.com/wurui1994/launchpad.git`
2. 进入项目目录：`cd launchpad`
3. 运行构建脚本：`./build.sh`
4. 构建完成后，应用程序将位于`build/LaunchPad.app`



## 使用说明

1. 启动LaunchPad应用程序
2. 使用搜索框输入应用程序名称
3. 按Enter键启动所选应用程序

## 系统要求

- macOS 11.0 (Big Sur) 或更高版本
- 至少4GB RAM
- 50MB可用磁盘空间

## 隐私说明

LaunchPad不会收集任何个人数据，也不会将任何数据发送到外部服务器。应用程序仅访问系统应用程序列表以提供搜索功能。

## 许可证

本项目采用MIT许可证 - 详情请参阅[LICENSE](LICENSE)文件

## 贡献

欢迎提交问题报告和拉取请求。对于重大更改，请先开issue讨论您想要更改的内容。

## 联系方式

如有任何问题或建议，请通过以下方式联系我们：

- 电子邮件：1341531859@qq.com
- GitHub Issues：[提交问题](https://github.com/wurui1994/launchpad/issues)