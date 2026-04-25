import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import agconnect from '@hw-agconnect/api-ohos';
import '@hw-agconnect/core-ohos';
import '@hw-agconnect/remoteconfig-ohos';
import { AGConnectConfig, SOURCE } from '@hw-agconnect/remoteconfig-ohos';
import { util } from '@kit.ArkTS';
import common from '@ohos.app.ability.common';

/**
 * AGConnect 远程配置 Flutter 插件（HarmonyOS 实现）。
 * 负责桥接 Dart 层 MethodChannel 到 OHOS 侧 AGC SDK。
 */
export default class AgconnectRemoteConfigPlugin implements FlutterPlugin, MethodCallHandler {
  /** 自定义 AGC 配置文件名（位于 AppScope/resources/rawfile/ 目录）。 */
  private static readonly CUSTOM_AGC_CONFIG_FILE_NAME: string = 'agconnect-services-android.json';

  /** MethodChannel 通道实例。 */
  private channel: MethodChannel | null = null;

  /** 远程配置实例。 */
  private config: AGConnectConfig | null = null;

  /** initialized() 的异步句柄，确保后续调用前完成初始化。 */
  private initPromise: Promise<void> | null = null;

  constructor() {
  }

  /** 返回插件唯一类名。 */
  getUniqueClassName(): string {
    return 'AgconnectRemoteConfigPlugin';
  }

  /**
   * 插件挂载入口。
   * 1. 创建 MethodChannel。
   * 2. 初始化 AGC Core（优先读取自定义 json）。
   * 3. 获取 remoteConfig 实例并触发 initialized()。
   */
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.huawei.flutter/agconnect_remote_config');
    this.channel.setMethodCallHandler(this);

    const context = binding.getApplicationContext();
    this.initAgcCore(context);

    try {
      const config = agconnect.remoteConfig();
      this.config = config;
      this.initPromise = config.initialized();
    } catch (e) {
      console.error('[AgconnectRemoteConfigPlugin] 获取 remoteConfig 实例失败:', JSON.stringify(e));
    }
  }

  /** 插件卸载入口，释放通道与缓存引用。 */
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
    }
    this.config = null;
    this.initPromise = null;
  }

  /**
   * 统一处理 Dart 侧 MethodChannel 调用。
   */
  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'applyDefaults':
        this.handleApplyDefaults(call, result);
        break;
      case 'applyLastFetched':
        this.handleApplyLastFetched(result);
        break;
      case 'fetch':
        this.handleFetch(call, result);
        break;
      case 'getValue':
        this.handleGetValue(call, result);
        break;
      case 'getSource':
        this.handleGetSource(call, result);
        break;
      case 'getMergedAll':
        this.handleGetMergedAll(result);
        break;
      case 'clearAll':
        this.handleClearAll(result);
        break;
      case 'setCustomAttributes':
        this.handleSetCustomAttributes(call, result);
        break;
      case 'getCustomAttributes':
        this.handleGetCustomAttributes(result);
        break;
      case 'setDeveloperMode':
        // OHOS SDK 不支持 setDeveloperMode，与 iOS 保持一致：直接返回成功。
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * 初始化 AGC Core。
   * 优先使用 rawfile/agconnect-services-android.json。
   * 若失败则回退默认初始化（SDK 自动读取 rawfile/agconnect-services.json）。
   */
  private initAgcCore(context: common.Context): void {
    try {
      const config = this.readCustomAgcConfig(context);
      agconnect.instance().init(context, config);
      console.info('[AgconnectRemoteConfigPlugin] 使用自定义配置初始化 AGC Core 成功');
    } catch (e) {
      // HACK: 自定义配置缺失或格式异常时回退默认初始化，保证插件可用；后续可加构建期校验。
      console.warn('[AgconnectRemoteConfigPlugin] 自定义配置初始化失败，回退默认初始化:', JSON.stringify(e));
      try {
        agconnect.instance().init(context);
      } catch (initError) {
        // 可能已被其他插件初始化，忽略重复初始化错误。
        console.warn('[AgconnectRemoteConfigPlugin] AGC Core 初始化提示:', JSON.stringify(initError));
      }
    }
  }

  /**
   * 从 rawfile 读取自定义 AGC 配置并解析为 JSON 对象。
   */
  private readCustomAgcConfig(context: common.Context): Object {
    const rawFile = context.resourceManager.getRawFileContentSync(
      AgconnectRemoteConfigPlugin.CUSTOM_AGC_CONFIG_FILE_NAME
    );
    const decoder = util.TextDecoder.create('utf-8');
    const jsonText = decoder.decodeWithStream(rawFile);
    return JSON.parse(jsonText) as Object;
  }

  /**
   * 确保 remoteConfig 完成 initialized()。
   */
  private async ensureInitialized(): Promise<void> {
    if (this.initPromise) {
      await this.initPromise;
    }
  }

  /**
   * 设置本地默认参数。
   * 注意：OHOS 侧 MethodChannel 的 Map 会映射为 ES Map，需要用 forEach 遍历。
   */
  private async handleApplyDefaults(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      await this.ensureInitialized();
      const config = this.getConfigOrThrow();
      const defaults = call.argument('defaults') as Map<string, string> | null;

      if (defaults) {
        const map = new Map<string, string | number | boolean>();
        defaults.forEach((value: string, key: string) => {
          map.set(key, value);
        });
        await config.applyDefault(map);
      }
      result.success(null);
    } catch (e) {
      this.handleError(e, result);
    }
  }

  /** 应用上次拉取到的云端配置。 */
  private async handleApplyLastFetched(result: MethodResult): Promise<void> {
    try {
      await this.ensureInitialized();
      const config = this.getConfigOrThrow();
      const configValues = await config.loadLastFetched();
      await config.apply(configValues);
      result.success(null);
    } catch (e) {
      this.handleError(e, result);
    }
  }

  /** 拉取最新远程配置，可选传入最小拉取间隔（秒）。 */
  private async handleFetch(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      await this.ensureInitialized();
      const config = this.getConfigOrThrow();
      const intervalSeconds: number | null = call.argument('intervalSeconds') as number | null;

      if (intervalSeconds != null && intervalSeconds != undefined) {
        await config.fetch(intervalSeconds);
      } else {
        await config.fetch();
      }
      result.success(null);
    } catch (e) {
      this.handleError(e, result);
    }
  }

  /** 获取指定 key 的字符串值。 */
  private handleGetValue(call: MethodCall, result: MethodResult): void {
    try {
      const config = this.getConfigOrThrow();
      const key: string = call.argument('key') as string;
      const value = config.getValueAsString(key);
      result.success(value);
    } catch (e) {
      this.handleError(e, result);
    }
  }

  /**
   * 获取指定 key 的值来源：
   * 0=STATIC(初始)，1=DEFAULT(本地默认)，2=REMOTE(云端)。
   */
  private handleGetSource(call: MethodCall, result: MethodResult): void {
    try {
      const config = this.getConfigOrThrow();
      const key: string = call.argument('key') as string;
      const source: SOURCE = config.getSource(key);
      result.success(this.sourceToOrdinal(source));
    } catch (e) {
      this.handleError(e, result);
    }
  }

  /** 获取合并后的全部配置（本地默认 + 云端）。 */
  private handleGetMergedAll(result: MethodResult): void {
    try {
      const config = this.getConfigOrThrow();
      const mergedMap: Map<string, Object> = config.getMergedAll();
      result.success(mergedMap);
    } catch (e) {
      this.handleError(e, result);
    }
  }

  /** 清空本地缓存配置。 */
  private async handleClearAll(result: MethodResult): Promise<void> {
    try {
      await this.ensureInitialized();
      const config = this.getConfigOrThrow();
      await config.clearAll();
      result.success(null);
    } catch (e) {
      this.handleError(e, result);
    }
  }

  /** 设置自定义属性。 */
  private async handleSetCustomAttributes(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      await this.ensureInitialized();
      const config = this.getConfigOrThrow();
      const attrs = call.argument('customAttributes') as Map<string, string> | null;

      if (attrs) {
        const map = new Map<string, string>();
        attrs.forEach((value: string, key: string) => {
          map.set(key, value);
        });
        await config.setCustomAttributes(map);
      }
      result.success(null);
    } catch (e) {
      this.handleError(e, result);
    }
  }

  /** 获取自定义属性。 */
  private async handleGetCustomAttributes(result: MethodResult): Promise<void> {
    try {
      await this.ensureInitialized();
      const config = this.getConfigOrThrow();
      const attrMap: Map<string, string> = await config.getCustomAttributes();
      result.success(attrMap);
    } catch (e) {
      this.handleError(e, result);
    }
  }

  /** 获取配置实例，若未初始化则抛错。 */
  private getConfigOrThrow(): AGConnectConfig {
    if (!this.config) {
      throw new Error('AGConnectConfig 未初始化，请确保 agconnect.instance().init(context) 已执行');
    }
    return this.config;
  }

  /** 将 SOURCE 枚举映射为 Dart 侧约定的序号。 */
  private sourceToOrdinal(source: SOURCE): number {
    switch (source) {
      case 'STATIC':
        return 0;
      case 'DEFAULT':
        return 1;
      case 'REMOTE':
        return 2;
      default:
        return 0;
    }
  }

  /** 统一异常转换为 Flutter PlatformException。 */
  private handleError(e: Object, result: MethodResult): void {
    if (e instanceof Error) {
      const error = e as Error;
      const agcError = e as Object as Record<string, Object>;
      const code = agcError['code'] !== undefined ? String(agcError['code']) : '-1';
      const message = error.message || '远程配置操作失败';
      result.error(code, message, null);
    } else {
      result.error('-1', String(e), null);
    }
  }
}
