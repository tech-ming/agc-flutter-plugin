# AGConnect Remote Config（远程配置）

## 简介

远程配置服务允许在线管理参数，无需用户更新应用即可在云端灵活修改应用的行为和外观。

[官方文档](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-remoteconfig-introduction)

## 平台支持

| Android | iOS | HarmonyOS |
|:-------:|:---:|:---------:|
| ✅ | ✅ | ✅ |

## 安装

```yaml
dependencies:
  agconnect_remote_config:
    path: packages/agc-flutter-plugin/agconnect_remote_config
```

```bash
flutter pub get
```

## HarmonyOS 适配说明

HarmonyOS 平台通过 `@hw-agconnect/remoteconfig-ohos` + `@hw-agconnect/core-ohos` 实现，支持以下功能：

- 设置本地默认参数（applyDefaults）
- 从云端拉取最新配置（fetch）
- 应用上次获取的云端配置（applyLastFetched）
- 获取配置值（getValue）
- 获取值来源（getSource）
- 获取合并后的所有配置（getMergedAll）
- 清空所有缓存数据（clearAll）
- 设置/获取自定义属性（setCustomAttributes / getCustomAttributes）

### 初始化机制

插件在 `onAttachedToEngine` 时自动完成初始化：

1. 通过 `binding.getApplicationContext()` 获取上下文
2. 调用 `agconnect.instance().init(context)` 初始化 AGC core SDK
3. 获取 `remoteConfig` 实例并调用 `initialized()` 加载本地缓存

**前提条件：** `agconnect-services.json` 需放置在 `rawfile` 目录下，SDK 会自动读取。

### 与 Android/iOS 的差异

| 功能 | Android/iOS | HarmonyOS | 说明 |
|------|:-----------:|:---------:|------|
| setDeveloperMode | ✅ | ⚠️ | HarmonyOS 无对应 API，调用不报错但无实际效果 |

### 核心文件

| 文件 | 职责 |
|------|------|
| `AgconnectRemoteConfigPlugin.ets` | 插件入口（初始化 + MethodChannel 分发） |

## 开发指南

- [使用指南](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-remoteconfig-flutter-usage)
- [API 参考](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-References/agc-overview-flutter)

## 许可证

[Apache License, version 2.0](https://www.apache.org/licenses/LICENSE-2.0)
