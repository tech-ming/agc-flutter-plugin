import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { cloudFunction } from '@kit.CloudFoundationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { parseTriggerURI, resolveTimeoutMs, convertFlutterParams } from './CloudFunctionUtils';

/**
 * AGConnect 云函数 Flutter 插件 - HarmonyOS 平台实现
 *
 * 桥接 Dart 层 MethodChannel 调用至 HarmonyOS Cloud Foundation Kit。
 *
 * 核心适配：
 * 1. 触发器标识符拆分：Android 的 "functionName-$version" → name + version
 * 2. Map → Record 转换：Flutter MethodChannel 传来的 Map 需转为普通对象
 * 3. 超时单位转换：AGCTimeUnit 枚举 → 毫秒
 */
export default class AGCCloudFunctionsPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "AGCCloudFunctionsPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(),
      "com.huawei.agc.flutter.cloudfunctions/MethodChannel");
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method == "callFunction") {
      this.callFunction(call, result)
    } else {
      result.notImplemented()
    }
  }

  /**
   * 调用云函数
   *
   * 参数映射：
   * - httpTriggerURI → parseTriggerURI() → FunctionParams.name + version
   * - timeout + units → resolveTimeoutMs() → FunctionParams.timeout（毫秒）
   * - functionParameters → convertFlutterParams() → FunctionParams.data
   */
  private callFunction(call: MethodCall, result: MethodResult): void {
    const httpTriggerURI: string = call.argument('httpTriggerURI') as string;
    if (!httpTriggerURI) {
      result.error("-1", "httpTriggerURI 不能为空", null);
      return;
    }

    const trigger = parseTriggerURI(httpTriggerURI);
    const rawParams: Object | null = call.argument('functionParameters') as Object | null;

    let params: cloudFunction.FunctionParams = {
      name: trigger.name,
      data: convertFlutterParams(rawParams),
      timeout: resolveTimeoutMs(call),
    };
    if (trigger.version) {
      params.version = trigger.version;
    }

    cloudFunction.call(params).then((res: cloudFunction.FunctionResult) => {
      // 返回结果序列化为字符串，与 Android/iOS 的 FunctionResult.getValue() 行为一致
      const value = res.result;
      if (typeof value === 'string') {
        result.success(value);
      } else {
        result.success(JSON.stringify(value));
      }
    }).catch((err: BusinessError) => {
      const errorCode = err.code !== undefined ? String(err.code) : "-1";
      const errorMessage = err.message || "云函数调用失败";
      result.error(errorCode, errorMessage, null);
    });
  }
}
