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
import { ClouddbLocalCache } from './ClouddbLocalCache';

const TAG = 'AgconnectClouddbZoneManager';
const DOMAIN = 0x0001;

/**
 * CloudDB Zone 管理器
 * 管理所有 Zone 实例，处理数据操作（CRUD、查询、事务等）
 *
 * 离线策略：
 * - 写操作（upsert/delete/transaction）成功后同步写入本地缓存
 * - 读操作（query/calculateQuery）云端超时或失败时降级读取本地缓存
 * - LOCAL_ONLY 策略直接读取本地缓存
 */
export class AgconnectClouddbZoneManager {
  // zone 实例缓存，key 为 zoneId（这里使用 zoneName 作为 zoneId）
  private zoneMap: Map<string, cloudDatabase.DatabaseZone> = new Map();
  // zoneId 到 zoneName 的映射
  private zoneIdToName: Map<string, string> = new Map();
  private nextZoneId: number = 0;

  // 本地缓存实例（由 Plugin 入口注入）
  private localCache: ClouddbLocalCache | null = null;

  /**
   * 设置本地缓存实例
   */
  setLocalCache(cache: ClouddbLocalCache): void {
    this.localCache = cache;
  }

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
   * 云端成功后同步写入本地缓存
   */
  async executeUpsert(zoneId: string, objectTypeName: string, entries: Array<Map<string, Object>>): Promise<number> {
    let zone = this.getZone(zoneId);
    let objects = mapListToDatabaseObjects(objectTypeName, entries);

    try {
      let result = await zone.upsert(objects);
      hilog.info(DOMAIN, TAG, `upsert 成功，影响行数: ${result}`);

      // 云端成功，异步写入本地缓存（不阻塞主流程）
      this.syncUpsertToCache(objectTypeName, entries);

      return result;
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `upsert 失败, code: ${error.code}, message: ${error.message}`);
      throw new Error(`upsert 失败, code: ${error.code}, message: ${error.message}`);
    }
  }

  /**
   * 执行 delete 操作
   * 云端成功后同步删除本地缓存
   */
  async executeDelete(zoneId: string, objectTypeName: string, entries: Array<Map<string, Object>>): Promise<number> {
    let zone = this.getZone(zoneId);
    let objects = mapListToDatabaseObjects(objectTypeName, entries);

    try {
      let result = await zone.delete(objects);
      hilog.info(DOMAIN, TAG, `delete 成功，删除行数: ${result}`);

      // 云端成功，异步删除本地缓存
      this.syncDeleteToCache(objectTypeName, entries);

      return result;
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `delete 失败, code: ${error.code}, message: ${error.message}`);
      throw new Error(`delete 失败, code: ${error.code}, message: ${error.message}`);
    }
  }

  // QueryPolicy 枚举索引（对齐 Dart 层 AGConnectCloudDBZoneQueryPolicy）
  // 0 = POLICY_QUERY_FROM_LOCAL_ONLY
  // 1 = POLICY_QUERY_FROM_CLOUD_ONLY
  // 2 = POLICY_QUERY_DEFAULT（在线查云端，离线降级本地）
  private static readonly POLICY_LOCAL_ONLY: number = 0;
  private static readonly POLICY_CLOUD_ONLY: number = 1;
  private static readonly POLICY_DEFAULT: number = 2;

  // POLICY_QUERY_DEFAULT 模式下云端查询超时时间（毫秒）
  private static readonly CLOUD_QUERY_TIMEOUT_MS: number = 10000;

  /**
   * 执行 query 操作
   *
   * HarmonyOS cloudDatabase.DatabaseZone.query() 不支持 QueryPolicy 参数，
   * 且无网络时 Promise 会永远 pending（既不 resolve 也不 reject）。
   *
   * 此方法根据 policyIndex 实现与 Android/iOS SDK 对齐的查询策略：
   * - LOCAL_ONLY(0)：直接读本地缓存
   * - CLOUD_ONLY(1)：仅查云端，成功后回写缓存
   * - DEFAULT(2)：先尝试云端查询（带超时），超时/失败后降级读本地缓存
   */
  async executeQuery(zoneId: string, queryMap: Map<string, Object>, policyIndex: number): Promise<Map<string, Object>> {
    let zone = this.getZone(zoneId);
    let condition = buildDatabaseQuery(queryMap);

    if (policyIndex === AgconnectClouddbZoneManager.POLICY_LOCAL_ONLY) {
      // 仅本地查询：直接读缓存
      return this.queryFromCache(queryMap);

    } else if (policyIndex === AgconnectClouddbZoneManager.POLICY_CLOUD_ONLY) {
      // 仅云端查询：直接调用，成功后回写缓存
      let result = await this.queryDirect(zone, condition, false);
      this.syncQueryResultToCache(queryMap, result);
      return result;

    } else {
      // DEFAULT：先尝试云端（带超时），超时后降级读本地缓存
      return this.queryWithCacheFallback(zone, condition, queryMap);
    }
  }

  /**
   * 直接查询（无超时保护）
   */
  private async queryDirect(zone: cloudDatabase.DatabaseZone, condition: cloudDatabase.DatabaseQuery<DynamicDatabaseObject>, isLocal: boolean): Promise<Map<string, Object>> {
    try {
      let resultList = await zone.query(condition);
      return this.buildSnapshotResult(resultList as Object[], !isLocal);
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `query 失败, code: ${error.code}, message: ${error.message}`);
      throw new Error(`query 失败, code: ${error.code}, message: ${error.message}`);
    }
  }

  /**
   * 带超时的查询
   *
   * 超时时抛出异常（由调用方决定降级策略）
   */
  private queryWithTimeout(zone: cloudDatabase.DatabaseZone, condition: cloudDatabase.DatabaseQuery<DynamicDatabaseObject>, timeoutMs: number): Promise<Map<string, Object>> {
    return new Promise<Map<string, Object>>((resolve, reject) => {
      let settled = false;

      // 超时定时器
      let timer = setTimeout(() => {
        if (!settled) {
          settled = true;
          hilog.warn(DOMAIN, TAG, `query 超时(${timeoutMs}ms)`);
          reject(new Error(`query 超时(${timeoutMs}ms)`));
        }
      }, timeoutMs);

      // 实际查询
      zone.query(condition).then((resultList: DynamicDatabaseObject[]) => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(this.buildSnapshotResult(resultList as Object[], true));
        }
      }).catch((err: BusinessError) => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          reject(err);
        }
      });
    });
  }

  /**
   * DEFAULT 策略：云端查询 + 超时降级本地缓存
   *
   * 1. 先发起云端查询（带超时）
   * 2. 成功则回写缓存并返回
   * 3. 超时或失败则降级读本地缓存
   */
  private async queryWithCacheFallback(zone: cloudDatabase.DatabaseZone, condition: cloudDatabase.DatabaseQuery<DynamicDatabaseObject>, queryMap: Map<string, Object>): Promise<Map<string, Object>> {
    try {
      // 云端查询（带超时）
      let result = await this.queryWithTimeout(zone, condition, AgconnectClouddbZoneManager.CLOUD_QUERY_TIMEOUT_MS);
      // 云端成功，回写缓存
      this.syncQueryResultToCache(queryMap, result);
      return result;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `云端查询失败或超时，降级读本地缓存: ${(e as Error).message}`);
      // 降级：读本地缓存
      return this.queryFromCache(queryMap);
    }
  }

  /**
   * 从本地缓存读取数据
   * 等待缓存初始化完成后再读取，缓存不可用时返回空结果（保证不阻塞）
   */
  private async queryFromCache(queryMap: Map<string, Object>): Promise<Map<string, Object>> {
    if (this.localCache) {
      await this.localCache.waitForReady();
      if (this.localCache.isReady()) {
        let cacheResult = await this.localCache.query(queryMap);
        if (cacheResult) {
          hilog.info(DOMAIN, TAG, '从本地缓存返回数据');
          return cacheResult;
        }
      }
    }
    hilog.warn(DOMAIN, TAG, '本地缓存不可用，返回空结果');
    return this.buildEmptySnapshotResult();
  }

  /**
   * 构建 Dart 层期望的 snapshot 返回格式
   */
  private buildSnapshotResult(resultList: Object[], isFromCloud: boolean): Map<string, Object> {
    let snapshotObjects = databaseObjectsToMapList(resultList);
    let result = new Map<string, Object>();
    result.set('isFromCloud', isFromCloud);
    result.set('hasPendingWrites', false);
    result.set('snapshotObjects', snapshotObjects);
    result.set('upsertedObjects', [] as Array<Map<string, Object | null>>);
    result.set('deletedObjects', [] as Array<Map<string, Object | null>>);

    hilog.info(DOMAIN, TAG, `query 成功，结果数量: ${snapshotObjects.length}, isFromCloud: ${isFromCloud}`);
    return result;
  }

  /**
   * 构建空的 snapshot 返回格式
   */
  private buildEmptySnapshotResult(): Map<string, Object> {
    let result = new Map<string, Object>();
    result.set('isFromCloud', false);
    result.set('hasPendingWrites', false);
    result.set('snapshotObjects', [] as Array<Map<string, Object | null>>);
    result.set('upsertedObjects', [] as Array<Map<string, Object | null>>);
    result.set('deletedObjects', [] as Array<Map<string, Object | null>>);
    return result;
  }

  /**
   * 执行聚合查询（average/sum/maximum/minimum/count）
   *
   * 与 executeQuery 同理，根据 policyIndex 添加超时保护和本地缓存降级。
   */
  async executeCalculateQuery(zoneId: string, queryMap: Map<string, Object>, fieldName: string, methodName: string, policyIndex: number): Promise<number> {
    let zone = this.getZone(zoneId);
    let condition = buildDatabaseQuery(queryMap);
    let calculateType = getQueryCalculateType(methodName);

    let doQuery = (): Promise<number> => {
      return zone.calculateQuery(condition, fieldName, calculateType);
    };

    if (policyIndex === AgconnectClouddbZoneManager.POLICY_LOCAL_ONLY) {
      // 仅本地：直接读缓存
      return this.calculateFromCache(queryMap, fieldName, methodName);

    } else if (policyIndex === AgconnectClouddbZoneManager.POLICY_CLOUD_ONLY) {
      // 仅云端：直接调用
      try {
        let result = await doQuery();
        hilog.info(DOMAIN, TAG, `calculateQuery(${methodName}) 成功，结果: ${result}`);
        return result;
      } catch (err) {
        let error = err as BusinessError;
        hilog.error(DOMAIN, TAG, `calculateQuery(${methodName}) 失败, code: ${error.code}, message: ${error.message}`);
        throw new Error(`calculateQuery(${methodName}) 失败, code: ${error.code}, message: ${error.message}`);
      }

    } else {
      // DEFAULT：云端超时后降级读缓存
      try {
        return await this.calculateWithTimeout(doQuery, AgconnectClouddbZoneManager.CLOUD_QUERY_TIMEOUT_MS, methodName);
      } catch (e) {
        hilog.warn(DOMAIN, TAG, `calculateQuery(${methodName}) 云端超时，降级读缓存: ${(e as Error).message}`);
        return this.calculateFromCache(queryMap, fieldName, methodName);
      }
    }
  }

  /**
   * 带超时的聚合查询
   */
  private calculateWithTimeout(doQuery: () => Promise<number>, timeoutMs: number, methodName: string): Promise<number> {
    return new Promise<number>((resolve, reject) => {
      let settled = false;

      let timer = setTimeout(() => {
        if (!settled) {
          settled = true;
          reject(new Error(`calculateQuery(${methodName}) 超时(${timeoutMs}ms)`));
        }
      }, timeoutMs);

      doQuery().then((result: number) => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          hilog.info(DOMAIN, TAG, `calculateQuery(${methodName}) 成功，结果: ${result}`);
          resolve(result);
        }
      }).catch((err: BusinessError) => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          reject(err);
        }
      });
    });
  }

  /**
   * 从本地缓存执行聚合查询
   * 等待缓存初始化完成后再执行
   */
  private async calculateFromCache(queryMap: Map<string, Object>, fieldName: string, methodName: string): Promise<number> {
    if (this.localCache) {
      await this.localCache.waitForReady();
      if (this.localCache.isReady()) {
        let result = await this.localCache.calculateQuery(queryMap, fieldName, methodName);
        if (result !== null) {
          hilog.info(DOMAIN, TAG, `缓存 calculateQuery(${methodName}) 结果: ${result}`);
          return result;
        }
      }
    }
    hilog.warn(DOMAIN, TAG, `缓存 calculateQuery 不可用，返回 0`);
    return 0;
  }

  // ==================== 缓存同步（异步，不阻塞主流程） ====================

  /**
   * 将 upsert 数据同步写入本地缓存
   */
  private syncUpsertToCache(objectTypeName: string, entries: Array<Map<string, Object>>): void {
    if (!this.localCache || !this.localCache.isReady()) return;

    // 转为 Map<string, Object | null> 格式
    let cacheEntries: Array<Map<string, Object | null>> = [];
    for (let i = 0; i < entries.length; i++) {
      let entry = entries[i];
      let cacheEntry = new Map<string, Object | null>();
      entry.forEach((value: Object, key: string) => {
        cacheEntry.set(key, value);
      });
      cacheEntries.push(cacheEntry);
    }

    this.localCache.upsert(objectTypeName, cacheEntries).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, `缓存同步 upsert 失败: ${err.message}`);
    });
  }

  /**
   * 将 delete 数据同步到本地缓存
   */
  private syncDeleteToCache(objectTypeName: string, entries: Array<Map<string, Object>>): void {
    if (!this.localCache || !this.localCache.isReady()) return;

    let cacheEntries: Array<Map<string, Object | null>> = [];
    for (let i = 0; i < entries.length; i++) {
      let entry = entries[i];
      let cacheEntry = new Map<string, Object | null>();
      entry.forEach((value: Object, key: string) => {
        cacheEntry.set(key, value);
      });
      cacheEntries.push(cacheEntry);
    }

    this.localCache.delete(objectTypeName, cacheEntries).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, `缓存同步 delete 失败: ${err.message}`);
    });
  }

  /**
   * 将云端查询结果回写本地缓存
   * 从 snapshotObjects 提取数据，做全量 upsert
   */
  private syncQueryResultToCache(queryMap: Map<string, Object>, result: Map<string, Object>): void {
    if (!this.localCache || !this.localCache.isReady()) return;

    let objectTypeName = (queryMap.get('zoneObjectTypeName') as string) ?? '';
    let snapshotObjects = result.get('snapshotObjects') as Array<Map<string, Object | null>>;
    if (!snapshotObjects || snapshotObjects.length === 0 || !objectTypeName) return;

    this.localCache.upsert(objectTypeName, snapshotObjects).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, `缓存回写查询结果失败: ${err.message}`);
    });
  }

  /**
   * 执行未同步数据查询
   * HarmonyOS 不直接支持此功能，使用本地缓存查询代替
   */
  async executeQueryUnsynced(zoneId: string, queryMap: Map<string, Object>): Promise<Map<string, Object>> {
    hilog.warn(DOMAIN, TAG, 'executeQueryUnsynced: HarmonyOS 不直接支持未同步查询，使用本地缓存查询代替');
    return this.executeQuery(zoneId, queryMap, AgconnectClouddbZoneManager.POLICY_LOCAL_ONLY);
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
   * 通过顺序执行 upsert 和 delete 来模拟。
   * 云端成功后同步写入本地缓存。
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
          // 事务中的 upsert 同步到缓存
          this.syncUpsertToCache(objectTypeName, entries);
        } else if (operation === 'executeDelete') {
          await zone.delete(objects);
          // 事务中的 delete 同步到缓存
          this.syncDeleteToCache(objectTypeName, entries);
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
