# AGC Flutter Plugin（HarmonyOS 适配版）

基于 [agc-flutter-plugin](https://github.com/AppGallery-Connect/agc-flutter-plugin) 的 HarmonyOS 适配分支。

## 概述

本包是 AGC Flutter Plugin 的 fork 版本，主要针对新版 Android Gradle Plugin（AGP 7.3+）兼容性问题进行了修复，同时保持对 HarmonyOS 平台的支持。

## 包含模块

| 模块 | 说明 | Android | iOS | HarmonyOS |
|------|------|:-------:|:---:|:---------:|
| `agconnect_core` | AGC 核心初始化 | ✅ | ✅ | ❌ |
| `agconnect_auth` | 用户认证（邮箱、手机、匿名、华为账号） | ✅ | ✅ | ✅ |
| `agconnect_clouddb` | 云数据库 | ✅ | ✅ | ✅ |
| `agconnect_cloudfunctions` | 云函数 | ✅ | ✅ | ✅ |
| `agconnect_storage` | 云存储 | ✅ | ✅ | ❌ |
| `agconnect_crash` | 崩溃分析 | ✅ | ✅ | ❌ |
| `agconnect_remote_config` | 远程配置 | ✅ | ✅ | ✅ |
| `agconnect_applinking` | 应用链接 | ✅ | ✅ | ❌ |
| `agconnect_appmessaging` | 应用内消息 | ✅ | ✅ | ❌ |

## 主要改动

### Auth 模块：新增 reauthenticate API

新增 `AGCUser.reauthenticate(credential)` 方法（Android / iOS / HarmonyOS 三端），用于敏感操作超时后刷新认证时效窗口，无需 signOut/signIn。详见 [agconnect_auth/README.md](./agconnect_auth/README.md)。

### Auth + CloudDB 联动：敏感操作后 Token 刷新导致 CloudDB 崩溃

Android 端执行修改邮箱/手机号等敏感操作后，Auth Token 会被刷新，但已打开的 `CloudDBZone` 仍绑定旧 Token，后续云端查询会触发原生层空指针崩溃（SIGSEGV）。HarmonyOS 端不受影响。解决方案：敏感操作后先关闭再重新打开所有 `CloudDBZone`。详见 [agconnect_auth/README.md](./agconnect_auth/README.md#已知问题)。

### Android Gradle Plugin 兼容性修复

- **namespace 声明**：在所有包的 `android/build.gradle` 中补充 `namespace` 字段（AGP 7.3+ 强制要求）
- **compileSdkVersion 升级**：全部从 29/30 升级至 34，修复 `android:attr/lStar not found` 编译错误
- **AndroidManifest 清理**：移除所有包 `AndroidManifest.xml` 中的 `package` 属性（与 `namespace` 冲突）

### CloudDB 对象类型解耦

原版插件硬编码依赖 `objecttypes.ObjectTypeInfoHelper`，要求业务 Schema 放入插件模块内，无法作为通用库复用。

本 Fork 新增 `ObjectTypeRegistry`，由业务层（app）在启动时主动注入，插件与业务 Schema 完全解耦。接入步骤见下方 [CloudDB 接入](#clouddb-接入)。

## 使用方法

在项目 `pubspec.yaml` 中通过本地路径引用：

```yaml
dependencies:
  agconnect_core:
    path: packages/agc-flutter-plugin/agconnect_core
  agconnect_auth:
    path: packages/agc-flutter-plugin/agconnect_auth
  agconnect_clouddb:
    path: packages/agc-flutter-plugin/agconnect_clouddb
  agconnect_cloudfunctions:
    path: packages/agc-flutter-plugin/agconnect_cloudfunctions
  agconnect_storage:
    path: packages/agc-flutter-plugin/agconnect_storage
```

## CloudDB 接入

### 1. AGC 控制台导出对象类型代码

导出 Android 代码时，**包名填写**：

```
com.huawei.agconnectclouddb.objecttypes
```


### 2. 将导出文件放入 app 模块

```
android/app/src/main/java/com/huawei/agconnectclouddb/objecttypes/
├── ObjectTypeInfoHelper.java
├── YourObjectType1.java
└── ...
```

### 3. app 模块添加 SDK 依赖

`android/app/build.gradle.kts`：

```kotlin
dependencies {
    implementation("com.huawei.agconnect:agconnect-cloud-database:1.9.1.300")
}
```

### 4. 在 Application 中注册

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

新增对象类型后只需重新导出文件并更新 `ObjectTypeInfoHelper`，插件无需任何改动。

## 上游仓库

- **原始仓库**：[AppGallery-Connect/agc-flutter-plugin](https://github.com/AppGallery-Connect/agc-flutter-plugin)
- **官方文档**：[AGC Flutter 接入指南](https://developer.huawei.com/consumer/en/doc/AppGallery-connect-Guides/agc-get-started-flutter-0000001057642285)

## 许可证

本项目遵循原始仓库的 [Apache License 2.0](./LICENCE)。
