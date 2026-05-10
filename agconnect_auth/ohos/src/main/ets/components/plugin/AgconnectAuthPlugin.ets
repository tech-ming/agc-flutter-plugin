import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  AbilityPluginBinding,
  EventChannel,
  EventSink,
} from '@ohos/flutter_ohos';
import { AgconnectAuthMethodHandler } from './AgconnectAuthMethodHandler';
import auth from '@hw-agconnect/auth';
import { cloudCommon } from '@kit.CloudFoundationKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

/** AGC Auth 鸿蒙侧插件入口，对应 Dart MethodChannel: com.huawei.flutter/agconnect_auth */
export default class AgconnectAuthPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  // 所有方法实现委托给 handler，保持本类职责单一
  private readonly handler: AgconnectAuthMethodHandler = new AgconnectAuthMethodHandler();
  // 缓存 FlutterPluginBinding，在 onAttachedToAbility 中使用
  private pluginBinding: FlutterPluginBinding | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "AgconnectAuthPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.pluginBinding = binding;
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "com.huawei.flutter/agconnect_auth");
    this.channel.setMethodCallHandler(this);
    // 注册 EventChannel，响应 Dart 端 tokenChanges() 的 listen/cancel 调用
    // 鸿蒙 Auth SDK 暂无 addTokenListener API，因此仅注册空 handler 避免 MissingPluginException
    this.eventChannel = new EventChannel(binding.getBinaryMessenger(), "com.huawei.flutter.event/agconnect_auth");
    this.eventChannel.setStreamHandler({
      onListen: (_args: Object, _sink: EventSink) => {
        // TODO: 鸿蒙 Auth SDK 提供 addTokenListener 后，在此推送 token 变化事件
      },
      onCancel: (_args: Object) => {
      },
    });
  }

  /**
   * Ability 绑定回调，可获取 UIAbilityContext。
   *
   * 华为账号登录（hwid）内部的 AuthenticationController 需要 UIAbilityContext
   * 才能弹出授权界面。ApplicationContext 不具备 UI 能力，会导致
   * "Incorrect context parameter type" 错误。
   *
   * 因此将 Auth SDK 初始化延迟到此处，使用 UIAbilityContext 替代 ApplicationContext。
   */
  onAttachedToAbility(binding: AbilityPluginBinding): void {
    const abilityContext = binding.getAbility().context as common.UIAbilityContext;
    this._initAuthSdk(abilityContext);
  }

  /**
   * 从 rawfile 读取 agconnect-services.json 并初始化 Auth SDK。
   *
   * 使用 UIAbilityContext 初始化，确保华为账号登录等需要 UI 能力的功能正常工作。
   *
   * 同时将 AuthProvider 注入到 CloudFoundationKit，使 CloudDB、CloudStorage 等
   * 服务能识别当前用户的认证身份（否则 Authenticated 角色的操作会 permission denied）。
   */
  private _initAuthSdk(context: common.UIAbilityContext): void {
    try {
      const resourceManager = context.resourceManager;
      // rawfile 读取返回 Uint8Array
      const rawFile = resourceManager.getRawFileContentSync('agconnect-services.json');
      const decoder = util.TextDecoder.create('utf-8');
      const json = decoder.decodeWithStream(rawFile);
      auth.init(context, json);

      // 将 AuthProvider 注入到 CloudFoundationKit
      let provider: cloudCommon.AuthProvider = auth.getAuthProvider();
      cloudCommon.init({ authProvider: provider });
    } catch (e) {
      console.error('[AgconnectAuthPlugin] 初始化 Auth SDK 失败:', JSON.stringify(e));
    }
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.pluginBinding = null;
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
    if (this.eventChannel != null) {
      this.eventChannel.setStreamHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case "signIn":
        this.handler.handleSignIn(call, result);
        break;
      case "signInAnonymously":
        this.handler.handleSignInAnonymously(result);
        break;
      case "signOut":
        this.handler.handleSignOut(result);
        break;
      case "deleteUser":
        this.handler.handleDeleteUser(result);
        break;
      case "getCurrentUser":
        this.handler.handleGetCurrentUser(result);
        break;
      case "createUserWithEmail":
        this.handler.handleCreateUserWithEmail(call, result);
        break;
      case "createUserWithPhone":
        this.handler.handleCreateUserWithPhone(call, result);
        break;
      case "resetPasswordWithEmail":
        this.handler.handleResetPasswordWithEmail(call, result);
        break;
      case "resetPasswordWithPhone":
        this.handler.handleResetPasswordWithPhone(call, result);
        break;
      case "link":
        this.handler.handleLink(call, result);
        break;
      case "unlink":
        this.handler.handleUnlink(call, result);
        break;
      case "updateProfile":
        this.handler.handleUpdateProfile(call, result);
        break;
      case "updateEmail":
        this.handler.handleUpdateEmail(call, result);
        break;
      case "updatePhone":
        this.handler.handleUpdatePhone(call, result);
        break;
      case "updatePassword":
        this.handler.handleUpdatePassword(call, result);
        break;
      case "reauthenticate":
        this.handler.handleReauthenticate(call, result);
        break;
      case "getUserExtra":
        this.handler.handleGetUserExtra(result);
        break;
      case "getToken":
        this.handler.handleGetToken(call, result);
        break;
      case "requestEmailVerifyCode":
        this.handler.handleRequestEmailVerifyCode(call, result);
        break;
      case "requestAuthEmailVerifyCode":
        this.handler.handleRequestAuthEmailVerifyCode(call, result);
        break;
      case "requestPhoneVerifyCode":
        this.handler.handleRequestPhoneVerifyCode(call, result);
        break;
      case "requestAuthPhoneVerifyCode":
        this.handler.handleRequestAuthPhoneVerifyCode(call, result);
        break;
      case "getSupportedAuthList":
        this.handler.handleGetSupportedAuthList(result);
        break;
      // TODO: setAutoCollectionAAID / isAutoCollectionAAID 鸿蒙 Auth SDK 暂无对应 API，返回未实现
      default:
        result.notImplemented();
        break;
    }
  }
}
