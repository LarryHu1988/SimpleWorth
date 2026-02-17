# SimpleWorth（简值）

SimpleWorth 是一款参考 Apple Fitness 视觉语言的 iOS 记账 App，当前底部 Tab 为：`支出`、`收入`、`金库`、`统计`。

## V0.5.0 功能概览

- 支出 / 收入记账：
  - 分类图标记账、真实数据增删改查
  - 年/月筛选联动
  - 账单滑动操作：右滑复制、左滑删除；支出账单额外支持退款
  - 退款账单保留在支出流中（退款分类），并同步更新统计
- 多币种与汇率：
  - 支持前 20 主流币种
  - 本位币设置、汇率实时更新、国旗与币种标识
  - 金额编辑统一展示币种符号前缀与汇率换算
- 统计图表：
  - 月度收入/支出并排柱状趋势图（可按年份与月份联动查看）
  - 分类占比图与收支概览（收入、支出、净结余、储蓄率）
- 金库（原小金库）：
  - 目标增删改查、存入记录管理
  - 存入与目标金额编辑支持币种符号前缀
  - 进度自动联动
- 设置能力：
  - 震动反馈、深色模式、账单详细时间
  - iCloud 同步开关、账单导入/导出
  - 货币选择、意见反馈、好评鼓励、分享给朋友、开发者信息

## 技术栈

- SwiftUI
- SwiftData
- CloudKit（iCloud 同步）
- Charts
- XcodeGen

## 本地运行

```bash
xcodegen generate
open SimpleWorth.xcodeproj
```

## 构建

```bash
xcodebuild -project SimpleWorth.xcodeproj -scheme SimpleWorth -destination 'platform=iOS Simulator,name=iPhone 17' build
```
