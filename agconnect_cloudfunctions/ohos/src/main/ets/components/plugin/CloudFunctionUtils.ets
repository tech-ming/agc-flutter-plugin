import { MethodCall } from '@ohos/flutter_ohos';

/** 默认超时时间（秒） */
const DEFAULT_TIMEOUT: number = 70;

/** 默认时间单位索引（3 = SECONDS） */
const DEFAULT_TIMEUNIT: number = 3;

/** 每毫秒对应各时间单位的倍率 */
const UNIT_TO_MS: number[] = [
  1 / 1_000_000,  // 0: NANOSECONDS
  1 / 1_000,      // 1: MICROSECONDS
  1,              // 2: MILLISECONDS
  1_000,          // 3: SECONDS
  60_000,         // 4: MINUTES
  3_600_000,      // 5: HOURS
  86_400_000,     // 6: DAYS
];

/** 触发器标识符解析结果 */
export class TriggerInfo {
  name: string = '';
  version: string | undefined = undefined;
}

/**
 * 解析 Android 格式的 HTTP 触发器标识符为 HarmonyOS 的 name + version
 *
 * Android httpTriggerURI 格式为 "functionName-$version"（如 "membership-$latest"）。
 * 以最后一个 "-$" 为分隔点拆分，因为函数名本身可能包含 "-"。
 *
 * 示例：
 * - "membership-$latest"  → name: "membership", version: "$latest"
 * - "my-func-$latest"     → name: "my-func", version: "$latest"
 * - "simple"              → name: "simple", version: undefined
 */
export function parseTriggerURI(uri: string): TriggerInfo {
  const info = new TriggerInfo();
  const separatorIndex = uri.lastIndexOf('-$');
  if (separatorIndex > 0) {
    info.name = uri.substring(0, separatorIndex);
    info.version = uri.substring(separatorIndex + 1);
  } else {
    info.name = uri;
  }
  return info;
}

/**
 * 将 Dart 层传入的 timeout + units 组合转换为毫秒
 *
 * AGCTimeUnit 枚举值映射：
 * 0=NANOSECONDS, 1=MICROSECONDS, 2=MILLISECONDS,
 * 3=SECONDS, 4=MINUTES, 5=HOURS, 6=DAYS
 */
export function resolveTimeoutMs(call: MethodCall): number {
  const timeout: number = (call.argument('timeout') as number) ?? DEFAULT_TIMEOUT;
  const units: number = (call.argument('units') as number) ?? DEFAULT_TIMEUNIT;
  const multiplier = (units >= 0 && units < UNIT_TO_MS.length) ? UNIT_TO_MS[units] : UNIT_TO_MS[3];
  return timeout * multiplier;
}

/**
 * 将 Flutter MethodChannel 传来的参数转换为 HarmonyOS API 可识别的对象
 *
 * Flutter MethodChannel 传递的 Dart Map 在 ohos 侧是 JS Map 类型，
 * 而 HarmonyOS cloudFunction API 只能识别普通 Record 对象。
 * 此函数自动检测并递归转换。
 */
export function convertFlutterParams(raw: Object | null): Object | undefined {
  if (raw === null || raw === undefined) {
    return undefined;
  }
  if (raw instanceof Map) {
    return mapToRecord(raw as Map<string, Object>);
  }
  return raw;
}

/**
 * 递归将 Map 转换为普通 Record 对象
 */
function mapToRecord(map: Map<string, Object>): Record<string, Object> {
  let obj: Record<string, Object> = {};
  map.forEach((value: Object, key: string) => {
    obj[key] = convertValue(value);
  });
  return obj;
}

/**
 * 递归转换单个值（Map → Record，Array 中的 Map 同样处理）
 */
function convertValue(value: Object): Object {
  if (value instanceof Map) {
    return mapToRecord(value as Map<string, Object>);
  }
  if (value instanceof Array) {
    return convertArray(value as Object[]);
  }
  return value;
}

/**
 * 递归转换数组中的 Map 元素
 */
function convertArray(arr: Object[]): Object[] {
  let result: Object[] = [];
  for (let i = 0; i < arr.length; i++) {
    result.push(convertValue(arr[i]));
  }
  return result;
}
