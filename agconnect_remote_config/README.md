# AGConnect Remote Config（远程配置）

## 简介

远程配置服务允许在线管理参数，无需用户升级应用即可动态调整应用行为和展示内容。

- 官方文档：https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-remoteconfig-introduction

## 平台支持

| 平台 | 支持状态 | 说明 |
|:---:|:---:|---|
| Android | 支持 | 原生 AGC Remote Config |
| iOS | 支持 | 原生 AGC Remote Config |
| HarmonyOS | 兼容支持 | AGC 官方暂不支持 OHOS 远程配置，当前通过 Android 配置文件兼容接入 |

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

### 运行环境

- DevEco Studio: 3.1 Beta2(3.1.0.400)
- SDK: API9 Release(3.2.11.9)

### 关键结论

- AGC 官方当前不提供 OHOS 远程配置原生能力。
- 本插件在 OHOS 端采用 Android 配置兼容方案。

### 配置方式

1. 从 AGC 控制台下载 Android 平台的 `agconnect-services.json`。
2. 复制到 OHOS 目录 `ohos/AppScope/resources/rawfile/`。
3. 将文件重命名为 `agconnect-services-android.json`。

说明：OHOS 侧插件初始化时优先读取 `rawfile/agconnect-services-android.json`；如果读取失败，回退到默认初始化流程。

### 功能支持

- `applyDefaults`
- `fetch`
- `applyLastFetched`
- `getValue`
- `getSource`
- `getMergedAll`
- `clearAll`
- `setCustomAttributes`
- `getCustomAttributes`

### 与 Android/iOS 的差异

| 功能 | Android/iOS | HarmonyOS | 说明 |
|---|:---:|:---:|---|
| `setDeveloperMode` | 支持 | 不支持 | OHOS 无对应 API，调用后直接返回成功 |

## 许可

Apache License 2.0
