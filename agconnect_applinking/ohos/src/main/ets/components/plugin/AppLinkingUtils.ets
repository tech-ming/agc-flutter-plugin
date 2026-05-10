import { MethodResult } from '@ohos/flutter_ohos';

/**
 * AppLinking 数据转换工具类
 *
 * HarmonyOS @kit.AppLinkingKit 只能获取链接 URI 字符串，
 * 不像 Android AGC SDK 的 ResolvedLinkData 那样提供 clickTimeStamp、
 * campaignInfo、socialCardInfo 等元数据。
 *
 * 因此将 URI 字符串转换为 Dart 层 ResolvedLinkData.fromMap() 期望的格式时，
 * 除 deepLink 外的其他字段填充默认值。
 */

/**
 * 将 HarmonyOS 链接 URI 字符串转换为 Dart 层 ResolvedLinkData 约定的 Map。
 *
 * 字段映射与 Android 端 Utils.fromResolvedLinkDataToMap() 保持一致：
 * - deepLink: 深度链接 URI 字符串（从 want.uri 或 deferredLink 获取）
 * - clickTimeStamp: 0（HarmonyOS @kit.AppLinkingKit 不提供）
 * - socialTitle/socialDescription/socialImageUrl: 空字符串
 * - campaignName/campaignMedium/campaignSource: 空字符串
 * - installSource: 空字符串
 * - linkType: 0 (AppLinking)
 */
export function linkUriToResolvedDataMap(uri: string): Record<string, Object> {
  const map: Record<string, Object> = {};
  map['deepLink'] = uri;
  map['clickTimeStamp'] = 0;
  map['socialTitle'] = '';
  map['socialDescription'] = '';
  map['socialImageUrl'] = '';
  map['campaignName'] = '';
  map['campaignMedium'] = '';
  map['campaignSource'] = '';
  map['installSource'] = '';
  // linkType: 0=AppLinking, 1=UnifiedLinking，与 Android 端 ordinal 对齐
  map['linkType'] = 0;
  return map;
}

/**
 * 统一异常转换为 Flutter PlatformException。
 */
export function handleError(e: Object, result: MethodResult): void {
  if (e instanceof Error) {
    const error = e as Error;
    const agcError = e as Object as Record<string, Object>;
    const code = agcError['code'] !== undefined ? String(agcError['code']) : 'UNKNOWN';
    const message = error.message || 'AppLinking 操作失败';
    result.error(code, message, null);
  } else {
    result.error('UNKNOWN', String(e), null);
  }
}
