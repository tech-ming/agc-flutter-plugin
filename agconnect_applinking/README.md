# AGConnect App Linking（应用链接）

## 简介

App Linking 允许你创建跨平台链接，无论用户是否安装了你的应用，链接都能按定义的方式工作。用户点击链接后将被引导到应用内的指定页面。

- 官方文档：<https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-applinking-introduction>

## 平台支持

| 平台 | 支持状态 | 说明 |
|:---:|:---:|---|
| Android | 完整支持 | 原生 AGC App Linking SDK |
| iOS | 完整支持 | 原生 AGC App Linking SDK |
| HarmonyOS | 部分支持 | 基于 `@kit.AppLinkingKit`，支持接收链接，不支持客户端创建链接 |

## 安装

```yaml
dependencies:
  agconnect_applinking:
    path: packages/agc-flutter-plugin/agconnect_applinking
```

```bash
flutter pub get
```

## 快速开始

### 1. AGC 控制台配置

1. 登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)，选择项目
2. 进入 **增长 > App Linking**，点击 **立即开通**
3. **链接前缀** 页签 → 添加链接前缀（如 `yourapp.drcn.agconnect.link`）
4. **网址允许清单** 页签 → 添加正则规则（如 `https://yourapp\.drcn\.agconnect\.link/.*`）
5. **聚合链接** 页签 → 创建聚合链接，填写深度链接地址

### 2. 客户端接收链接

```dart
import 'package:agconnect_applinking/agconnect_applinking.dart';

final agcAppLinking = AGCAppLinking();

// 监听链接数据
agcAppLinking.onResolvedData?.listen((ResolvedLinkData data) {
  final deepLink = data.deepLink;          // 深度链接 URI
  final campaignName = data.campaignName;  // 活动名称
  // 处理链接跳转...
});
```

---

## 平台集成指南

### Android 集成

**Step 1:** 下载 `agconnect-services.json`，复制到 `android/app/` 目录。

**Step 2:** 在 `android/build.gradle` 中配置 Maven 仓库和 AGC 插件：

```gradle
buildscript {
    repositories {
        google()
        maven { url 'https://developer.huawei.com/repo/' }
    }
    dependencies {
        classpath 'com.huawei.agconnect:agcp:1.7.1.300'
    }
}
```

**Step 3:** 在 `android/app/build.gradle` 中应用 AGC 插件：

```gradle
apply plugin: 'com.huawei.agconnect'
```

**Step 4:** 在 `AndroidManifest.xml` 中添加 Deep Link 配置：

```xml
<activity android:launchMode="standard">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:host="<你的链接前缀域名>" android:scheme="https" />
    </intent-filter>
</activity>
```

### iOS 集成

**Step 1:** 下载 `agconnect-services.plist`，复制到 Xcode 项目根目录。

**Step 2:** 配置 Universal Link 或 Custom URL Scheme：

- Universal Link: [Apple 官方文档](https://developer.apple.com/documentation/xcode/allowing_apps_and_websites_to_link_to_your_content)
- Custom Scheme: [Apple 官方文档](https://developer.apple.com/documentation/xcode/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app)

> **注意：** iOS 14 真机 Debug 模式下，Deep Link 等非主机启动路径不生效，请使用 Profile/Release 模式或模拟器调试。

### HarmonyOS 集成

**Step 1:** 从 AGC 控制台下载 Android 平台的 `agconnect-services.json`，复制到 `ohos/AppScope/resources/rawfile/`，重命名为 `agconnect-services-android.json`。

**Step 2:** 在 `module.json5` 中添加链接接收 skill 配置：

```json5
"skills": [
  {
    "entities": ["entity.system.home"],
    "actions": ["action.system.home"]
  },
  {
    "entities": ["entity.system.browsable"],
    "actions": ["ohos.want.action.viewData"],
    "uris": [
      {
        "scheme": "https",
        "host": "<你的链接前缀域名>"  // 如 xx.drcn.agconnect.link
      }
    ],
    "domainVerify": true
  }
]
```

**Step 3:** 插件自动监听 `onNewWant`，无需在 `EntryAbility` 中手动处理。插件通过 `AbilityPluginBinding.addOnNewWantListener()` 自动接收热启动链接。

---

## API 参考

### AGCAppLinking

| 方法 | 返回类型 | 说明 | Android | iOS | HarmonyOS |
| --- | --- | --- | :---: | :---: | :---: |
| `buildShortAppLinking(ApplinkingInfo)` | `Future<ShortAppLinking>` | 创建短链接 | ✅ | ✅ | ❌ |
| `buildLongAppLinking(ApplinkingInfo)` | `Future<LongAppLinking>` | 创建长链接 | ✅ | ✅ | ❌ |
| `onResolvedData` | `Stream<ResolvedLinkData>` | 监听接收到的链接数据 | ✅ | ✅ | ✅ |

### ResolvedLinkData

| 字段 | 类型 | 说明 | Android | iOS | HarmonyOS |
| --- | --- | --- | :---: | :---: | :---: |
| `deepLink` | `Uri` | 深度链接 URI | ✅ | ✅ | ✅ |
| `clickTimestamp` | `int` | 点击时间戳 | ✅ | ✅ | 始终为 0 |
| `socialTitle` | `String` | 社交分享标题 | ✅ | ✅ | 空字符串 |
| `socialDescription` | `String` | 社交分享描述 | ✅ | ✅ | 空字符串 |
| `socialImageUrl` | `String` | 社交分享图片 | ✅ | ✅ | 空字符串 |
| `campaignName` | `String` | 活动名称 | ✅ | ✅ | 空字符串 |
| `campaignMedium` | `String` | 活动媒介 | ✅ | ✅ | 空字符串 |
| `campaignSource` | `String` | 活动来源 | ✅ | ✅ | 空字符串 |
| `installSource` | `String` | 安装来源 | ✅ | ✅ | 空字符串 |
| `linkType` | `LinkType` | 链接类型 | ✅ | ✅ | ✅ |

### ShortAppLinking

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `shortLink` | `Uri` | 短链接 |
| `testUrl` | `Uri` | 测试链接 |

### LongAppLinking

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `longLink` | `Uri` | 长链接 |

### ApplinkingInfo

创建链接时的配置信息。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `deepLink` | `String` | 深度链接地址 |
| `uriPrefix` | `String` | 链接前缀域名 |
| `socialCardInfo` | `SocialCardInfo` | 社交分享信息 |
| `campaignInfo` | `CampaignInfo` | 活动追踪信息 |
| `androidLinkInfo` | `AndroidLinkInfo` | Android 链接配置 |
| `iosLinkInfo` | `iOSLinkInfo` | iOS 链接配置 |
| `itunesLinkInfo` | `iTunesLinkInfo` | iTunes 链接配置 |
| `expireMinute` | `int` | 短链接有效期（分钟），默认 2 年 |
| `shortAppLinkingLength` | `ShortAppLinkingLengthConstants` | 短链接后缀长度 |
| `previewType` | `AppLinkingLinkingPreviewTypeConstants` | 预览页样式 |

---

## HarmonyOS 适配说明

### 运行环境

- DevEco Studio: 5.0+
- SDK: API 12+

### 关键结论

- **接收链接**：支持。通过 `AbilityPluginBinding.addOnNewWantListener()` 自动监听冷启动（`launchWant.uri`）和热启动（`onNewWant`），以及延迟链接（`deferredLink.popDeferredLink()`）。
- **创建链接**：不支持。HarmonyOS `@kit.AppLinkingKit` 不提供客户端创建链接 API，需通过 AGC 控制台或服务端 API 创建聚合链接。

### 链接数据来源

HarmonyOS 端 `onResolvedData` 的数据来源：

1. **冷启动**：`UIAbility.launchWant.uri`，在 `onAttachedToAbility` 时获取
2. **热启动**：`UIAbility.onNewWant`，通过 `AbilityPluginBinding.addOnNewWantListener` 自动接收
3. **延迟链接**：`deferredLink.popDeferredLink()`，应用首次启动时获取此前点击的链接

### 与 Android/iOS 的差异

| 功能 | Android/iOS | HarmonyOS | 说明 |
| --- | :---: | :---: | --- |
| `buildShortAppLinking` | 支持 | 不支持 | HarmonyOS 无客户端创建链接 API，调用抛出 `PlatformException(UNSUPPORTED)` |
| `buildLongAppLinking` | 支持 | 不支持 | 同上 |
| `onResolvedData.deepLink` | 完整 URI | 完整 URI | 三端一致 |
| `onResolvedData.clickTimestamp` | 真实时间戳 | 始终为 0 | `@kit.AppLinkingKit` 不提供此字段 |
| `onResolvedData.socialCardInfo` | 完整数据 | 空字符串 | `@kit.AppLinkingKit` 不提供此字段 |
| `onResolvedData.campaignInfo` | 完整数据 | 空字符串 | `@kit.AppLinkingKit` 不提供此字段 |
| EntryAbility 配置 | AndroidManifest intent-filter | module.json5 skill + domainVerify | 配置方式不同 |
| 热启动监听 | Android Activity `onNewIntent` | `AbilityPluginBinding.addOnNewWantListener` | 插件自动注册，无需手动处理 |

### 创建聚合链接（HarmonyOS）

由于 HarmonyOS 不支持客户端创建链接，请在 AGC 控制台操作：

1. 进入 **增长 > App Linking > 聚合链接**
2. 点击 **创建聚合链接**
3. 填写 **深度链接地址**（如 `https://yourapp.drcn.agconnect.link/register?aff=u566`）
4. **HarmonyOS 链接行为** 选择"在 HarmonyOS 应用中打开"
5. **未安装时重定向到** 选择"华为应用市场页面详情页"
6. 点击"发布"，获取短链接

---

## 混淆配置（Android）

在 `android/app/proguard-rules.pro` 中添加：

```
-ignorewarnings
-keepattributes *Annotation*
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes Signature
-keep class com.hianalytics.android.**{*;}
-keep class com.huawei.updatesdk.**{*;}
-keep class com.huawei.hianalytics.**{*;}
-keep class com.huawei.hms.**{*;}
-keep class com.huawei.agc.**{*;}
-keep class com.huawei.agconnect.**{*;}

## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**
-keep class com.huawei.agc.flutter.** { *; }
-repackageclasses
```

---

## 许可

Apache License 2.0
