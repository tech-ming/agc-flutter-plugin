# AGC Flutter Plugin（HarmonyOS 适配版）

基于 <https://github.com/AppGallery-Connect/agc-flutter-plugin> 的 HarmonyOS 适配分支。

## 概述

本仓库在保留 AGC Flutter 原有能力的基础上，补充了 Android Gradle Plugin 新版本兼容与 HarmonyOS 相关适配。

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
