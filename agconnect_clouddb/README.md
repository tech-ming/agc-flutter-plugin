# AGConnect CloudDB（云数据库）

## 简介

云数据库是一款端云协同的数据库产品，提供设备与云端之间的数据协同管理能力、统一数据模型和丰富的数据管理 API。

[官方文档](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-clouddb-introduction-0000001054212760)

## 平台支持

| Android | iOS | HarmonyOS |
|:-------:|:---:|:---------:|
| ✅ | ✅ | ✅ |

## 安装

```yaml
dependencies:
  agconnect_clouddb:
    path: packages/agc-flutter-plugin/agconnect_clouddb
```

```bash
flutter pub get
```

## HarmonyOS 适配说明

HarmonyOS 平台通过 `@kit.CloudFoundationKit` 的 `cloudDatabase` 模块实现，支持以下功能：

- 初始化 CloudDB / 创建对象类型
- 打开/关闭/删除 CloudDB Zone
- 数据写入（upsert）
- 数据删除（delete）
- 条件查询（equalTo、notEqualTo、greaterThan、lessThan、in、contains、beginsWith、endsWith、isNull、isNotNull）
- 排序与分页（orderByAsc、orderByDesc、limit）
- 聚合查询（average、sum、maximum、minimum、count）
- 事务操作（顺序执行 upsert/delete 模拟）

### 与 Android/iOS 的差异

| 功能 | Android/iOS | HarmonyOS | 说明 |
|------|:-----------:|:---------:|------|
| enableNetwork / disableNetwork | ✅ | ⚠️ | HarmonyOS 无对应 API，调用不报错但无实际效果 |
| setUserKey / updateDataEncryptionKey | ✅ | ⚠️ | HarmonyOS 无对应 API，调用不报错 |
| subscribeSnapshot | ✅ | ⚠️ | HarmonyOS 无快照订阅 API，调用不报错但不会推送事件 |
| executeQueryUnsynced | ✅ | ⚠️ | 使用普通查询代替 |
| executeServerStatusQuery | ✅ | ⚠️ | 返回客户端本地时间戳 |
| startAt / startAfter / endAt / endBefore | ✅ | ❌ | HarmonyOS 查询不支持范围游标 |

## 开发指南

- [使用指南](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-clouddb-flutter-usage-0000001154073689)
- [API 参考](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-References/flutter-clouddb-overview-0000001108597968)

## 许可证

[Apache License, version 2.0](https://www.apache.org/licenses/LICENSE-2.0)
