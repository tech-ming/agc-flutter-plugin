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

/**
 * AGConnect 远程配置 Flutter 插件 - HarmonyOS 平台实现
 *
 * 桥接 Dart 层 MethodChannel 调用至 @hw-agconnect/remoteconfig-ohos SDK。
 *
 * 初始化流程：
 * 1. onAttachedToEngine 中通过 binding.getApplicationContext() 获取上下文
 * 2. 调用 agconnect.instance().init(context) 初始化老版 AGC SDK（core-ohos）
 * 3. 获取 remoteConfig 实例并调用 initialized() 加载本地缓存
 *
 * MethodChannel 名称: com.huawei.flutter/agconnect_remote_config
 * （与 Android/iOS 保持一致）
 */
export default class AgconnectRemoteConfigPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  /** 远程配置实例，在 onAttachedToEngine 时获取并初始化 */
  private config: AGConnectConfig | null = null;
  /** 标记 initialized() 是否已完成 */
  private initPromise: Promise<void> | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "AgconnectRemoteConfigPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    // 通道名称与 Dart 层 / Android / iOS 保持一致
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "com.huawei.flutter/agconnect_remote_config");
    this.channel.setMethodCallHandler(this);

    // 初始化 AGC core SDK（remoteconfig-ohos 依赖老版架构）
    // agconnect-services.json 需放置在 rawfile 目录下，SDK 会自动读取
    const context = binding.getApplicationContext();
    try {
      agconnect.instance().init(context);
    } catch (e) {
      // 可能已被其他插件初始化过，忽略重复初始化错误
      console.warn('[AgconnectRemoteConfigPlugin] AGC core init:', JSON.stringify(e));
    }

    // 获取远程配置实例并执行初始化（加载本地缓存）
    try {
      const config = agconnect.remoteConfig();
      this.config = config;
      this.initPromise = config.initialized();
    } catch (e) {
      console.error('[AgconnectRemoteConfigPlugin] 获取 remoteConfig 实例失败:', JSON.stringify(e));
    }
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
    }
    this.config = null;
    this.initPromise = null;
  }

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
        // ohos SDK 不支持 setDeveloperMode，与 iOS 行为一致，直接返回成功
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * 确保初始化完成后再执行操作
   * ohos SDK 需要先调用 initialized() 加载本地缓存数据
   */
  private async ensureInitialized(): Promise<void> {
    if (this.initPromise) {
      await this.initPromise;
    }
  }

  /**
   * 设置本地默认参数
   * Dart 层传入 { defaults: Map<String, String> }
   *
   * 注意：Flutter MethodChannel 在 OHOS 侧将 Dart Map 解码为 ArkTS 的
   * Map<Any, Any>（ES Map），不是 JS Object/Record，因此不能用 Object.keys()，
   * 必须用 Map.forEach() 遍历。
   */
  private async handleApplyDefaults(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      await this.ensureInitialized();
      const config = this.getConfigOrThrow();
      // MethodChannel 传来的实际类型是 Map<string, string>，不是 Record
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

  /**
   * 应用上次从云端获取的配置
   * 先调用 loadLastFetched() 获取缓存的 ConfigValue，再调用 apply() 生效
   */
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

  /**
   * 从云端获取最新配置
   * Dart 层传入 { intervalSeconds: number? }
   */
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

  /**
   * 获取指定 key 的 String 值
   * Dart 层传入 { key: string }
   */
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
   * 获取指定 key 值的来源
   * Dart 层传入 { key: string }
   * 返回值：0=initial(STATIC), 1=local(DEFAULT), 2=remote(REMOTE)
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

  /**
   * 获取合并后的所有配置（默认值 + 云端值）
   * 返回 Map<string, Object> 给 Dart 层
   *
   * 直接返回 Map（StandardMessageCodec 会将 ES Map 编码为 Dart Map）。
   */
  private handleGetMergedAll(result: MethodResult): void {
    try {
      const config = this.getConfigOrThrow();
      const mergedMap: Map<string, Object> = config.getMergedAll();
      result.success(mergedMap);
    } catch (e) {
      this.handleError(e, result);
    }
  }

  /**
   * 清空所有缓存数据
   */
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

  /**
   * 设置自定义属性
   * Dart 层传入 { customAttributes: Map<String, String> }
   *
   * 同 handleApplyDefaults，MethodChannel 传来的是 ES Map，不是 Record。
   */
  private async handleSetCustomAttributes(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      await this.ensureInitialized();
      const config = this.getConfigOrThrow();
      // MethodChannel 传来的实际类型是 Map<string, string>
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

  /**
   * 获取自定义属性
   * 返回 Map<string, string> 给 Dart 层
   *
   * 直接返回 Map，StandardMessageCodec 会将 ES Map 编码为 Dart Map。
   */
  private async handleGetCustomAttributes(result: MethodResult): Promise<void> {
    try {
      await this.ensureInitialized();
      const config = this.getConfigOrThrow();
      const attrMap: Map<string, string> = await config.getCustomAttributes();
      // 直接返回 Map
      result.success(attrMap);
    } catch (e) {
      this.handleError(e, result);
    }
  }

  /**
   * 获取配置实例，若未初始化则抛异常
   */
  private getConfigOrThrow(): AGConnectConfig {
    if (!this.config) {
      throw new Error('AGConnectConfig 未初始化，请确保 agconnect.instance().init(context) 已执行');
    }
    return this.config;
  }

  /**
   * SOURCE 字符串 → Dart 层对应的数字序号
   * STATIC(初始值) → 0, DEFAULT(本地默认值) → 1, REMOTE(云端值) → 2
   */
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

  /**
   * 统一错误处理
   * 将原生异常转换为 Flutter PlatformException 格式
   */
  private handleError(e: Object, result: MethodResult): void {
    if (e instanceof Error) {
      const error = e as Error;
      // 尝试提取 AGC 错误码
      const agcError = e as Object as Record<string, Object>;
      const code = agcError['code'] !== undefined ? String(agcError['code']) : '-1';
      const message = error.message || '远程配置操作失败';
      result.error(code, message, null);
    } else {
      result.error('-1', String(e), null);
    }
  }
}
