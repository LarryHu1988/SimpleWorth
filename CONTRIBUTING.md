# 开发协作 / Development

请先阅读 [开发说明](docs/DEVELOPMENT.md)与[版本保留规则](docs/RELEASES.md)。源码使用 SwiftUI、SwiftData 和 Swift Charts，项目配置由 XcodeGen 生成。每次修改应限于相关功能，保留用户已有的工作区变更。

产品文案与视觉素材以[官网](https://larryhu.com/simpleworth/)为准。README 图片使用官网公开素材仓库中的 PNG，避免私有仓库图片鉴权影响显示；保留可点击的 App Store、支持与隐私文字链接。中英文介绍应同步更新。

行为变更运行对应的隔离回归测试；文档与图片变更检查 GitHub 渲染和资源加载即可。真机数据、Apple 账号、签名私钥、审核账号、日志和构建产物不得提交到仓库。`AppStore/` 是本地发行准备目录，保持 Git 忽略。

Before making changes, read the development and release-retention guides. Keep changes scoped, preserve existing work, and validate the affected behavior. Product copy and visual assets follow the website. Update both README languages and keep public PNG links pinned to the website asset commit. Never commit credentials, private ledgers, signing material, review accounts or generated release artifacts.

© 2026 Larry Hu. All rights reserved. 此文档不授予额外的源码许可。
