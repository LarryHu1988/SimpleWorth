# SimpleWorth（简值）

参考 Apple Fitness 视觉语言的记账类 iOS App，包含底部 4 个 Tab：`支出`、`收入`、`统计`、`小金库`。

## 当前版本能力（V0.2.0）

- 支出 / 收入：
  - 丰富分类图标（生活消费与多来源收入）
  - 真实账单增删改查（新增、编辑、删除）
  - 月度汇总与环形进度展示
- 统计：
  - 近 6 个月收支柱状图
  - 分类占比环形图（支出/收入切换）
  - 总收入、总支出、净结余、储蓄率
- 小金库：
  - 小目标增删改查
  - 存入记录新增/删除，并同步目标进度
  - 总进度圆环与目标进度条
- 视觉：
  - 自定义 App Icon（简值风格）
  - 启动页视觉（品牌图形 + 背景色）

## 技术栈

- SwiftUI
- SwiftData（本地持久化）
- Charts
- XcodeGen

## 启动

```bash
xcodegen generate
open SimpleWorth.xcodeproj
```

## 编译验证

```bash
xcodebuild -project SimpleWorth.xcodeproj -scheme SimpleWorth -destination 'generic/platform=iOS Simulator' build
```
