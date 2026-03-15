import { MethodCall, MethodResult } from '@ohos/flutter_ohos';
import auth from '@hw-agconnect/auth';
import {
  PasswordInfo,
  EmailInfo,
  PhoneInfo,
  UserProfileInfo,
  EmailCredentialInfo,
  PhoneCredentialInfo,
} from '@hw-agconnect/auth';
import { BusinessError } from '@kit.BasicServicesKit';
import { mapFromUser, handleError, buildEmailVerifyCodeParam, buildPhoneVerifyCodeParam, safeGet } from './AgconnectAuthUtils';
import { buildSignInParam, buildCredentialInfo } from './AgconnectAuthCredential';
import { dartIndexToProviderKind } from './AgconnectAuthProviderMap';

/** 所有 AGC Auth MethodChannel 方法的具体实现 */
export class AgconnectAuthMethodHandler {
  constructor() {
  }

  /** 第三方凭证登录 */
  handleSignIn(call: MethodCall, result: MethodResult): void {
    let credentialMap = call.argument('credential') as Object;
    let signInParam = buildSignInParam(credentialMap);
    if (signInParam == null) {
      let errDetails: Record<string, Object> = {};
      result.error("", "不支持的认证提供商", errDetails);
      return;
    }
    auth.signIn(signInParam)
      .then((signInResult) => {
        result.success(mapFromUser(signInResult.getUser()));
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 匿名登录 */
  handleSignInAnonymously(result: MethodResult): void {
    auth.signInAnonymously()
      .then((signInResult) => {
        result.success(mapFromUser(signInResult.getUser()));
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 登出 */
  handleSignOut(result: MethodResult): void {
    auth.signOut()
      .then(() => {
        result.success(null);
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 删除当前用户 */
  handleDeleteUser(result: MethodResult): void {
    auth.deleteUser()
      .then(() => {
        result.success(null);
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 获取当前登录用户 */
  handleGetCurrentUser(result: MethodResult): void {
    auth.getCurrentUser()
      .then((user) => {
        result.success(mapFromUser(user));
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 邮箱注册账户 */
  handleCreateUserWithEmail(call: MethodCall, result: MethodResult): void {
    let credentialInfo: EmailCredentialInfo = {
      kind: 'email',
      email: call.argument('email') as string,
      password: call.argument('password') as string,
      verifyCode: call.argument('verifyCode') as string,
    };
    auth.createUser(credentialInfo)
      .then((signInResult) => {
        result.success(mapFromUser(signInResult.getUser()));
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 手机号注册账户 */
  handleCreateUserWithPhone(call: MethodCall, result: MethodResult): void {
    let credentialInfo: PhoneCredentialInfo = {
      kind: 'phone',
      countryCode: call.argument('countryCode') as string,
      phoneNumber: call.argument('phoneNumber') as string,
      password: call.argument('password') as string,
      verifyCode: call.argument('verifyCode') as string,
    };
    auth.createUser(credentialInfo)
      .then((signInResult) => {
        result.success(mapFromUser(signInResult.getUser()));
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 通过邮箱重置密码 */
  handleResetPasswordWithEmail(call: MethodCall, result: MethodResult): void {
    let credentialInfo: EmailCredentialInfo = {
      kind: 'email',
      email: call.argument('email') as string,
      password: call.argument('password') as string,
      verifyCode: call.argument('verifyCode') as string,
    };
    auth.resetPassword(credentialInfo)
      .then(() => {
        result.success(null);
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 通过手机号重置密码 */
  handleResetPasswordWithPhone(call: MethodCall, result: MethodResult): void {
    let credentialInfo: PhoneCredentialInfo = {
      kind: 'phone',
      countryCode: call.argument('countryCode') as string,
      phoneNumber: call.argument('phoneNumber') as string,
      password: call.argument('password') as string,
      verifyCode: call.argument('verifyCode') as string,
    };
    auth.resetPassword(credentialInfo)
      .then(() => {
        result.success(null);
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 关联新的认证方式 */
  handleLink(call: MethodCall, result: MethodResult): void {
    let credentialMap = call.argument('credential') as Object;
    let credentialInfo = buildCredentialInfo(credentialMap);
    if (credentialInfo == null) {
      let errDetails: Record<string, Object> = {};
      result.error("", "不支持的认证提供商", errDetails);
      return;
    }
    auth.getCurrentUser()
      .then((user) => {
        if (user == null) {
          let errDetails: Record<string, Object> = {};
          result.error("", "当前无登录用户", errDetails);
          return;
        }
        user.link(credentialInfo)
          .then((signInResult) => {
            result.success(mapFromUser(signInResult.getUser()));
          })
          .catch((err: BusinessError) => {
            handleError(result, err);
          });
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 解除认证关联 */
  handleUnlink(call: MethodCall, result: MethodResult): void {
    let providerKind = dartIndexToProviderKind(call.argument('provider') as number);
    if (providerKind == null) {
      let errDetails: Record<string, Object> = {};
      result.error("", "不支持的认证提供商", errDetails);
      return;
    }
    auth.getCurrentUser()
      .then((user) => {
        if (user == null) {
          let errDetails: Record<string, Object> = {};
          result.error("", "当前无登录用户", errDetails);
          return;
        }
        user.unlink(providerKind!)
          .then((signInResult) => {
            result.success(mapFromUser(signInResult.getUser()));
          })
          .catch((err: BusinessError) => {
            handleError(result, err);
          });
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 更新用户资料（昵称/头像） */
  handleUpdateProfile(call: MethodCall, result: MethodResult): void {
    auth.getCurrentUser()
      .then((user) => {
        if (user == null) {
          let errDetails: Record<string, Object> = {};
          result.error("", "当前无登录用户", errDetails);
          return;
        }
        let profileInfo: UserProfileInfo = {
          displayName: call.argument('displayName') as string,
          photoUrl: call.argument('photoUrl') as string,
        };
        user.updateProfile(profileInfo)
          .then(() => {
            return auth.getCurrentUser();
          })
          .then((updatedUser) => {
            result.success(mapFromUser(updatedUser));
          })
          .catch((err: BusinessError) => {
            handleError(result, err);
          });
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 更新邮箱 */
  handleUpdateEmail(call: MethodCall, result: MethodResult): void {
    let localeLanguage = call.argument('localeLanguage') as string;
    let localeCountry = call.argument('localeCountry') as string;
    let lang: string = (localeLanguage && localeCountry) ? `${localeLanguage}_${localeCountry}` : '';
    auth.getCurrentUser()
      .then((user) => {
        if (user == null) {
          let errDetails: Record<string, Object> = {};
          result.error("", "当前无登录用户", errDetails);
          return;
        }
        let emailInfo: EmailInfo = {
          email: call.argument('email') as string,
          verifyCode: call.argument('verifyCode') as string,
          lang: lang,
        };
        user.updateEmail(emailInfo)
          .then(() => {
            return auth.getCurrentUser();
          })
          .then((updatedUser) => {
            result.success(mapFromUser(updatedUser));
          })
          .catch((err: BusinessError) => {
            handleError(result, err);
          });
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 更新手机号 */
  handleUpdatePhone(call: MethodCall, result: MethodResult): void {
    let localeLanguage = call.argument('localeLanguage') as string;
    let localeCountry = call.argument('localeCountry') as string;
    let lang: string = (localeLanguage && localeCountry) ? `${localeLanguage}_${localeCountry}` : '';
    auth.getCurrentUser()
      .then((user) => {
        if (user == null) {
          let errDetails: Record<string, Object> = {};
          result.error("", "当前无登录用户", errDetails);
          return;
        }
        let phoneInfo: PhoneInfo = {
          phoneNumber: call.argument('phoneNumber') as string,
          countryCode: call.argument('countryCode') as string,
          verifyCode: call.argument('verifyCode') as string,
          lang: lang,
        };
        user.updatePhone(phoneInfo)
          .then(() => {
            return auth.getCurrentUser();
          })
          .then((updatedUser) => {
            result.success(mapFromUser(updatedUser));
          })
          .catch((err: BusinessError) => {
            handleError(result, err);
          });
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 更新密码 */
  handleUpdatePassword(call: MethodCall, result: MethodResult): void {
    let providerKind = dartIndexToProviderKind(call.argument('provider') as number);
    if (providerKind == null) {
      let errDetails: Record<string, Object> = {};
      result.error("", "不支持的认证提供商", errDetails);
      return;
    }
    auth.getCurrentUser()
      .then((user) => {
        if (user == null) {
          let errDetails: Record<string, Object> = {};
          result.error("", "当前无登录用户", errDetails);
          return;
        }
        let passwordInfo: PasswordInfo = {
          password: call.argument('password') as string,
          verifyCode: call.argument('verifyCode') as string,
          providerType: providerKind!,
        };
        user.updatePassword(passwordInfo)
          .then(() => {
            return auth.getCurrentUser();
          })
          .then((updatedUser) => {
            result.success(mapFromUser(updatedUser));
          })
          .catch((err: BusinessError) => {
            handleError(result, err);
          });
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 获取用户扩展信息（创建时间、最后登录时间） */
  handleGetUserExtra(result: MethodResult): void {
    auth.getCurrentUser()
      .then((user) => {
        if (user == null) {
          let errDetails: Record<string, Object> = {};
          result.error("", "当前无登录用户", errDetails);
          return;
        }
        user.getUserExtra()
          .then((extra) => {
            let userExtraMap: Record<string, Object> = {};
            userExtraMap['createTime'] = extra.getCreateTime();
            userExtraMap['lastSignInTime'] = extra.getLastSignInTime();

            let res: Record<string, Object> = {};
            res['userExtra'] = userExtraMap;
            res['user'] = mapFromUser(user) as Object;
            result.success(res);
          })
          .catch((err: BusinessError) => {
            handleError(result, err);
          });
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 获取用户 Token */
  handleGetToken(call: MethodCall, result: MethodResult): void {
    let forceRefresh = call.argument('forceRefresh') as boolean;
    // 鸿蒙侧 getToken 返回 Token，属性为 tokenString 和 expiration
    auth.getToken(forceRefresh)
      .then((tokenResult) => {
        let res: Record<string, Object> = {};
        res['token'] = tokenResult.tokenString;
        res['expirePeriod'] = tokenResult.expiration;
        result.success(res);
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 通过邮件申请验证码（Provider 级别） */
  handleRequestEmailVerifyCode(call: MethodCall, result: MethodResult): void {
    let verifyCodeParam = buildEmailVerifyCodeParam(call.args as Object);
    auth.requestVerifyCode(verifyCodeParam)
      .then((verifyResult) => {
        let res: Record<string, Object> = {};
        res['shortestInterval'] = verifyResult.getShortestInterval();
        res['validityPeriod'] = verifyResult.getValidityPeriod();
        result.success(res);
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /**
   * 通过邮件申请验证码（Auth 实例级别）。
   * 鸿蒙 SDK 统一通过 auth.requestVerifyCode，与 handleRequestEmailVerifyCode 共用同一 API。
   */
  handleRequestAuthEmailVerifyCode(call: MethodCall, result: MethodResult): void {
    this.handleRequestEmailVerifyCode(call, result);
  }

  /** 通过手机号申请验证码（Provider 级别） */
  handleRequestPhoneVerifyCode(call: MethodCall, result: MethodResult): void {
    let verifyCodeParam = buildPhoneVerifyCodeParam(call.args as Object);
    auth.requestVerifyCode(verifyCodeParam)
      .then((verifyResult) => {
        let res: Record<string, Object> = {};
        res['shortestInterval'] = verifyResult.getShortestInterval();
        res['validityPeriod'] = verifyResult.getValidityPeriod();
        result.success(res);
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 通过手机号申请验证码（Auth 实例级别） */
  handleRequestAuthPhoneVerifyCode(call: MethodCall, result: MethodResult): void {
    this.handleRequestPhoneVerifyCode(call, result);
  }

  /** 重新认证当前用户（刷新敏感操作时效） */
  handleReauthenticate(call: MethodCall, result: MethodResult): void {
    let credentialMap = call.argument('credential') as Object;
    let signInParam = buildSignInParam(credentialMap);
    if (signInParam == null) {
      let errDetails: Record<string, Object> = {};
      result.error("", "不支持的认证提供商", errDetails);
      return;
    }
    auth.getCurrentUser()
      .then((user) => {
        if (user == null) {
          let errDetails: Record<string, Object> = {};
          result.error("", "当前无登录用户", errDetails);
          return;
        }
        user.userReauthenticate(signInParam)
          .then(() => {
            result.success(null);
          })
          .catch((err: BusinessError) => {
            handleError(result, err);
          });
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 获取支持的认证方式列表 */
  handleGetSupportedAuthList(result: MethodResult): void {
    // TODO: 鸿蒙 Auth SDK 暂无 getSupportedAuthList 接口，返回空列表兜底
    let res: Record<string, Object> = {};
    res['supportedAuthList'] = new Array<string>();
    result.success(res);
  }
}
