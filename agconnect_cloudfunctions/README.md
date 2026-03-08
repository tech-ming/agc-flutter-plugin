# AGConnect Cloud Functions（云函数）

## 简介

云函数服务提供 Serverless 计算能力，支持在应用端直接调用部署在 AGC 控制台的云函数，无需自行搭建和管理服务器。

[官方文档](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-cloudfunction-introduction-0000001059279544)

## 平台支持

| Android | iOS | HarmonyOS |
|:-------:|:---:|:---------:|
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

## 使用方法

```dart
import 'package:agconnect_cloudfunctions/agconnect_cloudfunctions.dart';

// 创建云函数调用对象（传入 HTTP 触发器标识符）
FunctionCallable functionCallable = FunctionCallable('your-function-trigger');

// 调用云函数（可传入参数）
FunctionResult result = await functionCallable.call({'key': 'value'});

// 获取返回值（JSON 字符串）
String value = result.getValue();
```

## HarmonyOS 适配说明

HarmonyOS 平台通过 `@kit.CloudFoundationKit` 的 `cloudFunction` 模块实现，支持以下功能：

- 调用已部署的云函数/云对象
- 自定义超时时间
- 传递函数参数
- 获取函数执行结果

### 平台差异

| 特性 | Android / iOS | HarmonyOS |
|------|:------------:|:---------:|
| SDK 来源 | AGConnect SDK | Cloud Foundation Kit |
| 函数标识 | `httpTriggerURI`（如 `membership-$latest`） | 插件自动拆分为 `name` + `version` |
| 函数参数 | `functionParameters` 透传 | 映射为 `FunctionParams.data` |
| 超时设置 | 支持（`timeout` + `AGCTimeUnit`） | 支持（转换为毫秒传入） |
| 错误处理 | `AGCFunctionException` | `BusinessError`（错误码 + 消息） |

> **触发器标识符自动解析**：Dart 层传入的 `httpTriggerURI`（如 `membership-$latest`）
> 会被插件自动拆分为 `name: "membership"` + `version: "$latest"`，Dart 层无需感知平台差异。

### 前置条件

1. 在 AGC 控制台完成[云函数部署](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-cloudfunction-getstarted-0000001059300464)
2. 项目 `ohos/AppScope/resources/rawfile/agconnect-services.json` 包含正确的项目配置
3. 为云函数创建 HTTP 触发器并获取触发器标识符

## API 参考

### FunctionCallable

云函数调用类。

| 构造函数 | 说明 |
|---------|------|
| `FunctionCallable(String httpTriggerURI, {int timeout, AGCTimeUnit units})` | 默认构造函数 |
| `FunctionCallable.fromMap(Map map)` | 从 Map 创建 |
| `FunctionCallable.fromJson(String source)` | 从 JSON 字符串创建 |

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `call([dynamic functionParameters])` | `Future<FunctionResult>` | 调用云函数 |
| `clone({...})` | `FunctionCallable` | 克隆并可覆盖部分参数 |

#### 参数说明

| 参数 | 类型 | 必填 | 说明 |
|------|------|:----:|------|
| `httpTriggerURI` | `String` | 是 | HTTP 触发器标识符（即云函数名称） |
| `timeout` | `int` | 否 | 超时时间，默认 70 |
| `units` | `AGCTimeUnit` | 否 | 时间单位，默认 `SECONDS` |

### FunctionResult

云函数执行结果。

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `getValue()` | `String` | 获取返回值（JSON 字符串） |

### AGCTimeUnit

时间单位常量。

| 值 | 常量 | 说明 |
|---|------|------|
| 0 | `NANOSECONDS` | 纳秒 |
| 1 | `MICROSECONDS` | 微秒 |
| 2 | `MILLISECONDS` | 毫秒 |
| 3 | `SECONDS` | 秒（默认） |
| 4 | `MINUTES` | 分钟 |
| 5 | `HOURS` | 小时 |
| 6 | `DAYS` | 天 |

## 开发指南

- [创建云函数](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-cloudfunction-getstarted-0000001059300464)
- [应用内调用](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-cloudfunction-appcall-0000001059460468)
- [HarmonyOS 云函数调用](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/agc-harmonyos-clouddev-invokecloudfunc)

## 许可证

[Apache License, version 2.0](https://www.apache.org/licenses/LICENSE-2.0)
