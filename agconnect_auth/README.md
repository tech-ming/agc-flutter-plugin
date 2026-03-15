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

## 新增功能

### AGCUser.reauthenticate（重新认证）

新增 `AGCUser.reauthenticate(AGCAuthCredential credential)` 方法，用于刷新敏感操作的认证时效窗口。

**背景**：AGC 将修改密码、修改邮箱、修改手机号、销户、关联账号等视为敏感操作，要求用户在 5 分钟内登录过才能执行。超时后会返回错误码 `203818081`（sensitiveOperationTimeout）。

**用法**：捕获敏感操作超时错误后，调用 `reauthenticate` 刷新时效，再重试原操作。该方法仅刷新认证时效，不会触发 signOut/signIn，密码错误也不影响当前登录态。

```dart
final user = await AGCAuth.instance.currentUser;
final credential = EmailAuthProvider.credentialWithPassword(email, password);
await user!.reauthenticate(credential);
// 重新认证成功，可以继续执行敏感操作
```

**三端支持**：Android、iOS、HarmonyOS 均已实现。

## 已知问题

### Android 端敏感操作后 CloudDB 崩溃（SIGSEGV）

**现象**：在 Android 端执行修改邮箱（`updateEmail`）或修改手机号（`updatePhone`）等会刷新 Auth Token 的操作后，紧接着查询 CloudDB 会导致原生层空指针崩溃（`SIGSEGV, fault addr 0x0`），堆栈指向 `libnaturalbase_cloud_jni.so` 的 `nativeQueryObjectList`。

**根因**：AGC CloudDB 的 `CloudDBZone` 在打开时绑定当前 Auth Token。修改邮箱/手机号等敏感操作会触发 Auth Token 刷新，但已打开的 `CloudDBZone` 仍持有旧 Token。旧 Zone 上的云端查询因 Token 失效导致原生层空指针。

**影响范围**：仅 Android 端复现，HarmonyOS 端 SDK 内部自动处理了 Token 刷新。

**解决方案**：在执行会刷新 Token 的敏感操作后，先关闭再重新打开所有已缓存的 `CloudDBZone`，再执行后续 CloudDB 操作。

```dart
// 1. 执行敏感操作（Token 被刷新）
await authDataSource.updateEmail(newEmail: email, verifyCode: code);
// 2. 重新打开 CloudDB Zone（绑定新 Token）
await cloudDbService.reopenAllZones();
// 3. 继续 CloudDB 操作
await remoteDataSource.upsertUserProfile(updated);
```

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

