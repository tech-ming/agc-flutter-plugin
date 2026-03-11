import { relationalStore, preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'ClouddbLocalCache';
const DOMAIN = 0x0001;
const DB_NAME = 'clouddb_cache.db';
const PREF_NAME = 'clouddb_cache_meta';
const PREF_KEY_SCHEMA_VERSION = 'schemaVersion';

/**
 * CloudDB 本地缓存管理器
 *
 * 使用 relationalStore（关系型数据库）为 CloudDB 数据提供离线缓存。
 * 根据 schema.json 动态建表，支持 upsert / delete / query 操作。
 * 在云端操作成功后同步写入缓存，离线降级时从缓存读取。
 */

// ==================== Schema 类型定义 ====================

/**
 * 字段定义（对应 schema.json 中的 fields 数组元素）
 */
interface SchemaField {
  fieldName: string;
  fieldType: string; // Boolean, Integer, Long, Double, String, Date, ...
  notNull?: boolean;
  belongPrimaryKey?: boolean;
  defaultValue?: string;
}

/**
 * 对象类型定义（对应 schema.json 中的 objectTypes 数组元素）
 */
interface SchemaObjectType {
  objectTypeName: string;
  fields: SchemaField[];
  indexes?: SchemaIndex[];
}

/**
 * 索引定义
 */
interface SchemaIndex {
  indexName: string;
  indexList: SchemaIndexField[];
}

interface SchemaIndexField {
  fieldName: string;
  sortType: string;
}

// ==================== ClouddbLocalCache ====================

export class ClouddbLocalCache {
  private store: relationalStore.RdbStore | null = null;
  // objectTypeName -> SchemaField[]
  private schemaMap: Map<string, SchemaField[]> = new Map();
  // objectTypeName -> 主键字段名列表
  private primaryKeyMap: Map<string, string[]> = new Map();
  // schema.json 中的 schemaVersion
  private schemaVersion: number = 0;
  private initialized: boolean = false;
  // 保存初始化 Promise，确保并发调用等待同一个初始化过程
  private initPromise: Promise<void> | null = null;

  /**
   * 初始化缓存数据库
   * 解析 schema，创建 RdbStore，建表
   *
   * 使用 initPromise 保证：即使多处并发调用也只执行一次初始化，
   * 外部通过 waitForReady() 等待初始化完成。
   */
  init(context: common.Context, schemaJson: string): Promise<void> {
    if (this.initialized) return Promise.resolve();
    if (this.initPromise) return this.initPromise;

    this.initPromise = this.doInit(context, schemaJson);
    return this.initPromise;
  }

  private async doInit(context: common.Context, schemaJson: string): Promise<void> {
    try {
      // 解析 schema（含 schemaVersion）
      this.parseSchema(schemaJson);

      const config: relationalStore.StoreConfig = {
        name: DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
      };

      // 检查本地记录的 schema 版本，版本变更时销毁旧库重建
      let needRebuild = await this.checkSchemaVersionChanged(context);
      if (needRebuild) {
        hilog.info(DOMAIN, TAG, `schema 版本变更，销毁旧缓存数据库并重建`);
        await relationalStore.deleteRdbStore(context, DB_NAME);
      }

      // 创建 / 打开 RdbStore
      this.store = await relationalStore.getRdbStore(context, config);

      // 根据 schema 动态建表
      await this.createTables();

      // 将当前 schema 版本写入 Preferences
      await this.saveSchemaVersion(context);

      this.initialized = true;
      hilog.info(DOMAIN, TAG, `本地缓存初始化成功，schemaVersion: ${this.schemaVersion}，对象类型数: ${this.schemaMap.size}`);
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `本地缓存初始化失败, code: ${error.code}, message: ${error.message}`);
    }
  }

  /**
   * 等待缓存初始化完成
   * ZoneManager 在需要缓存时调用此方法，保证缓存已就绪
   */
  async waitForReady(): Promise<boolean> {
    if (this.initialized) return true;
    if (this.initPromise) {
      await this.initPromise;
    }
    return this.initialized;
  }

  /**
   * 解析 schema.json，构建字段映射表、主键映射表，并提取 schemaVersion
   */
  private parseSchema(schemaJson: string): void {
    let schema: Record<string, Object> = JSON.parse(schemaJson) as Record<string, Object>;

    // 提取 schemaVersion
    let version = schema['schemaVersion'] as number;
    if (version !== undefined && version !== null) {
      this.schemaVersion = version;
    }

    let objectTypes = schema['objectTypes'] as Object[];
    if (!objectTypes) return;

    for (let i = 0; i < objectTypes.length; i++) {
      let objType = objectTypes[i] as SchemaObjectType;
      let name = objType.objectTypeName;
      let fields = objType.fields;

      this.schemaMap.set(name, fields);

      // 提取主键字段
      let pks: string[] = [];
      for (let j = 0; j < fields.length; j++) {
        if (fields[j].belongPrimaryKey) {
          pks.push(fields[j].fieldName);
        }
      }
      this.primaryKeyMap.set(name, pks);
    }
  }

  /**
   * 根据 schema 动态建表
   */
  private async createTables(): Promise<void> {
    if (!this.store) return;

    let entries = Array.from(this.schemaMap.entries());
    for (let i = 0; i < entries.length; i++) {
      let tableName = entries[i][0];
      let fields = entries[i][1];
      let pks = this.primaryKeyMap.get(tableName) ?? [];

      let columnDefs: string[] = [];
      for (let j = 0; j < fields.length; j++) {
        let f = fields[j];
        let sqlType = this.mapFieldTypeToSql(f.fieldType);
        let col = `${f.fieldName} ${sqlType}`;
        if (f.notNull) {
          col += ' NOT NULL';
        }
        columnDefs.push(col);
      }

      // 复合主键
      if (pks.length > 0) {
        columnDefs.push(`PRIMARY KEY (${pks.join(', ')})`);
      }

      let sql = `CREATE TABLE IF NOT EXISTS ${tableName} (${columnDefs.join(', ')})`;
      await this.store.executeSql(sql);
      hilog.info(DOMAIN, TAG, `建表: ${tableName}`);
    }
  }

  /**
   * schema fieldType -> SQLite 类型映射
   */
  private mapFieldTypeToSql(fieldType: string): string {
    switch (fieldType) {
      case 'Boolean':
        return 'INTEGER';
      case 'Integer':
      case 'Long':
        return 'INTEGER';
      case 'Float':
      case 'Double':
        return 'REAL';
      case 'String':
      case 'Text':
        return 'TEXT';
      case 'Date':
        // Date 存为毫秒时间戳（INTEGER）
        return 'INTEGER';
      case 'ByteArray':
        return 'BLOB';
      default:
        return 'TEXT';
    }
  }

  // ==================== 数据操作 ====================

  /**
   * 缓存 upsert 操作
   * 使用 INSERT OR REPLACE 实现
   */
  async upsert(objectTypeName: string, entries: Array<Map<string, Object | null>>): Promise<void> {
    if (!this.store || !this.initialized) return;

    let fields = this.schemaMap.get(objectTypeName);
    if (!fields) {
      hilog.warn(DOMAIN, TAG, `upsert: 未知的对象类型 ${objectTypeName}`);
      return;
    }

    try {
      // 逐条 INSERT OR REPLACE
      for (let i = 0; i < entries.length; i++) {
        let entry = entries[i];
        let valueBucket: relationalStore.ValuesBucket = {};

        for (let j = 0; j < fields.length; j++) {
          let fieldName = fields[j].fieldName;
          let fieldType = fields[j].fieldType;

          if (entry.has(fieldName)) {
            let value = entry.get(fieldName);
            valueBucket[fieldName] = this.toStorageValue(value, fieldType);
          }
        }

        // 使用 CONFLICT_RESOLUTION_ON_CONFLICT_REPLACE 实现 upsert
        await this.store!.insert(objectTypeName, valueBucket,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      }

      hilog.info(DOMAIN, TAG, `缓存 upsert 成功: ${objectTypeName}, 数量: ${entries.length}`);
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `缓存 upsert 失败: ${error.message}`);
    }
  }

  /**
   * 缓存 delete 操作
   * 根据主键删除
   */
  async delete(objectTypeName: string, entries: Array<Map<string, Object | null>>): Promise<void> {
    if (!this.store || !this.initialized) return;

    let pks = this.primaryKeyMap.get(objectTypeName);
    if (!pks || pks.length === 0) {
      hilog.warn(DOMAIN, TAG, `delete: ${objectTypeName} 无主键定义`);
      return;
    }

    try {
      for (let i = 0; i < entries.length; i++) {
        let entry = entries[i];
        let predicates = new relationalStore.RdbPredicates(objectTypeName);

        for (let k = 0; k < pks.length; k++) {
          let pkField = pks[k];
          let pkValue = entry.get(pkField);
          if (pkValue !== null && pkValue !== undefined) {
            predicates.equalTo(pkField, pkValue as relationalStore.ValueType);
          }
        }

        await this.store!.delete(predicates);
      }

      hilog.info(DOMAIN, TAG, `缓存 delete 成功: ${objectTypeName}, 数量: ${entries.length}`);
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `缓存 delete 失败: ${error.message}`);
    }
  }

  /**
   * 从缓存查询数据
   *
   * 将 Dart 层的 queryMap 条件翻译为 RdbPredicates 执行本地查询，
   * 返回与 buildSnapshotResult 一致的格式。
   */
  async query(queryMap: Map<string, Object>): Promise<Map<string, Object> | null> {
    if (!this.store || !this.initialized) return null;

    let objectTypeName = (queryMap.get('zoneObjectTypeName') as string) ?? '';
    let fields = this.schemaMap.get(objectTypeName);
    if (!fields) {
      hilog.warn(DOMAIN, TAG, `query: 未知的对象类型 ${objectTypeName}`);
      return null;
    }

    try {
      let predicates = this.buildPredicates(objectTypeName, queryMap);
      let resultSet = await this.store!.query(predicates);
      let results: Array<Map<string, Object | null>> = [];

      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow();
        do {
          let row = new Map<string, Object | null>();
          for (let j = 0; j < fields.length; j++) {
            let fieldName = fields[j].fieldName;
            let fieldType = fields[j].fieldType;
            let colIndex = resultSet.getColumnIndex(fieldName);
            if (colIndex >= 0 && !resultSet.isColumnNull(colIndex)) {
              row.set(fieldName, this.readColumnValue(resultSet, colIndex, fieldType));
            }
          }
          results.push(row);
        } while (resultSet.goToNextRow());
      }
      resultSet.close();

      // 构建 snapshot 格式
      let result = new Map<string, Object>();
      result.set('isFromCloud', false);
      result.set('hasPendingWrites', false);
      result.set('snapshotObjects', results);
      result.set('upsertedObjects', [] as Array<Map<string, Object | null>>);
      result.set('deletedObjects', [] as Array<Map<string, Object | null>>);

      hilog.info(DOMAIN, TAG, `缓存 query 成功: ${objectTypeName}, 结果数量: ${results.length}`);
      return result;
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `缓存 query 失败: ${error.message}`);
      return null;
    }
  }

  /**
   * 从缓存执行聚合查询
   * 支持 count / sum / average / maximum / minimum
   */
  async calculateQuery(queryMap: Map<string, Object>, fieldName: string, methodName: string): Promise<number | null> {
    if (!this.store || !this.initialized) return null;

    let objectTypeName = (queryMap.get('zoneObjectTypeName') as string) ?? '';
    if (!this.schemaMap.has(objectTypeName)) {
      return null;
    }

    try {
      let funcName = this.getAggregateFuncName(methodName);
      let targetField = (funcName === 'COUNT') ? '*' : fieldName;
      let predicates = this.buildPredicates(objectTypeName, queryMap);

      // 使用 querySql 执行聚合
      let whereClause = '';
      let whereArgs: string[] = [];
      // 简化：直接查全表聚合（条件已在 predicates 中无法直接提取 SQL）
      // 如果有条件，使用 RdbPredicates 查出行再在内存中聚合
      let resultSet = await this.store!.query(predicates);

      let result: number = 0;
      let count = resultSet.rowCount;

      if (count === 0) {
        resultSet.close();
        return 0;
      }

      if (funcName === 'COUNT') {
        resultSet.close();
        return count;
      }

      // 内存聚合（sum/avg/max/min）
      let colIndex = -1;
      let values: number[] = [];
      resultSet.goToFirstRow();
      colIndex = resultSet.getColumnIndex(fieldName);
      if (colIndex < 0) {
        resultSet.close();
        return 0;
      }

      do {
        if (!resultSet.isColumnNull(colIndex)) {
          values.push(resultSet.getDouble(colIndex));
        }
      } while (resultSet.goToNextRow());
      resultSet.close();

      if (values.length === 0) return 0;

      switch (funcName) {
        case 'SUM':
          result = values.reduce((a: number, b: number) => a + b, 0);
          break;
        case 'AVERAGE':
          result = values.reduce((a: number, b: number) => a + b, 0) / values.length;
          break;
        case 'MAXIMUM':
          result = Math.max(...values);
          break;
        case 'MINIMUM':
          result = Math.min(...values);
          break;
        default:
          result = 0;
      }

      hilog.info(DOMAIN, TAG, `缓存 calculateQuery(${funcName}) 成功: ${result}`);
      return result;
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `缓存 calculateQuery 失败: ${error.message}`);
      return null;
    }
  }

  // ==================== 辅助方法 ====================

  /**
   * 根据 queryMap 的 queryElements 构建 RdbPredicates
   */
  private buildPredicates(objectTypeName: string, queryMap: Map<string, Object>): relationalStore.RdbPredicates {
    let predicates = new relationalStore.RdbPredicates(objectTypeName);
    let queryElements = queryMap.get('queryElements') as Array<Map<string, Object>> | undefined;
    if (!queryElements || queryElements.length === 0) {
      return predicates;
    }

    for (let i = 0; i < queryElements.length; i++) {
      let element = queryElements[i];
      let operation = element.get('operation') as string;
      let field = element.get('field') as string;
      let value = element.get('value') as Object;

      switch (operation) {
        case 'equalTo':
          predicates.equalTo(field, value as relationalStore.ValueType);
          break;
        case 'notEqualTo':
          predicates.notEqualTo(field, value as relationalStore.ValueType);
          break;
        case 'lessThan':
          predicates.lessThan(field, value as relationalStore.ValueType);
          break;
        case 'lessThanOrEqualTo':
          predicates.lessThanOrEqualTo(field, value as relationalStore.ValueType);
          break;
        case 'greaterThan':
          predicates.greaterThan(field, value as relationalStore.ValueType);
          break;
        case 'greaterThanOrEqualTo':
          predicates.greaterThanOrEqualTo(field, value as relationalStore.ValueType);
          break;
        case 'in':
          predicates.in(field, value as relationalStore.ValueType[]);
          break;
        case 'beginsWith':
          predicates.beginsWith(field, value as string);
          break;
        case 'endsWith':
          predicates.endsWith(field, value as string);
          break;
        case 'contains':
          predicates.contains(field, value as string);
          break;
        case 'isNull':
          predicates.isNull(field);
          break;
        case 'isNotNull':
          predicates.isNotNull(field);
          break;
        case 'orderByAsc':
          predicates.orderByAsc(field);
          break;
        case 'orderByDesc':
          predicates.orderByDesc(field);
          break;
        case 'limit': {
          let count = value as number;
          let offset = element.get('offset') as number | undefined;
          predicates.limitAs(count);
          if (offset !== undefined && offset !== null) {
            predicates.offsetAs(offset);
          }
          break;
        }
        default:
          break;
      }
    }

    return predicates;
  }

  /**
   * 将值转为 relationalStore 支持的存储类型
   */
  private toStorageValue(value: Object | null | undefined, fieldType: string): relationalStore.ValueType | null {
    if (value === null || value === undefined) return null;

    switch (fieldType) {
      case 'Boolean':
        return (value as boolean) ? 1 : 0;
      case 'Integer':
      case 'Long':
        return value as number;
      case 'Float':
      case 'Double':
        return value as number;
      case 'String':
      case 'Text':
        return value as string;
      case 'Date':
        // Date 字段：传入可能是 number（毫秒时间戳）或 Date 对象
        if (typeof value === 'number') {
          return value as number;
        } else if (value instanceof Date) {
          return (value as Date).getTime();
        }
        return value as number;
      default:
        return value as relationalStore.ValueType;
    }
  }

  /**
   * 从 ResultSet 读取指定列的值，按字段类型转换
   */
  private readColumnValue(resultSet: relationalStore.ResultSet, colIndex: number, fieldType: string): Object | null {
    switch (fieldType) {
      case 'Boolean':
        return resultSet.getLong(colIndex) !== 0;
      case 'Integer':
      case 'Long':
        return resultSet.getLong(colIndex);
      case 'Float':
      case 'Double':
        return resultSet.getDouble(colIndex);
      case 'String':
      case 'Text':
        return resultSet.getString(colIndex);
      case 'Date':
        // Date 字段存为毫秒时间戳，读出为 number（与 Dart 层约定一致）
        return resultSet.getLong(colIndex);
      default:
        return resultSet.getString(colIndex);
    }
  }

  /**
   * Dart 方法名 -> SQL 聚合函数名
   */
  private getAggregateFuncName(methodName: string): string {
    switch (methodName) {
      case 'executeAverageQuery':
        return 'AVERAGE';
      case 'executeSumQuery':
        return 'SUM';
      case 'executeMaximumQuery':
        return 'MAXIMUM';
      case 'executeMinimalQuery':
        return 'MINIMUM';
      case 'executeCountQuery':
        return 'COUNT';
      default:
        return 'COUNT';
    }
  }

  /**
   * 检查 schema 版本是否变更
   *
   * 从 Preferences 读取上次建表时的 schemaVersion，
   * 与当前 schema.json 中的版本对比。
   * 首次安装（无记录）时不需要销毁，直接建表即可。
   *
   * @returns true 表示版本变更，需要销毁重建
   */
  private async checkSchemaVersionChanged(context: common.Context): Promise<boolean> {
    try {
      let pref = await preferences.getPreferences(context, PREF_NAME);
      let savedVersion = await pref.get(PREF_KEY_SCHEMA_VERSION, 0) as number;

      if (savedVersion === 0) {
        // 首次安装，无旧数据库，不需要销毁
        hilog.info(DOMAIN, TAG, `首次初始化缓存，schemaVersion: ${this.schemaVersion}`);
        return false;
      }

      if (savedVersion !== this.schemaVersion) {
        hilog.info(DOMAIN, TAG, `schema 版本变更: ${savedVersion} -> ${this.schemaVersion}`);
        return true;
      }

      return false;
    } catch (err) {
      let error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, `读取缓存版本号失败，按首次安装处理: ${error.message}`);
      return false;
    }
  }

  /**
   * 将当前 schemaVersion 持久化到 Preferences
   */
  private async saveSchemaVersion(context: common.Context): Promise<void> {
    try {
      let pref = await preferences.getPreferences(context, PREF_NAME);
      await pref.put(PREF_KEY_SCHEMA_VERSION, this.schemaVersion);
      await pref.flush();
    } catch (err) {
      let error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, `保存 schemaVersion 失败: ${error.message}`);
    }
  }

  /**
   * 缓存是否已初始化
   */
  isReady(): boolean {
    return this.initialized;
  }
}
