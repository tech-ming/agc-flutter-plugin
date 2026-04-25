# AGConnect Cloud Functions（云函数）

## 简介

云函数提供 Serverless 计算能力，可在应用侧直接调用部署在 AGC 的云函数。

- 官方文档：https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-cloudfunction-introduction-0000001059279544

## 平台支持

| Android | iOS | HarmonyOS |
|:---:|:---:|:---:|
| ✅ | ✅ | ✅ |

## 安装

```yaml
dependencies:
  agconnect_cloudfunctions:
    path: packages/agc-flutter-plugin/agconnect_cloudfunctions
```

```bash
flutter pub get
```

## 基础用法

```dart
import 'package:agconnect_cloudfunctions/agconnect_cloudfunctions.dart';

final callable = FunctionCallable('your-function-trigger');
final result = await callable.call({'key': 'value'});
final value = result.getValue();
```

## HarmonyOS 说明

HarmonyOS 通过 `@kit.CloudFoundationKit` 的 `cloudFunction` 模块实现。

### 关键能力

- 调用已部署云函数
- 传递函数参数
- 自定义超时
- 获取执行结果

### 平台差异（已适配）

- Dart 侧传入 `httpTriggerURI` 后，OHOS 插件内部会解析为 `name + version`。
- 超时参数会统一换算为毫秒传入 OHOS 能力层。

### 前置条件

1. 在 AGC 控制台完成云函数部署。
2. 确保项目 AGC 配置文件正确。
3. 云函数已创建 HTTP 触发器。

## 许可

Apache License 2.0
