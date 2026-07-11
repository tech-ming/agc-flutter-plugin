# AGC Flutter Plugin（HarmonyOS 适配版）

基于 <https://github.com/AppGallery-Connect/agc-flutter-plugin> 的 HarmonyOS 适配分支。

## 概述

本仓库在保留 AGC Flutter 原有能力的基础上，补充了 Android Gradle Plugin 新版本兼容、HarmonyOS 相关适配，以及云数据库安全证书更新所需的 SDK 版本对齐。

## 模块支持

| 模块 | 说明 | Android | iOS | HarmonyOS |
|---|---|:---:|:---:|:---:|
| `agconnect_core` | AGC 核心初始化 | ✅ | ✅ | ❌ |
| `agconnect_auth` | 用户认证（邮箱、手机、匿名、华为账号） | ✅ | ✅ | ✅ |
| `agconnect_clouddb` | 云数据库 | ✅ | ✅ | ✅ |
| `agconnect_cloudfunctions` | 云函数 | ✅ | ✅ | ✅ |
| `agconnect_storage` | 云存储 | ✅ | ✅ | ✅ |
| `agconnect_crash` | 崩溃分析 | ✅ | ✅ | ❌ |
| `agconnect_remote_config` | 远程配置 | ✅ | ✅ | ⚠️ |
| `agconnect_applinking` | 应用链接 | ✅ | ✅ | ✅ |
| `agconnect_appmessaging` | 应用内消息 | ✅ | ✅ | ❌ |

说明：

- `✅` 表示已支持。
- `❌` 表示未适配。
- `⚠️` 表示兼容方案支持（非官方原生能力）。

## 主要改动

### 云数据库安全证书更新（SDK 版本对齐）

华为云数据库服务端于 2026-12 更新安全证书（旧证书停用），移动端须在 **2026-12-15 前**升级云数据库 SDK 以启用新证书，否则业务无法连接云端。门槛：Android 云数据库 SDK 需 ≥ `1.9.6.300`，iOS 需 ≥ `1.9.4.300`。

由于 AGC 各模块共用 `agconnect-core`，iOS CocoaPods 对 `AGConnectCore` 的版本约束又需一致，本仓库将全部模块统一对齐（Android / iOS 为两套独立版本号）：

| 模块 | Android | iOS |
|---|:---:|:---:|
| `agconnect_core` | `1.9.6.300` | 随业务库传递 |
| `agconnect_auth` | `1.9.6.300` | `1.9.4.300` |
| `agconnect_clouddb` | `1.9.6.300` | `1.9.4.300` |
| `agconnect_cloudfunctions` | `1.9.6.300` | `1.9.4.300` |
| `agconnect_storage` | `1.9.6.300` | `1.9.4.300`（`~>`） |
| `agconnect_crash` | `1.9.6.300` | `1.9.4.300` |
| `agconnect_remote_config` | `1.9.6.300` | `1.9.4.300` |
| `agconnect_applinking` | `1.9.6.300` | `1.9.4.300` |
| `agconnect_appmessaging` | `1.9.6.300` | `1.9.4.300`（`~>`） |

- 各模块版本在其 `android/build.gradle`（`implementation`）与 `ios/*.podspec`（`s.dependency`）中声明。
- `agconnect_core` 的 iOS podspec 不直接 pin `AGConnectCore`，其版本随业务模块（auth / clouddb 等）传递依赖引入。
- 集成方还需在自身工程配置 AGC Gradle 插件（`agcp`）；`agcp` 与 SDK 为两套版本号、向后兼容，证书更新不依赖它。

#### 使用 CloudDB 时的混淆配置

CloudDB 的 ObjectType 生成类通过反射按类名 / 字段名做序列化与 schema 映射，release 混淆一旦重命名它们即会失败（生成类所在包如 `com.huawei.agconnectclouddb.objecttypes` 不被 `-keep class com.huawei.agconnect.**` 覆盖，因 `agconnect` 后需紧跟 `.`）。

`agconnect_clouddb` 已内置 consumer ProGuard 规则（`android/consumer-rules.pro`，随 AAR 分发），集成方开启 minify 时会**自动**保留继承 `CloudDBZoneObject` 的 ObjectType 生成类，**通常无需额外配置**。

如需在集成方工程显式声明（例如按自己的 ObjectType 实际包名精确保留），可参考：

```proguard
# 按基类保留（与生成包名无关，等价于插件内置规则）
-keep class * extends com.huawei.agconnect.cloud.database.CloudDBZoneObject { *; }
# 或按你的 ObjectType 实际所在包保留（示例）
-keep class com.huawei.agconnectclouddb.objecttypes.** { *; }
```

### Android Gradle Plugin 兼容

- 在各模块 `android/build.gradle` 中补齐 `namespace`。
- `compileSdkVersion` 升级到 34。
- 移除与 `namespace` 冲突的 Manifest `package` 声明。

### Auth 能力扩展

- 新增 `AGCUser.reauthenticate(credential)`。

### CloudDB 解耦

- 通过注册机制解耦对象类型与插件内部实现，便于业务层扩展。

### HarmonyOS 远程配置

- AGC 官方当前不支持 OHOS 远程配置原生能力。
- `agconnect_remote_config` 在 OHOS 端使用 Android 配置兼容方案。
- 开发者需要将 Android 平台的 `agconnect-services.json` 复制到 `ohos/AppScope/resources/rawfile/`，并重命名为 `agconnect-services-android.json`。

## 上游仓库

- 原始仓库：<https://github.com/AppGallery-Connect/agc-flutter-plugin>

## 许可

Apache License 2.0
