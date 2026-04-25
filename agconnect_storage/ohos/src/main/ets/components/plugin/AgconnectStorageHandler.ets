import { MethodCall, MethodResult } from '@ohos/flutter_ohos';

/**
 * 处理 AGCStorage# 前缀的方法调用。
 *
 * 鸿蒙端 cloudStorage API 没有 AGCStorageManagement 对应的配置 API
 * （如 setRetryTimes、getRetryTimes、setMaxRequestTimeout 等），
 * 这些方法返回默认值或 notImplemented。
 */
export class AgconnectStorageHandler {
  constructor() {
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    let method = (call.method as string).split('#')[1];
    switch (method) {
      case 'referenceFromUrl':
        // 鸿蒙 CloudStorage 无 referenceFromUrl API
        result.notImplemented();
        break;
      case 'getArea':
        // 鸿蒙 CloudStorage 无 getArea API，返回默认 CN
        result.success('CN');
        break;
      case 'setRetryTimes':
        // 鸿蒙无对应 API，静默成功
        result.success(true);
        break;
      case 'getRetryTimes':
        // 返回默认值 3
        result.success(3);
        break;
      case 'setMaxRequestTimeout':
        result.success(true);
        break;
      case 'getMaxRequestTimeout':
        // 返回默认值 20000ms
        result.success(20000);
        break;
      case 'setMaxUploadTimeout':
        result.success(true);
        break;
      case 'getMaxUploadTimeout':
        // 返回默认值 120000ms
        result.success(120000);
        break;
      case 'setMaxDownloadTimeout':
        result.success(true);
        break;
      case 'getMaxDownloadTimeout':
        // 返回默认值 60000ms
        result.success(60000);
        break;
      default:
        result.notImplemented();
        break;
    }
  }
}
