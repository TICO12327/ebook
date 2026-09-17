# 阅读（YueDu）

一个自用的 iOS 在线 EPUB 阅读器。使用 SwiftUI 与 SwiftData，支持从 OPDS 书源搜索、下载 EPUB，并在本地阅读。

## 当前功能

- OPDS 在线书源，内置 Project Gutenberg 与 Standard Ebooks
- 关键词搜索与一键下载
- EPUB 章节解析与分页阅读
- 章节目录与章节跳转
- 阅读进度保存
- 主题、字体、字号、行距、段距、边距设置
- 搜索书架、删除书籍
- 可添加自定义 OPDS 书源

## 暂未包含

- 文字转语音（TTS）
- DeepSeek 文本处理
- 账号与云端同步
- PDF、TXT、MOBI

## 环境要求

- iOS 17.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（用于从 `project.yml` 生成工程）

## 本地构建

```bash
brew install xcodegen
xcodegen generate
open YueDu.xcodeproj
```

在 Xcode 中设置你的 Team 与 Bundle Identifier，连接 iPhone 后运行。

## 云端构建未签名 IPA

仓库包含 `.github/workflows/build-ipa.yml`。推送到 GitHub 后：

1. 打开仓库的 Actions 页面
2. 选择 `Build Unsigned IPA`
3. 运行 `Run workflow`
4. 下载 `YueDu-unsigned-ipa`

这是未签名 IPA，需要使用 SideStore、AltStore 或 Sideloadly 自签安装。

## 自签安装

### SideStore / AltStore

1. 在 iPhone 上安装 SideStore 或 AltStore
2. 将未签名 IPA 导入
3. 使用你的 Apple ID 签名安装
4. 免费账号每 7 天需要续签一次

### Sideloadly

1. 在电脑上安装 Sideloadly
2. 连接 iPhone
3. 选择 IPA，输入 Apple ID
4. 开始签名安装

### 注意事项

- 免费 Apple ID 安装的 App 每 7 天需要重签
- 使用付费开发者账号可获得 1 年签名有效期
- Bundle Identifier 必须唯一，建议修改为 `你的域名.yuedu`

## 项目结构

```text
YueDu/
  App/           App 入口与全局状态
  Models/        SwiftData 模型与阅读设置
  Services/      OPDS、下载、EPUB 解析、文件存储
  Views/
    Bookshelf/   书架与在线书城
    Reader/      阅读器
    Settings/    设置
  Resources/     资源目录
```

## 设计说明

EPUB 解压使用系统 `unzip` 命令，因此在 iOS 真机上可以直接运行。文本提取采用章节 HTML 转纯文本的方式，优先保证阅读稳定与速度。

后续接入 TTS 时，建议从 `ReaderViewModel` 暴露当前章节的 `plainText` 与段落偏移，将朗读位置与阅读位置统一到同一套段落索引上。
