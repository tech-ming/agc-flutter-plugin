import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { AgconnectClouddbMethodHandler } from './AgconnectClouddbMethodHandler';
import { SchemaRegistry } from './AgconnectClouddbUtils';
import { ClouddbLocalCache } from './ClouddbLocalCache';

/**
 * AGConnect CloudDB Flutter 插件 - HarmonyOS 平台实现
 * MethodChannel 名称与 Dart 层保持一致：com.huawei.agconnectclouddb/methodChannel/
 */
export default class AgconnectClouddbPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private methodHandler: AgconnectClouddbMethodHandler = new AgconnectClouddbMethodHandler();

  constructor() {
  }

  getUniqueClassName(): string {
    return "AgconnectClouddbPlugin";
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    // MethodChannel 名称必须与 Dart 层一致
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "com.huawei.agconnectclouddb/methodChannel/");
    this.channel.setMethodCallHandler(this);

    let context = binding.getApplicationContext();

    // 从 rawfile 读取 schema.json，构建字段类型映射表 + 初始化本地缓存
    this._loadSchemaAndInitCache(context);
  }

  /**
   * 从 rawfile/schema.json 加载对象类型的字段信息，并初始化本地缓存。
   *
   * Android 端通过强类型类 + 反射获取字段类型（Date、String、Integer 等），
   * OHos 端使用 DynamicDatabaseObject 无法反射，因此从 schema.json 构建映射表，
   * 使 Date ↔ 毫秒时间戳 的双向转换与 Android 对齐。
   *
   * 同时将 schema.json 传给 ClouddbLocalCache，用于动态建表和离线缓存。
   */
  private _loadSchemaAndInitCache(context: common.Context): void {
    try {
      const resourceManager = context.resourceManager;
      const rawFile = resourceManager.getRawFileContentSync('schema.json');
      const decoder = util.TextDecoder.create('utf-8');
      const schemaJson = decoder.decodeWithStream(rawFile);

      // 1. 加载 Schema 到 SchemaRegistry（原有逻辑）
      SchemaRegistry.loadFromJson(schemaJson);

      // 2. 初始化本地缓存并注入到 MethodHandler -> ZoneManager
      let localCache = new ClouddbLocalCache();
      localCache.init(context, schemaJson).then(() => {
        this.methodHandler.setLocalCache(localCache);
      }).catch((err: Error) => {
        console.error('[AgconnectClouddbPlugin] 本地缓存初始化失败:', err.message);
      });
    } catch (e) {
      console.error('[AgconnectClouddbPlugin] 加载 schema.json 失败:', JSON.stringify(e));
    }
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    this.methodHandler.onMethodCall(call, result);
  }
}
