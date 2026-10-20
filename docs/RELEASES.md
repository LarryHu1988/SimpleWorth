# 版本保留与发布 / Release retention

正式版本从 **1.0** 起。保留 1.0 及以后版本；不再创建或发布早期测试版本的 Release 或标签。当前已上架版本为 1.0；准备稿不应写成已发布。

## GitHub

- 每个正式发布使用对应的版本标签；版本号按数字比较。
- 保留 1.0 及后续 Release 与标签，维护当前 README、支持入口和 App Store 链接。
- 不重写源码提交历史，不把本地审核资料、私钥、归档或 QA 数据加入源码发布。
- README 视觉素材来自官网的原生网页渲染，使用官网公开仓库中固定提交的 PNG URL；浅色与深色 `<picture>` 源均须验证。

## Xcode

核对归档内部 `CFBundleIdentifier`、`CFBundleShortVersionString` 和构建号，不凭文件夹日期判断版本。保留 1.0 及以后归档、对应 dSYM、导出配置和必要发行材料。只有确认属于 SimpleWorth 且低于 1.0 的旧归档和配套文件才移除。DerivedData 是可重建缓存，清理前确认没有活动构建。

## App Store Connect

保留 1.0 及以后的正式版本、准备稿、构建和相关素材。旧 TestFlight 构建只能按 Apple 提供的能力停止测试／设为过期；已上传的历史记录仍可能显示，不能把“已过期”写成“已彻底删除”。不得为了清理历史而删除 App、当前版本、测试组或当前用户数据。

[Apple: Stop testing a build](https://developer.apple.com/help/app-store-connect/test-a-beta-version/stop-testing-a-build/)

Version 1.0 is the retention floor. Preserve all later versions and their required archives, symbols and release materials. Retire pre-1.0 TestFlight builds using Apple's supported expiration flow, while preserving current distribution and future drafts. Uploaded historical build records may remain visible in App Store Connect.
