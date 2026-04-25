# AGConnect Auth（认证服务）

## 简介

认证服务为应用提供安全可靠的用户认证能力，支持邮箱、手机号、匿名、华为账号等登录方式。

- 官方文档：https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-auth-introduction-0000001053732605

## 平台支持

| Android | iOS | HarmonyOS |
|:---:|:---:|:---:|
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

## HarmonyOS 说明

HarmonyOS 通过 `@kit.CloudFoundationKit` 的 `authentication` 模块实现。

支持能力：
- 邮箱登录/注册
- 手机号登录/注册
- 匿名登录
- 华为账号登录
- 获取/刷新 Token
- 用户资料管理
- 退出登录/注销账号

## 新增能力

### `AGCUser.reauthenticate(credential)`

用于刷新敏感操作的认证时效窗口，避免通过 signOut/signIn 重新登录。

## 已知问题与处理

### Android：敏感操作后 CloudDB 旧 Zone 可能崩溃

当执行会刷新 Token 的敏感操作后，已打开的 `CloudDBZone` 可能仍持有旧 Token，随后查询触发原生层异常。

建议流程：
1. 执行敏感操作。
2. 关闭并重新打开相关 CloudDB Zone。
3. 再执行后续 CloudDB 操作。

### HarmonyOS：`updateProfile` 空字符串兼容

`AGCUser.updateProfile()` 传空字符串（例如用于清空昵称或头像）时，OHOS 侧 SDK 对空字符串参数更严格。

本插件已在插件层完成兼容处理：
- 写入时：OHOS 原生桥接层对空字符串进行兼容转换，避免直接触发 SDK 参数错误。
- 读取时：Dart 层统一做字段清洗，确保跨平台读取语义一致。

结论：
- 业务层不需要再为该问题做二次兜底。
- 业务层按正常 `updateProfile` 调用即可。

## 错误码说明

不同平台客户端 SDK 的本地错误码可能不一致，但后端业务错误码（例如 `203817xxx` / `203818xxx`）语义一致。

跨平台建议：
- 优先按后端错误码分组处理业务逻辑。
- 客户端错误码仅用于平台内补充诊断。

错误码参考：
- Android：https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-References/agcauthexception-0000001054083804#section1449134615189
- iOS：https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-References/agcautherrorcode-ios-0000001054662396
- HarmonyOS：https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-References/harmonyos-arkts-agcautherror-0000001633167954

## 许可

Apache License 2.0
