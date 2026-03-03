# AGC Flutter Plugin（HarmonyOS 适配版）

基于 [agc-flutter-plugin](https://github.com/AppGallery-Connect/agc-flutter-plugin) 的 HarmonyOS 适配分支。

## 概述

本包是 AGC Flutter Plugin 的 fork 版本，主要针对新版 Android Gradle Plugin（AGP 7.3+）兼容性问题进行了修复，同时保持对 HarmonyOS 平台的支持。

## 包含模块

| 模块 | 说明 |
|------|------|
| `agconnect_core` | AGC 核心初始化 |
| `agconnect_auth` | 用户认证（邮箱、手机、匿名、华为账号） |
| `agconnect_clouddb` | 云数据库 |
| `agconnect_cloudfunctions` | 云函数 |
| `agconnect_storage` | 云存储 |
| `agconnect_crash` | 崩溃分析 |
| `agconnect_remote_config` | 远程配置 |
| `agconnect_applinking` | 应用链接 |
| `agconnect_appmessaging` | 应用内消息 |

## 主要改动

### Android Gradle Plugin 兼容性修复

- **namespace 声明**：在所有包的 `android/build.gradle` 中补充 `namespace` 字段（AGP 7.3+ 强制要求）
- **compileSdkVersion 升级**：全部从 29/30 升级至 34，修复 `android:attr/lStar not found` 编译错误
- **AndroidManifest 清理**：移除所有包 `AndroidManifest.xml` 中的 `package` 属性（与 `namespace` 冲突）


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

## CloudDB ObjectTypeInfoHelper 说明

若应用使用了 CloudDB 本地对象存储功能，需将 AGC 控制台导出的 `ObjectTypeInfoHelper.java` 放置在 app 模块对应路径：

```
android/app/src/main/java/com/huawei/agconnectclouddb/objecttypes/ObjectTypeInfoHelper.java
```

插件会在运行时通过反射自动加载，无需修改插件代码。

## 上游仓库

- **原始仓库**：[AppGallery-Connect/agc-flutter-plugin](https://github.com/AppGallery-Connect/agc-flutter-plugin)
- **官方文档**：[AGC Flutter 接入指南](https://developer.huawei.com/consumer/en/doc/AppGallery-connect-Guides/agc-get-started-flutter-0000001057642285)

## 许可证

本项目遵循原始仓库的 [Apache License 2.0](./LICENCE)。
