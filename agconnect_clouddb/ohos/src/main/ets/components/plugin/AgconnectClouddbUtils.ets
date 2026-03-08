import { cloudDatabase } from '@kit.CloudFoundationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AgconnectClouddbUtils';
const DOMAIN = 0x0001;

/**
 * CloudDB 工具类
 * 负责 Dart 层 Map 数据与 HarmonyOS DatabaseObject 之间的转换
 */

// ==================== Schema 注册表 ====================

/**
 * Schema 注册表
 *
 * 对齐 Android 端的 ObjectTypeRegistry + 反射机制：
 * Android 端通过强类型 CloudDBZoneObject 子类 + Java 反射获取字段类型，
 * 从而准确判断 Date、String、Integer 等类型进行序列化/反序列化。
 * OHos 端使用 DynamicDatabaseObject 无法反射，因此从 schema.json 构建
 * 等效的字段类型映射表。
 */
export class SchemaRegistry {
  // objectTypeName -> Set<Date 字段名>
  private static dateFields: Map<string, Set<string>> = new Map();

  /**
   * 从 schema.json 内容加载字段类型信息
   */
  static loadFromJson(jsonStr: string): void {
    try {
      let schema: Record<string, Object> = JSON.parse(jsonStr) as Record<string, Object>;
      let objectTypes = schema['objectTypes'] as Object[];
      if (!objectTypes) return;

      for (let i = 0; i < objectTypes.length; i++) {
        let objType = objectTypes[i] as Record<string, Object>;
        let objectTypeName = objType['objectTypeName'] as string;
        let fields = objType['fields'] as Object[];
        let dateFieldSet = new Set<string>();
        if (fields) {
          for (let j = 0; j < fields.length; j++) {
            let field = fields[j] as Record<string, string>;
            if (field['fieldType'] === 'Date') {
              dateFieldSet.add(field['fieldName']);
            }
          }
        }
        SchemaRegistry.dateFields.set(objectTypeName, dateFieldSet);
      }
      hilog.info(DOMAIN, TAG, `Schema 加载成功，对象类型数: ${objectTypes.length}`);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Schema 解析失败: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 判断指定对象类型的字段是否为 Date 类型
   */
  static isDateField(objectTypeName: string, fieldName: string): boolean {
    let fields = SchemaRegistry.dateFields.get(objectTypeName);
    if (!fields) return false;
    return fields.has(fieldName);
  }
}

// ==================== DynamicDatabaseObject ====================

/**
 * 通用的 DatabaseObject 子类，用于动态构建对象
 * 由于 HarmonyOS cloudDatabase 需要继承 DatabaseObject，这里创建一个动态对象类
 */
export class DynamicDatabaseObject extends cloudDatabase.DatabaseObject {
  /**
   * 静态类名，供 DatabaseQuery 构造函数内部实例化时使用。
   *
   * DatabaseQuery 的构造函数会 new 传入的类并调用 naturalbase_ClassName() 获取表名。
   * 由于无法在构造时传参，通过静态字段在构建查询前设置目标表名。
   */
  static queryClassName: string = '';

  private _className: string = '';
  private _data: Map<string, Object | null> = new Map();

  public naturalbase_ClassName(): string {
    // 优先返回实例级别的 className（upsert/delete 等操作通过 setClassName 设置），
    // 若未设置则回退到静态字段（DatabaseQuery 构造时的场景）
    return this._className || DynamicDatabaseObject.queryClassName;
  }

  // 设置对象类型名称
  setClassName(name: string): void {
    this._className = name;
  }

  // 设置字段值
  setField(key: string, value: Object | null): void {
    this._data.set(key, value);
    // 同时设置到对象属性上，以便 SDK 能够读取
    let self = this as Object;
    (self as Record<string, Object | null>)[key] = value;
  }

  // 获取字段值
  getField(key: string): Object | null {
    return this._data.get(key) ?? null;
  }

  // 获取所有数据
  getData(): Map<string, Object | null> {
    return this._data;
  }
}

// ==================== Map ↔ DatabaseObject 转换 ====================

/**
 * 将 Dart 层传来的 Map 数据转换为 DynamicDatabaseObject
 *
 * 对齐 Android 端 AGCCloudDBZoneObjectUtil.fromMap() 的行为：
 * - Date 字段：Dart 传来 int（millisecondsSinceEpoch）→ new Date(value)
 * - 其他字段：直接赋值
 */
export function mapToDatabaseObject(objectTypeName: string, dataMap: Map<string, Object>): DynamicDatabaseObject {
  let obj = new DynamicDatabaseObject();
  obj.setClassName(objectTypeName);
  dataMap.forEach((value: Object, key: string) => {
    if (SchemaRegistry.isDateField(objectTypeName, key) && typeof value === 'number') {
      // Date 字段：Dart 传来 int（毫秒时间戳）→ JavaScript Date 对象
      obj.setField(key, new Date(value as number));
    } else {
      obj.setField(key, value);
    }
  });
  return obj;
}

/**
 * 将 Dart 层传来的 Map 数组转换为 DynamicDatabaseObject 数组
 */
export function mapListToDatabaseObjects(objectTypeName: string, dataList: Array<Map<string, Object>>): DynamicDatabaseObject[] {
  let result: DynamicDatabaseObject[] = [];
  for (let i = 0; i < dataList.length; i++) {
    result.push(mapToDatabaseObject(objectTypeName, dataList[i]));
  }
  return result;
}

/**
 * 将 DatabaseObject 转换为 Map（用于返回给 Dart 层）
 *
 * 对齐 Android 端 AGCCloudDBZoneObjectUtil.toMap() 的行为：
 * - Date 字段：date.getTime() → Dart 端接收 int（毫秒时间戳）
 * - 其他字段：直接传递
 */
export function databaseObjectToMap(obj: Object): Map<string, Object | null> {
  let result = new Map<string, Object | null>();
  let keys = Object.keys(obj);
  for (let i = 0; i < keys.length; i++) {
    let key = keys[i];
    // 过滤掉内部属性和方法
    if (key.startsWith('_') || key === 'naturalbase_ClassName') {
      continue;
    }
    let value = (obj as Record<string, Object | null>)[key];
    if (typeof value === 'function') {
      continue;
    }
    // Date 类型转为毫秒时间戳（Dart 层使用 millisecondsSinceEpoch）
    if (value instanceof Date) {
      result.set(key, (value as Date).getTime());
    } else if (value !== null && typeof (value as Record<string, Function>)['getTime'] === 'function') {
      // CloudDB SDK 返回的 Date 变体对象可能不通过 instanceof 检测
      result.set(key, (value as Date).getTime());
    } else {
      result.set(key, value);
    }
  }
  return result;
}

/**
 * 将 DatabaseObject 数组转换为 Map 数组
 */
export function databaseObjectsToMapList(objList: Object[]): Array<Map<string, Object | null>> {
  let result: Array<Map<string, Object | null>> = [];
  for (let i = 0; i < objList.length; i++) {
    result.push(databaseObjectToMap(objList[i]));
  }
  return result;
}

// ==================== 枚举映射 ====================

/**
 * QueryCalculate 枚举映射
 * Dart 层方法名 -> HarmonyOS QueryCalculate 枚举
 */
export function getQueryCalculateType(methodName: string): cloudDatabase.QueryCalculate {
  switch (methodName) {
    case 'executeAverageQuery':
      return cloudDatabase.QueryCalculate.AVERAGE;
    case 'executeSumQuery':
      return cloudDatabase.QueryCalculate.SUM;
    case 'executeMaximumQuery':
      return cloudDatabase.QueryCalculate.MAXIMUM;
    case 'executeMinimalQuery':
      return cloudDatabase.QueryCalculate.MINIMUM;
    case 'executeCountQuery':
      return cloudDatabase.QueryCalculate.COUNT;
    default:
      return cloudDatabase.QueryCalculate.COUNT;
  }
}
