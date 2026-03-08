import {
  CredentialInfo,
  EmailCredentialInfo,
  PhoneCredentialInfo,
  HwIdCredentialInfo,
  SelfBuildCredentialInfo,
  SignInParam,
} from '@hw-agconnect/auth';
import { safeGet } from './AgconnectAuthUtils';
import { dartIndexToProviderKind } from './AgconnectAuthProviderMap';

/**
 * AGC Auth 凭证构建工具。
 *
 * provider 枚举值来源于 Dart 侧 AuthProviderType.index，
 * 通过 AgconnectAuthProviderMap 统一做双向转换。
 */

/**
 * 从 Flutter 侧 credential 对象构造鸿蒙侧 SignInParam。
 * @param credential Flutter 传入的凭证参数（可能是 Map 或 Record）
 * @returns 鸿蒙 auth.signIn 所需的 SignInParam，不支持的 provider 返回 null
 */
export function buildSignInParam(credential: Object): SignInParam | null {
  let provider = safeGet(credential, 'provider') as number;
  let autoCreateUser = safeGet(credential, 'autoCreateUser') as boolean;

  let credentialInfo = _buildCredentialByKind(credential, provider);
  if (credentialInfo == null) {
    return null;
  }

  let signInParam: SignInParam = {
    credentialInfo: credentialInfo,
    autoCreateUser: autoCreateUser,
  };
  return signInParam;
}

/**
 * 从 Flutter 侧 credential 对象构造鸿蒙侧 CredentialInfo。
 * 用于 link 等需要 CredentialInfo 的场景。
 * @param credential Flutter 传入的凭证参数（可能是 Map 或 Record）
 * @returns CredentialInfo 或 null
 */
export function buildCredentialInfo(credential: Object): CredentialInfo | null {
  let provider = safeGet(credential, 'provider') as number;
  return _buildCredentialByKind(credential, provider);
}

/**
 * 根据 Dart provider index 构建对应的 CredentialInfo。
 */
function _buildCredentialByKind(credential: Object, dartIndex: number): CredentialInfo | null {
  let kind = dartIndexToProviderKind(dartIndex);
  if (kind == null) {
    return null;
  }

  if (kind === 'selfBuild') {
    let info: SelfBuildCredentialInfo = {
      kind: 'selfBuild',
      accessToken: safeGet(credential, 'token') as string,
    };
    return info;
  } else if (kind === 'email') {
    let info: EmailCredentialInfo = {
      kind: 'email',
      email: safeGet(credential, 'email') as string,
      password: safeGet(credential, 'password') as string,
      verifyCode: safeGet(credential, 'verifyCode') as string,
    };
    return info;
  } else if (kind === 'phone') {
    let info: PhoneCredentialInfo = {
      kind: 'phone',
      countryCode: safeGet(credential, 'countryCode') as string,
      phoneNumber: safeGet(credential, 'phoneNumber') as string,
      password: safeGet(credential, 'password') as string,
      verifyCode: safeGet(credential, 'verifyCode') as string,
    };
    return info;
  } else if (kind === 'hwid') {
    let info: HwIdCredentialInfo = {
      kind: 'hwid',
    };
    return info;
  }

  return null;
}
