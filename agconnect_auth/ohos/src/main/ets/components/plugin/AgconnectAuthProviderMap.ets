import { ProviderType } from '@hw-agconnect/auth';

/**
 * Dart AuthProviderType 枚举 index 与鸿蒙 SDK ProviderType 的双向映射。
 *
 * Dart 枚举定义（agconnect_auth_credential.dart）：
 *   anonymous=0, hms=1, facebook=2, twitter=3, wechat=4,
 *   huaweiGame=5, qq=6, weibo=7, google=8, googleGame=9,
 *   selfBuild=10, phone=11, email=12, apple=13, alipay=14
 *
 * 鸿蒙 Auth SDK 支持的 ProviderType：
 *   'email' | 'phone' | 'hwid' | 'selfBuild'
 */

/** Dart index → 鸿蒙 ProviderType */
const _indexToKind: Map<number, ProviderType> = new Map([
  [1, 'hwid'],
  [10, 'selfBuild'],
  [11, 'phone'],
  [12, 'email'],
]);

/** 鸿蒙 ProviderType → Dart index */
const _kindToIndex: Map<string, number> = new Map([
  ['hwid', 1],
  ['selfBuild', 10],
  ['phone', 11],
  ['email', 12],
]);

/**
 * 将 Dart AuthProviderType.index 转换为鸿蒙 SDK ProviderType。
 * @param dartIndex Dart 侧枚举 index
 * @returns 鸿蒙 ProviderType，未知 provider 返回 null
 */
export function dartIndexToProviderKind(dartIndex: number): ProviderType | null {
  return _indexToKind.get(dartIndex) ?? null;
}

/**
 * 将鸿蒙 SDK ProviderType 转换为 Dart AuthProviderType.index。
 * @param kind 鸿蒙 SDK 返回的 provider 字符串
 * @returns Dart 枚举 index，未知 provider 返回 0（anonymous）
 */
export function providerKindToDartIndex(kind: string): number {
  return _kindToIndex.get(kind) ?? 0;
}
