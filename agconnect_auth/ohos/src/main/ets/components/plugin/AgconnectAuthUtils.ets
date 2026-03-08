import { MethodResult } from '@ohos/flutter_ohos';
import { AuthUser, VerifyCodeParam, VerifyCodeAction } from '@hw-agconnect/auth';
import { BusinessError } from '@kit.BasicServicesKit';
import { providerKindToDartIndex } from './AgconnectAuthProviderMap';

/**
 * 从 call.args 或嵌套参数中安全获取值。
 * Flutter 传来的参数可能是 Map 或普通对象，需要统一处理。
 * @param obj 参数对象（可能是 Map 或 Record）
 * @param key 要获取的键
 * @returns 对应的值，不存在时返回 null
 */
export function safeGet(obj: Object, key: string): Object | null {
  if (obj instanceof Map) {
    let mapObj = obj as Map<string, Object>;
    return mapObj.get(key) ?? null;
  }
  let record = obj as Record<string, Object>;
  return record[key] ?? null;
}

/**
 * 将 AuthUser 对象转换为 Map 返回给 Flutter。
 * @param user 鸿蒙 AGC Auth 用户对象，可为 null
 * @returns 包含用户字段的 Record，user 为 null 时返回 null
 */
export function mapFromUser(user: AuthUser | null): Record<string, Object> | null {
  if (user == null) {
    return null;
  }
  let result: Record<string, Object> = {};
  result['isAnonymous'] = user.isAnonymous();
  result['uid'] = user.getUid();
  result['email'] = user.getEmail();
  result['phone'] = user.getPhone();
  result['displayName'] = user.getDisplayName();
  result['photoUrl'] = user.getPhotoUrl();
  // Dart 侧期望 int（AuthProviderType 枚举 index），鸿蒙 SDK 返回 string
  result['providerId'] = providerKindToDartIndex(user.getProviderId());
  result['providerInfo'] = user.getProviderInfo();
  result['emailVerified'] = user.getEmailVerified();
  result['passwordSet'] = user.getPasswordSetted();
  return result;
}

/**
 * 统一错误处理：将 BusinessError 转成 Flutter PlatformException。
 * @param result Flutter MethodResult 回调
 * @param err 鸿蒙侧 BusinessError
 */
export function handleError(result: MethodResult, err: BusinessError): void {
  let details: Record<string, Object> = {};
  details['exceptionCode'] = err.code;
  result.error(String(err.code), err.message, details);
}

/**
 * 构造邮箱验证码请求参数。
 * @param args Flutter 侧传入的参数（可能是 Map 或 Record）
 * @returns 鸿蒙 requestVerifyCode 所需的 VerifyCodeParam
 */
export function buildEmailVerifyCodeParam(args: Object): VerifyCodeParam {
  let settings = safeGet(args, 'settings') as Object;
  // action: 0=注册登录, 1=重置密码
  let action: VerifyCodeAction = (safeGet(settings, 'action') as number) === 0
    ? VerifyCodeAction.REGISTER_LOGIN
    : VerifyCodeAction.RESET_PASSWORD;
  let localeLanguage = safeGet(settings, 'localeLanguage') as string;
  let localeCountry = safeGet(settings, 'localeCountry') as string;
  let lang: string = localeLanguage
    ? (localeCountry ? `${localeLanguage}_${localeCountry}` : localeLanguage)
    : 'zh_CN';
  let email = safeGet(args, 'email') as string;
  let sendInterval = safeGet(settings, 'sendInterval') as number;

  let param: VerifyCodeParam = {
    verifyCodeType: { kind: 'email', email: email },
    action: action,
    lang: lang,
    sendInterval: sendInterval,
  };
  return param;
}

/**
 * 构造手机验证码请求参数。
 * @param args Flutter 侧传入的参数（可能是 Map 或 Record）
 * @returns 鸿蒙 requestVerifyCode 所需的 VerifyCodeParam
 */
export function buildPhoneVerifyCodeParam(args: Object): VerifyCodeParam {
  let settings = safeGet(args, 'settings') as Object;
  let action: VerifyCodeAction = (safeGet(settings, 'action') as number) === 0
    ? VerifyCodeAction.REGISTER_LOGIN
    : VerifyCodeAction.RESET_PASSWORD;
  let localeLanguage = safeGet(settings, 'localeLanguage') as string;
  let localeCountry = safeGet(settings, 'localeCountry') as string;
  let lang: string = localeLanguage
    ? (localeCountry ? `${localeLanguage}_${localeCountry}` : localeLanguage)
    : 'zh_CN';
  let countryCode = safeGet(args, 'countryCode') as string;
  let phoneNumber = safeGet(args, 'phoneNumber') as string;
  let sendInterval = safeGet(settings, 'sendInterval') as number;

  let param: VerifyCodeParam = {
    verifyCodeType: { kind: 'phone', phoneNumber: phoneNumber, countryCode: countryCode },
    action: action,
    lang: lang,
    sendInterval: sendInterval,
  };
  return param;
}
