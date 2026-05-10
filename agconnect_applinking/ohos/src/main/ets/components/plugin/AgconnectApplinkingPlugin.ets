import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  EventChannel,
  EventSink,
  AbilityPluginBinding,
  NewWantListener,
} from '@ohos/flutter_ohos';
import { Want, AbilityConstant } from '@kit.AbilityKit';
import { deferredLink } from '@kit.AppLinkingKit';
import { linkUriToResolvedDataMap, handleError } from './AppLinkingUtils';

/**
 * AGC AppLinking Flutter 插件 - HarmonyOS 平台实现
 *
 * 基于 @kit.AppLinkingKit 提供的真实 API：
 *
 * MethodChannel: com.huawei.agc.flutter.applinking_methodchannel
 * - buildShortAppLinking: 不支持（HarmonyOS @kit.AppLinkingKit 无客户端创建链接 API，
 *   需通过 AGC 控制台或服务端 API 创建聚合链接）
 * - buildLongAppLinking: 不支持（同上）
 *
 * EventChannel: com.huawei.agc.flutter.applinking_eventchannel
 * - onResolvedData: 监听 App Linking 链接数据
 *   数据来源：
 *   1. Ability launchWant.uri（冷启动，应用链接 / 聚合链接拉起时传入的 URI）
 *   2. AbilityPluginBinding.addOnNewWantListener（热启动，onNewWant 自动回调）
 *   3. deferredLink.popDeferredLink()（延迟链接，应用首次启动时获取此前点击的链接）
 *
 * 无需在 EntryAbility 中手动调用任何方法，插件通过 AbilityPluginBinding 自动监听生命周期。
 */
export default class AgconnectApplinkingPlugin implements FlutterPlugin, MethodCallHandler, NewWantListener {
  private channel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private eventSink: EventSink | null = null;
  private abilityBinding: AbilityPluginBinding | null = null;

  /** 缓存的初始链接 URI（从 Ability launchWant 获取，等待 EventChannel 监听后发送） */
  private initialLinkUri: string | null = null;

  getUniqueClassName(): string {
    return "AgconnectApplinkingPlugin";
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    // MethodChannel - 与 Dart 层 AGCAppLinking._channel 名称一致
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(),
      "com.huawei.agc.flutter.applinking_methodchannel"
    );
    this.channel.setMethodCallHandler(this);

    // EventChannel - 与 Dart 层 AGCAppLinking._eventChannel 名称一致
    this.eventChannel = new EventChannel(
      binding.getBinaryMessenger(),
      "com.huawei.agc.flutter.applinking_eventchannel"
    );
    this.eventChannel.setStreamHandler({
      onListen: (_args: Object, sink: EventSink) => {
        this.eventSink = sink;
        this.sendCachedLinkData();
      },
      onCancel: (_args: Object) => {
        this.eventSink = null;
      },
    });
  }

  /**
   * Ability 绑定回调。
   *
   * 1. 获取 UIAbility 的 launchWant.uri 作为冷启动链接
   * 2. 注册 NewWantListener 接收热启动链接（onNewWant 自动回调）
   */
  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityBinding = binding;

    // 1. 获取冷启动链接
    try {
      const ability = binding.getAbility();
      const launchWant = ability.launchWant;
      if (launchWant && launchWant.uri) {
        this.initialLinkUri = launchWant.uri;
        console.info(`[AgconnectApplinkingPlugin] Cold start URI: ${launchWant.uri}`);
      }
    } catch (e) {
      console.warn('[AgconnectApplinkingPlugin] 获取 launchWant.uri 失败:', JSON.stringify(e));
    }

    // 2. 注册 onNewWant 监听，热启动时自动回调 this.onNewWant()
    binding.addOnNewWantListener(this);
  }

  /**
   * Ability 解绑回调。移除 onNewWant 监听。
   */
  onDetachedFromAbility(binding: AbilityPluginBinding): void {
    binding.removeOnNewWantListener(this);
    this.abilityBinding = null;
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
    }
    if (this.eventChannel != null) {
      this.eventChannel.setStreamHandler(null);
    }
    this.eventSink = null;
    this.channel = null;
    this.eventChannel = null;
  }

  /**
   * NewWantListener 实现。
   * 由 flutter_ohos 框架在 onNewWant 时自动回调，无需 EntryAbility 手动调用。
   */
  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    const uri = want?.uri;
    if (uri && uri.length > 0) {
      console.info(`[AgconnectApplinkingPlugin] Hot start URI: ${uri}`);
      this.sendLinkData(uri);
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case "buildShortAppLinking":
        result.error(
          'UNSUPPORTED',
          'HarmonyOS @kit.AppLinkingKit 不支持客户端创建链接，请通过 AGC 控制台创建聚合链接',
          null
        );
        break;
      case "buildLongAppLinking":
        result.error(
          'UNSUPPORTED',
          'HarmonyOS @kit.AppLinkingKit 不支持客户端创建链接，请通过 AGC 控制台创建聚合链接',
          null
        );
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * 发送链接数据到 Flutter 侧。
   * 如果 EventChannel 尚未监听，缓存链接等待。
   */
  private sendLinkData(uri: string): void {
    if (this.eventSink) {
      const map = linkUriToResolvedDataMap(uri);
      this.eventSink.success(map);
    } else {
      // EventChannel 尚未监听，缓存链接等待
      this.initialLinkUri = uri;
    }
  }

  /**
   * 向 Flutter 端发送缓存的链接数据。
   *
   * 数据来源（按优先级）：
   * 1. initialLinkUri — Ability launchWant 或 onNewWant 中的链接 URI
   * 2. deferredLink.popDeferredLink() — 延迟链接（应用首次启动时获取此前点击的链接）
   */
  private sendCachedLinkData(): void {
    // 1. 发送缓存的链接
    if (this.initialLinkUri) {
      const map = linkUriToResolvedDataMap(this.initialLinkUri);
      this.eventSink?.success(map);
      this.initialLinkUri = null;
    }

    // 2. 尝试获取延迟链接
    deferredLink.popDeferredLink()
      .then((link: string) => {
        if (link && this.eventSink) {
          const map = linkUriToResolvedDataMap(link);
          this.eventSink.success(map);
        }
      })
      .catch(() => {
        // 延迟链接获取失败（无缓存链接或已获取过），静默忽略
      });
  }
}
