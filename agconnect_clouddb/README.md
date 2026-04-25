# AGConnect CloudDB（云数据库）

## 简介

CloudDB 提供端云协同的数据管理能力，支持统一数据模型与查询操作。

- 官方文档：https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-clouddb-introduction-0000001054212760

## 平台支持

| Android | iOS | HarmonyOS |
|:---:|:---:|:---:|
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

## CloudDB 接入

### 1. 在 AGC 控制台导出对象类型代码

导出 Android 代码时，包名填写：

```text
com.huawei.agconnectclouddb.objecttypes
```

### 2. 将导出文件放入 app 模块

```text
android/app/src/main/java/com/huawei/agconnectclouddb/objecttypes/
├── ObjectTypeInfoHelper.java
├── YourObjectType1.java
└── ...
```

### 3. app 模块添加 CloudDB 依赖

`android/app/build.gradle.kts`：

```kotlin
dependencies {
    implementation("com.huawei.agconnect:agconnect-cloud-database:1.9.1.300")
}
```

### 4. 在 Application 中注册对象类型

`MainApplication.kt`：

```kotlin
import com.huawei.agconnectclouddb.ObjectTypeRegistry
import com.huawei.agconnectclouddb.objecttypes.ObjectTypeInfoHelper

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ObjectTypeRegistry.register(ObjectTypeInfoHelper.getObjectTypeInfo())
    }
}
```

新增对象类型后，只需重新导出并更新 `ObjectTypeInfoHelper`。

## HarmonyOS 说明

HarmonyOS 通过 `@kit.CloudFoundationKit` 的 `cloudDatabase` 模块实现，并补充了本地缓存层。

### 关键能力

- CloudDB 初始化与对象类型创建
- Zone 打开/关闭/删除
- `upsert` / `delete`
- 条件查询、排序、分页、聚合
- 事务顺序执行（模拟）
- 离线缓存回退查询

### 离线缓存机制

- 写操作成功后异步回写本地缓存。
- 默认查询优先云端，超时或失败回退本地缓存。
- 本地建表基于 `rawfile/schema.json`。
- `schemaVersion` 变化时自动重建本地缓存表。

### 与 Android/iOS 的差异

- `enableNetwork/disableNetwork`：OHOS 无对应 API。
- `setUserKey/updateDataEncryptionKey`：OHOS 无对应 API。
- `subscribeSnapshot`：OHOS 无快照订阅 API。
- `executeQueryUnsynced`：降级为普通查询。
- `startAt/startAfter/endAt/endBefore`：OHOS 不支持范围游标。

## 许可

Apache License 2.0
