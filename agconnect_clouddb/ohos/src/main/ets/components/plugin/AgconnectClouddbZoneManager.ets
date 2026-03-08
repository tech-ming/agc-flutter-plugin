import { cloudDatabase } from '@kit.CloudFoundationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  DynamicDatabaseObject,
  mapListToDatabaseObjects,
  databaseObjectsToMapList,
  getQueryCalculateType,
} from './AgconnectClouddbUtils';
import { buildDatabaseQuery } from './AgconnectClouddbQueryBuilder';

const TAG = 'AgconnectClouddbZoneManager';
const DOMAIN = 0x0001;

/**
 * CloudDB Zone 管理器
 * 管理所有 Zone 实例，处理数据操作（CRUD、查询、事务等）
 */
export class AgconnectClouddbZoneManager {
  // zone 实例缓存，key 为 zoneId（这里使用 zoneName 作为 zoneId）
  private zoneMap: Map<string, cloudDatabase.DatabaseZone> = new Map();
  // zoneId 到 zoneName 的映射
  private zoneIdToName: Map<string, string> = new Map();
  private nextZoneId: number = 0;

  /**
   * 初始化 CloudDB
   * HarmonyOS 不需要显式初始化，直接返回成功
   * 注：CloudFoundationKit 的 AuthProvider 注入由 Auth 插件负责（cloudCommon.init）
   */
  initialize(): void {
    hilog.info(DOMAIN, TAG, '初始化 CloudDB');
  }

  /**
   * 创建对象类型
   * HarmonyOS 中对象类型通过 AGC 控制台定义，不需要客户端创建
   */
  createObjectType(): void {
    hilog.info(DOMAIN, TAG, '创建对象类型（HarmonyOS 通过控制台定义）');
  }

  /**
   * 打开 CloudDB Zone
   */
  openCloudDBZone(zoneConfig: Map<string, Object>): Map<string, Object> {
    let zoneName = zoneConfig.get('zoneName') as string;
    let zoneId = `zone_${this.nextZoneId++}`;

    let databaseZone = cloudDatabase.zone(zoneName);
    this.zoneMap.set(zoneId, databaseZone);
    this.zoneIdToName.set(zoneId, zoneName);

    hilog.info(DOMAIN, TAG, `打开 CloudDB Zone: ${zoneName}, zoneId: ${zoneId}`);

    let result = new Map<string, Object>();
    result.set('zoneId', zoneId);
    return result;
  }

  /**
   * 关闭 CloudDB Zone
   */
  closeCloudDBZone(zoneId: string): void {
    this.zoneMap.delete(zoneId);
    this.zoneIdToName.delete(zoneId);
    hilog.info(DOMAIN, TAG, `关闭 CloudDB Zone: ${zoneId}`);
  }

  /**
   * 删除 CloudDB Zone
   * HarmonyOS 端没有直接删除 Zone 的 API，从缓存中移除
   */
  deleteCloudDBZone(zoneName: string): void {
    // 查找并移除所有使用该 zoneName 的 zone
    let keysToRemove: string[] = [];
    this.zoneIdToName.forEach((name: string, id: string) => {
      if (name === zoneName) {
        keysToRemove.push(id);
      }
    });
    for (let key of keysToRemove) {
      this.zoneMap.delete(key);
      this.zoneIdToName.delete(key);
    }
    hilog.info(DOMAIN, TAG, `删除 CloudDB Zone: ${zoneName}`);
  }

  /**
   * 获取 Zone 实例
   */
  private getZone(zoneId: string): cloudDatabase.DatabaseZone {
    let zone = this.zoneMap.get(zoneId);
    if (!zone) {
      throw new Error(`Zone not found: ${zoneId}`);
    }
    return zone;
  }

  /**
   * 执行 upsert 操作
   */
  async executeUpsert(zoneId: string, objectTypeName: string, entries: Array<Map<string, Object>>): Promise<number> {
    let zone = this.getZone(zoneId);
    let objects = mapListToDatabaseObjects(objectTypeName, entries);

    try {
      let result = await zone.upsert(objects);
      hilog.info(DOMAIN, TAG, `upsert 成功，影响行数: ${result}`);
      return result;
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `upsert 失败, code: ${error.code}, message: ${error.message}`);
      throw new Error(`upsert 失败, code: ${error.code}, message: ${error.message}`);
    }
  }

  /**
   * 执行 delete 操作
   */
  async executeDelete(zoneId: string, objectTypeName: string, entries: Array<Map<string, Object>>): Promise<number> {
    let zone = this.getZone(zoneId);
    let objects = mapListToDatabaseObjects(objectTypeName, entries);

    try {
      let result = await zone.delete(objects);
      hilog.info(DOMAIN, TAG, `delete 成功，删除行数: ${result}`);
      return result;
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `delete 失败, code: ${error.code}, message: ${error.message}`);
      throw new Error(`delete 失败, code: ${error.code}, message: ${error.message}`);
    }
  }

  /**
   * 执行 query 操作
   */
  async executeQuery(zoneId: string, queryMap: Map<string, Object>): Promise<Map<string, Object>> {
    let zone = this.getZone(zoneId);
    let condition = buildDatabaseQuery(queryMap);

    try {
      let resultList = await zone.query(condition);
      let snapshotObjects = databaseObjectsToMapList(resultList as Object[]);

      // 构建 Dart 层期望的 snapshot 返回格式
      let result = new Map<string, Object>();
      result.set('isFromCloud', true);
      result.set('hasPendingWrites', false);
      result.set('snapshotObjects', snapshotObjects);
      result.set('upsertedObjects', [] as Array<Map<string, Object | null>>);
      result.set('deletedObjects', [] as Array<Map<string, Object | null>>);

      hilog.info(DOMAIN, TAG, `query 成功，结果数量: ${resultList.length}`);
      return result;
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `query 失败, code: ${error.code}, message: ${error.message}`);
      throw new Error(`query 失败, code: ${error.code}, message: ${error.message}`);
    }
  }

  /**
   * 执行聚合查询（average/sum/maximum/minimum/count）
   */
  async executeCalculateQuery(zoneId: string, queryMap: Map<string, Object>, fieldName: string, methodName: string): Promise<number> {
    let zone = this.getZone(zoneId);
    let condition = buildDatabaseQuery(queryMap);
    let calculateType = getQueryCalculateType(methodName);

    try {
      let result = await zone.calculateQuery(condition, fieldName, calculateType);
      hilog.info(DOMAIN, TAG, `calculateQuery(${methodName}) 成功，结果: ${result}`);
      return result;
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `calculateQuery(${methodName}) 失败, code: ${error.code}, message: ${error.message}`);
      throw new Error(`calculateQuery(${methodName}) 失败, code: ${error.code}, message: ${error.message}`);
    }
  }

  /**
   * 执行未同步数据查询
   * HarmonyOS 不直接支持此功能，使用普通查询代替
   */
  async executeQueryUnsynced(zoneId: string, queryMap: Map<string, Object>): Promise<Map<string, Object>> {
    hilog.warn(DOMAIN, TAG, 'executeQueryUnsynced: HarmonyOS 不直接支持未同步查询，使用普通查询代替');
    return this.executeQuery(zoneId, queryMap);
  }

  /**
   * 执行服务器状态查询
   * HarmonyOS 不直接支持，返回当前时间戳
   */
  executeServerStatusQuery(): Map<string, Object> {
    let result = new Map<string, Object>();
    result.set('serverTimeStamp', Date.now());
    return result;
  }

  /**
   * 执行事务
   * HarmonyOS cloudDatabase 不直接支持事务 API，
   * 通过顺序执行 upsert 和 delete 来模拟
   */
  async runTransaction(zoneId: string, transactionElements: Array<Map<string, Object>>): Promise<void> {
    let zone = this.getZone(zoneId);

    for (let i = 0; i < transactionElements.length; i++) {
      let element = transactionElements[i];
      let operation = element.get('operation') as string;
      let objectTypeName = element.get('zoneObjectTypeName') as string;
      let entries = element.get('zoneObjectDataEntries') as Array<Map<string, Object>>;
      let objects = mapListToDatabaseObjects(objectTypeName, entries);

      try {
        if (operation === 'executeUpsert') {
          await zone.upsert(objects);
        } else if (operation === 'executeDelete') {
          await zone.delete(objects);
        }
      } catch (err) {
        let error = err as BusinessError;
        hilog.error(DOMAIN, TAG, `事务操作失败, operation: ${operation}, code: ${error.code}, message: ${error.message}`);
        throw new Error(`事务操作失败, operation: ${operation}, code: ${error.code}, message: ${error.message}`);
      }
    }

    hilog.info(DOMAIN, TAG, '事务执行成功');
  }

  /**
   * 启用网络同步
   * HarmonyOS 不提供此 API，忽略
   */
  enableNetwork(zoneName: string): void {
    hilog.info(DOMAIN, TAG, `enableNetwork: ${zoneName}（HarmonyOS 不支持此操作）`);
  }

  /**
   * 禁用网络同步
   * HarmonyOS 不提供此 API，忽略
   */
  disableNetwork(zoneName: string): void {
    hilog.info(DOMAIN, TAG, `disableNetwork: ${zoneName}（HarmonyOS 不支持此操作）`);
  }

  /**
   * 设置用户密钥
   * HarmonyOS 不提供此 API，忽略
   */
  setUserKey(): void {
    hilog.info(DOMAIN, TAG, 'setUserKey（HarmonyOS 不支持此操作）');
  }

  /**
   * 更新数据加密密钥
   * HarmonyOS 不提供此 API，忽略
   */
  updateDataEncryptionKey(): void {
    hilog.info(DOMAIN, TAG, 'updateDataEncryptionKey（HarmonyOS 不支持此操作）');
  }

  /**
   * 获取 CloudDB Zone 配置列表
   * HarmonyOS 不提供此 API，返回空列表
   */
  getCloudDBZoneConfigs(): Array<Map<string, Object>> {
    hilog.info(DOMAIN, TAG, 'getCloudDBZoneConfigs（HarmonyOS 不支持此操作，返回空列表）');
    return [];
  }

  /**
   * 获取指定 Zone 的配置
   */
  getCloudDBZoneConfig(zoneId: string): Map<string, Object> {
    let zoneName = this.zoneIdToName.get(zoneId) ?? '';
    let result = new Map<string, Object>();
    result.set('zoneName', zoneName);
    result.set('syncProperty', 'CLOUDDBZONE_CLOUD_CACHE');
    result.set('accessProperty', 'CLOUDDBZONE_PUBLIC');
    result.set('capacity', 104857600);
    result.set('isPersistenceEnabled', true);
    result.set('isEncrypted', false);
    return result;
  }
}
