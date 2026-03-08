# AGConnect Auth（认证服务）

## 简介

认证服务为应用提供安全可靠的用户认证系统，支持邮箱、手机、匿名、华为账号等多种认证方式，无需关心云端设施和实现细节。

[官方文档](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-auth-introduction-0000001053732605)

## 平台支持

| Android | iOS | HarmonyOS |
|:-------:|:---:|:---------:|
| ✅ | ✅ | ✅ |

## 安装

```yaml
dependencies:
  agconnect_auth:
    path: packages/agc-flutter-plugin/agconnect_auth
```

```bash
flutter pub get
```

## HarmonyOS 适配说明

HarmonyOS 平台通过 `@kit.CloudFoundationKit` 的 `authentication` 模块实现，支持以下功能：

- 邮箱登录/注册
- 手机号登录/注册
- 匿名登录
- 华为账号登录
- 获取/刷新 Token
- 用户信息管理
- 退出登录/注销账号

## 开发指南

- [使用指南](https://developer.huawei.com/consumer/cn/doc/development/AppGallery-connect-Guides/agc-auth-flutter-usage)
- [API 参考](https://developer.huawei.com/consumer/cn/doc/development/AppGallery-connect-References/flutter-auth-overview)

## 许可证

[Apache License, version 2.0](https://www.apache.org/licenses/LICENSE-2.0)

## 错误码

各平台 SDK 的客户端错误码数值不一致，后台错误码（203817xxx / 203818xxx）一致。跨平台处理时需注意。

各平台错误码参考：

- **Android 错误码**：[官方文档](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-References/agcauthexception-0000001054083804#section1449134615189)
- **iOS 错误码**：[官方文档](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-References/agcautherrorcode-ios-0000001054662396)
- **HarmonyOS 错误码**：[官方文档](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-References/harmonyos-arkts-agcautherror-0000001633167954)

