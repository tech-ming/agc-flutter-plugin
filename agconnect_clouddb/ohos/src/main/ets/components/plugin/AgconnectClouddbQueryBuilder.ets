import { cloudDatabase } from '@kit.CloudFoundationKit';
import { DynamicDatabaseObject } from './AgconnectClouddbUtils';

/**
 * 查询条件构建器
 * 将 Dart 层传来的查询条件 Map 转换为 HarmonyOS DatabaseQuery 对象
 */

/**
 * 根据 Dart 层传来的 query Map 构建 DatabaseQuery
 * query 结构：
 * {
 *   zoneObjectTypeName: string,
 *   queryElements: [
 *     { field: string, operation: string, value: any },
 *     ...
 *   ]
 * }
 */
export function buildDatabaseQuery(queryMap: Map<string, Object>): cloudDatabase.DatabaseQuery<DynamicDatabaseObject> {
  // 设置静态类名，供 DatabaseQuery 构造函数内部 new DynamicDatabaseObject() 时
  // 通过 naturalbase_ClassName() 获取正确的表名
  let objectTypeName = (queryMap.get('zoneObjectTypeName') as string) ?? '';
  DynamicDatabaseObject.queryClassName = objectTypeName;

  let condition = new cloudDatabase.DatabaseQuery(DynamicDatabaseObject);

  let queryElements = queryMap.get('queryElements') as Array<Map<string, Object>>;
  if (!queryElements || queryElements.length === 0) {
    return condition;
  }

  for (let i = 0; i < queryElements.length; i++) {
    let element = queryElements[i];
    let operation = element.get('operation') as string;
    let field = element.get('field') as string;
    let value = element.get('value') as Object;

    switch (operation) {
      case 'equalTo':
        condition.equalTo(field, value as cloudDatabase.FieldType);
        break;
      case 'notEqualTo':
        condition.notEqualTo(field, value as cloudDatabase.FieldType);
        break;
      case 'lessThan':
        condition.lessThan(field, value as cloudDatabase.FieldType);
        break;
      case 'lessThanOrEqualTo':
        condition.lessThanOrEqualTo(field, value as cloudDatabase.FieldType);
        break;
      case 'greaterThan':
        condition.greaterThan(field, value as cloudDatabase.FieldType);
        break;
      case 'greaterThanOrEqualTo':
        condition.greaterThanOrEqualTo(field, value as cloudDatabase.FieldType);
        break;
      case 'in':
        condition.in(field, value as cloudDatabase.FieldType[]);
        break;
      case 'beginsWith':
        condition.beginsWith(field, value as cloudDatabase.FieldType);
        break;
      case 'endsWith':
        condition.endsWith(field, value as cloudDatabase.FieldType);
        break;
      case 'contains':
        condition.contains(field, value as cloudDatabase.FieldType);
        break;
      case 'isNull':
        condition.isNull(field);
        break;
      case 'isNotNull':
        condition.isNotNull(field);
        break;
      case 'orderByAsc':
        condition.orderByAsc(field);
        break;
      case 'orderByDesc':
        condition.orderByDesc(field);
        break;
      case 'limit': {
        let count = value as number;
        let offset = element.get('offset') as number | undefined;
        if (offset != undefined && offset != null) {
          condition.limit(count, offset);
        } else {
          condition.limit(count);
        }
        break;
      }
      // startAt / startAfter / endAt / endBefore 在 HarmonyOS cloudDatabase API 中不直接支持
      // 这些操作使用 limit + offset 模拟或忽略
      case 'startAt':
      case 'startAfter':
      case 'endAt':
      case 'endBefore':
        // HarmonyOS cloudDatabase 不支持这些范围查询，跳过
        break;
      default:
        break;
    }
  }

  return condition;
}
