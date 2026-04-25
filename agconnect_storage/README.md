# AGConnect Storage（云存储）

## 简介

云存储提供图片、音频、视频等用户内容的对象存储能力。

- 官方文档：https://developer.huawei.com/consumer/cn/doc/development/AppGallery-connect-Guides/agc-cloudstorage-introduction

## 平台支持

| Android | iOS | HarmonyOS |
|:---:|:---:|:---:|
| ✅ | ✅ | ✅ |

## 安装

```yaml
dependencies:
  agconnect_cloudstorage:
    path: packages/agc-flutter-plugin/agconnect_storage
```

```bash
flutter pub get
```

## HarmonyOS 说明

HarmonyOS 通过 `@kit.CloudFoundationKit` 的 `cloudStorage` 模块实现。

### 前置条件

1. 在 AGC 控制台开通云存储。
2. 配置 AGC 配置文件到 OHOS 工程资源目录。
3. 声明网络权限 `ohos.permission.INTERNET`。

### 已适配能力

- `uploadFile` / `uploadData`
- `downloadToFile` / `downloadData`
- `deleteFile`
- `getMetadata` / `updateMetadata`
- `getDownloadUrl`
- `list` / `listAll`
- 任务控制：`pause` / `resume` / `cancel`

### 差异说明

- `referenceFromUrl`：OHOS 侧未实现。
- 区域查询与超时/重试参数：OHOS 侧按兼容策略处理。

## 许可

Apache License 2.0
