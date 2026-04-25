import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { AgconnectStorageHandler } from './AgconnectStorageHandler';
import { AgconnectStorageReferenceHandler } from './AgconnectStorageReferenceHandler';
import { AgconnectStorageTaskManager } from './AgconnectStorageTaskManager';

/**
 * AGConnect CloudStorage 鸿蒙侧插件入口。
 * MethodChannel 名称与 Dart 层保持一致：com.huawei.agconnect.cloudstorage/methodChannel/
 *
 * 方法路由规则（与 Android 端保持一致）：
 * - AGCStorage#xxx       → AgconnectStorageHandler（存储实例级配置方法）
 * - AGCStorageReference#xxx → AgconnectStorageReferenceHandler（文件操作方法）
 * - AGCStorageTask#xxx   → AgconnectStorageTaskManager（任务控制方法）
 */
export default class AgconnectCloudstoragePlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private storageHandler: AgconnectStorageHandler | null = null;
  private referenceHandler: AgconnectStorageReferenceHandler | null = null;
  private taskManager: AgconnectStorageTaskManager | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "AgconnectCloudstoragePlugin";
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(),
      "com.huawei.agconnect.cloudstorage/methodChannel/",
    );
    this.channel.setMethodCallHandler(this);

    // 初始化各处理器
    this.taskManager = new AgconnectStorageTaskManager();
    this.storageHandler = new AgconnectStorageHandler();
    this.referenceHandler = new AgconnectStorageReferenceHandler(binding, this.taskManager);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
    }
    this.channel = null;
    this.storageHandler = null;
    this.referenceHandler = null;
    this.taskManager = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    let method = call.method as string;

    try {
      if (method.startsWith('AGCStorage#')) {
        this.storageHandler?.onMethodCall(call, result);
      } else if (method.startsWith('AGCStorageReference#')) {
        this.referenceHandler?.onMethodCall(call, result);
      } else if (method.startsWith('AGCStorageTask#')) {
        this.taskManager?.onMethodCall(call, result);
      } else {
        result.notImplemented();
      }
    } catch (e) {
      let errDetails: Record<string, Object> = {};
      errDetails['exceptionType'] = 'PluginException';
      result.error('UNKNOWN', (e as Error).message ?? 'Unknown error', errDetails);
    }
  }
}
