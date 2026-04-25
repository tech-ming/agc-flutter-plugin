import { MethodResult } from '@ohos/flutter_ohos';
import { BusinessError } from '@kit.BasicServicesKit';
import { cloudStorage } from '@kit.CloudFoundationKit';

/**
 * CloudStorage 工具方法集合
 */

/** 统一错误处理：将 BusinessError 转换为 Flutter MethodResult.error */
export function handleError(result: MethodResult, err: BusinessError | Error): void {
  let code: string = '';
  let message: string = '';
  let details: Record<string, Object> = {};

  if ((err as BusinessError).code !== undefined) {
    let bizErr = err as BusinessError;
    code = String(bizErr.code);
    message = bizErr.message ?? 'Unknown error';
    details['exceptionType'] = 'StorageException';
  } else {
    code = 'UNKNOWN';
    message = err.message ?? 'Unknown error';
    details['exceptionType'] = 'PluginException';
  }
  result.error(code, message, details);
}

/**
 * 将 cloudStorage.Metadata 转换为与 Android/Dart 对齐的 Map。
 * Dart 层 AGCStorageMetadata 期望的字段：
 * name, path, size, bucket, cacheControl, contentType,
 * contentDisposition, contentEncoding, contentLanguage,
 * sha256Hash, customMetadata, creationTimeMillis, updatedTimeMillis
 */
export function metadataToMap(meta: cloudStorage.Metadata): Record<string, Object> {
  let map: Record<string, Object> = {};
  // 基本属性 - 使用安全读取，鸿蒙 Metadata 结构可能部分字段缺失
  map['name'] = safeGet(meta, 'name', '') as Object;
  map['path'] = safeGet(meta, 'path', '') as Object;
  map['size'] = safeGet(meta, 'size', 0) as Object;
  map['bucket'] = safeGet(meta, 'bucket', '') as Object;
  map['cacheControl'] = safeGet(meta, 'cacheControl', '') as Object;
  map['contentType'] = safeGet(meta, 'contentType', '') as Object;
  map['contentDisposition'] = safeGet(meta, 'contentDisposition', '') as Object;
  map['contentEncoding'] = safeGet(meta, 'contentEncoding', '') as Object;
  map['contentLanguage'] = safeGet(meta, 'contentLanguage', '') as Object;
  map['sha256Hash'] = safeGet(meta, 'sha256Hash', '') as Object;
  let emptyMap: Record<string, string> = {};
  map['customMetadata'] = safeGet(meta, 'customMetadata', emptyMap) as Object;

  // 时间字段：Dart 层使用 DateTime.parse()，需要 ISO 8601 字符串
  let metaObj = meta as Object as Record<string, Object>;
  let createTime: Date | undefined = metaObj['createTime'] as Date | undefined;
  let updateTime: Date | undefined = metaObj['updateTime'] as Date | undefined;
  map['creationTimeMillis'] = createTime ? createTime.toISOString() : new Date(0).toISOString();
  map['updatedTimeMillis'] = updateTime ? updateTime.toISOString() : new Date(0).toISOString();
  return map;
}

/** 安全获取对象属性 */
function safeGet(obj: Object, key: string, defaultValue: Object): Object {
  try {
    let value = (obj as Record<string, Object>)[key];
    return value !== undefined && value !== null ? value : defaultValue;
  } catch (e) {
    return defaultValue;
  }
}
