# 版本保留与发布 / Release retention

正式版本从 **1.0** 起。保留 1.0 及以后版本；不再创建或发布早期测试版本的 Release 或标签。GitHub 源码发布、TestFlight 分发、App Store 审核和商店上线是独立状态，必须分别核验，不能把准备稿或审核中版本写成已上架。

## GitHub

- 每个正式发布使用对应的版本标签；版本号按数字比较。
- 保留 1.0 及后续 Release 与标签，维护当前 README、支持入口和 App Store 链接。
- 不重写源码提交历史，不把本地审核资料、私钥、归档或 QA 数据加入源码发布。
- README 视觉素材来自官网的原生网页渲染，使用官网公开仓库中固定提交的 PNG URL；浅色与深色 `<picture>` 源均须验证。
- 中英文 README 和 App 官网只展示产品介绍、功能、截图、下载和支持入口，不展示更新日志、更新说明、审核情况或发布进度。版本更新说明放在 GitHub Release 与 App Store Connect 对应版本中。
- README 的项目图标直接引用当前 `Sources/Assets.xcassets/AppIcon.appiconset/` 浅色和深色图标，不使用开发者个人头像代替 App 图标。
- 仓库保持公开，官网为 https://larryhu.com/simpleworth/ 。简介与主题保持和产品定位一致；未经单独授权，不更改个人账号头像或源代码许可。

## 每次更新同步清单

1. 核对 `project.yml`、Xcode 工程和 `Sources/Info.plist` 的版本号与构建号一致；以归档内实际信息和 Apple 后台回读为准。
2. 提交并推送已验证的源码。使用对应 `V<版本号>` 标签，不移动已发布标签；已经存在的版本只更新 Release 元数据与说明。
3. 同步 GitHub Release 的标题、版本、构建号和四语更新说明。经用户要求发布的最新源码版本设为 Latest；如果仅为测试版则保留 Pre-release。不得把 GitHub Latest 误写成 App Store 已上线。
4. 分别核对 TestFlight、App Store Connect 和公开商店的真实状态。若 GitHub 源码先行发布，Release 中明确说明 Apple 侧仍在测试或审核；商店实际发布后再同步该状态。
5. 核对中英文 README 的当前 App 图标、产品截图、功能、下载和支持链接。只在产品内容变化时更新介绍，不重新加入更新日志、版本更新说明或审核状态。
6. 核对仓库 About 的简介、官网、主题、可见性，以及项目社交预览。品牌变化时用当前 App 图标重新导出 `docs/branding/social-preview.html` 为同目录的 PNG，尺寸 1280×640、文件小于 1 MB，然后在仓库 Settings → Social preview 上传；仅提交图片文件不会更改远端设置。
7. 保留四语说明、签名和上传等必要本地发行材料，但不提交私钥、认证信息或个人审核联系资料；执行凭据扫描后再发布。对 README、Release、About、图标和社交预览做远端回读，不把本地完成当成 GitHub 已同步。

README and the product website stay focused on the product, not release notes or review status. Each user-requested release must also sync the GitHub Release, current app icons, About metadata, and social preview. GitHub source releases, TestFlight distribution, App Review, and public App Store availability must be verified independently. Keep the personal account avatar and existing licensing unchanged unless separately authorized.

## Xcode

核对归档内部 `CFBundleIdentifier`、`CFBundleShortVersionString` 和构建号，不凭文件夹日期判断版本。保留 1.0 及以后归档、对应 dSYM、导出配置和必要发行材料。只有确认属于 SimpleWorth 且低于 1.0 的旧归档和配套文件才移除。DerivedData 是可重建缓存，清理前确认没有活动构建。

## App Store Connect

保留 1.0 及以后的正式版本、准备稿、构建和相关素材。旧 TestFlight 构建只能按 Apple 提供的能力停止测试／设为过期；已上传的历史记录仍可能显示，不能把“已过期”写成“已彻底删除”。不得为了清理历史而删除 App、当前版本、测试组或当前用户数据。

[Apple: Stop testing a build](https://developer.apple.com/help/app-store-connect/test-a-beta-version/stop-testing-a-build/)

Version 1.0 is the retention floor. Preserve all later versions and their required archives, symbols and release materials. Retire pre-1.0 TestFlight builds using Apple's supported expiration flow, while preserving current distribution and future drafts. Uploaded historical build records may remain visible in App Store Connect.
