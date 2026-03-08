import { MethodCall, MethodResult } from '@ohos/flutter_ohos';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AgconnectClouddbZoneManager } from './AgconnectClouddbZoneManager';

const TAG = 'AgconnectClouddbMethodHandler';
const DOMAIN = 0x0001;

/**
 * CloudDB 方法调度处理器
 * 负责接收 Dart 层 MethodChannel 调用，分发到对应的业务逻辑
 */
export class AgconnectClouddbMethodHandler {
  private zoneManager: AgconnectClouddbZoneManager = new AgconnectClouddbZoneManager();

  /**
   * 处理方法调用
   */
  onMethodCall(call: MethodCall, result: MethodResult): void {
    hilog.info(DOMAIN, TAG, `收到方法调用: ${call.method}`);

    switch (call.method) {
      case 'initialize':
        this.handleInitialize(result);
        break;
      case 'createObjectType':
        this.handleCreateObjectType(result);
        break;
      case 'getCloudDBZoneConfigs':
        this.handleGetCloudDBZoneConfigs(result);
        break;
      case 'openCloudDBZone':
      case 'openCloudDBZone2':
        this.handleOpenCloudDBZone(call, result);
        break;
      case 'closeCloudDBZone':
        this.handleCloseCloudDBZone(call, result);
        break;
      case 'deleteCloudDBZone':
        this.handleDeleteCloudDBZone(call, result);
        break;
      case 'enableNetwork':
        this.handleEnableNetwork(call, result);
        break;
      case 'disableNetwork':
        this.handleDisableNetwork(call, result);
        break;
      case 'setUserKey':
        this.handleSetUserKey(result);
        break;
      case 'updateDataEncryptionKey':
        this.handleUpdateDataEncryptionKey(result);
        break;
      case 'getCloudDBZoneConfig':
        this.handleGetCloudDBZoneConfig(call, result);
        break;
      case 'executeUpsert':
        this.handleExecuteUpsert(call, result);
        break;
      case 'executeDelete':
        this.handleExecuteDelete(call, result);
        break;
      case 'executeQuery':
        this.handleExecuteQuery(call, result);
        break;
      case 'executeAverageQuery':
      case 'executeSumQuery':
      case 'executeMaximumQuery':
      case 'executeMinimalQuery':
      case 'executeCountQuery':
        this.handleExecuteCalculateQuery(call, result);
        break;
      case 'executeQueryUnsynced':
        this.handleExecuteQueryUnsynced(call, result);
        break;
      case 'executeServerStatusQuery':
        this.handleExecuteServerStatusQuery(call, result);
        break;
      case 'runTransaction':
        this.handleRunTransaction(call, result);
        break;
      case 'subscribeSnapshot':
        this.handleSubscribeSnapshot(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  // ======================== AGConnectCloudDB 方法 ========================

  private handleInitialize(result: MethodResult): void {
    try {
      this.zoneManager.initialize();
      result.success(null);
    } catch (err) {
      this.handleError(err, result);
    }
  }

  private handleCreateObjectType(result: MethodResult): void {
    try {
      this.zoneManager.createObjectType();
      result.success(null);
    } catch (err) {
      this.handleError(err, result);
    }
  }

  private handleGetCloudDBZoneConfigs(result: MethodResult): void {
    try {
      let configs = this.zoneManager.getCloudDBZoneConfigs();
      result.success(configs);
    } catch (err) {
      this.handleError(err, result);
    }
  }

  private handleOpenCloudDBZone(call: MethodCall, result: MethodResult): void {
    try {
      let args = call.args as Map<string, Object>;
      let zoneConfig = args.get('zoneConfig') as Map<string, Object>;
      let zoneResult = this.zoneManager.openCloudDBZone(zoneConfig);
      result.success(zoneResult);
    } catch (err) {
      this.handleError(err, result);
    }
  }

  private handleCloseCloudDBZone(call: MethodCall, result: MethodResult): void {
    try {
      let args = call.args as Map<string, Object>;
      let zoneId = args.get('zoneId') as string;
      this.zoneManager.closeCloudDBZone(zoneId);
      result.success(null);
    } catch (err) {
      this.handleError(err, result);
    }
  }

  private handleDeleteCloudDBZone(call: MethodCall, result: MethodResult): void {
    try {
      let args = call.args as Map<string, Object>;
      let zoneName = args.get('zoneName') as string;
      this.zoneManager.deleteCloudDBZone(zoneName);
      result.success(null);
    } catch (err) {
      this.handleError(err, result);
    }
  }

  private handleEnableNetwork(call: MethodCall, result: MethodResult): void {
    try {
      let args = call.args as Map<string, Object>;
      let zoneName = args.get('zoneName') as string;
      this.zoneManager.enableNetwork(zoneName);
      result.success(null);
    } catch (err) {
      this.handleError(err, result);
    }
  }

  private handleDisableNetwork(call: MethodCall, result: MethodResult): void {
    try {
      let args = call.args as Map<string, Object>;
      let zoneName = args.get('zoneName') as string;
      this.zoneManager.disableNetwork(zoneName);
      result.success(null);
    } catch (err) {
      this.handleError(err, result);
    }
  }

  private handleSetUserKey(result: MethodResult): void {
    try {
      this.zoneManager.setUserKey();
      result.success(null);
    } catch (err) {
      this.handleError(err, result);
    }
  }

  private handleUpdateDataEncryptionKey(result: MethodResult): void {
    try {
      this.zoneManager.updateDataEncryptionKey();
      result.success(null);
    } catch (err) {
      this.handleError(err, result);
    }
  }

  // ======================== AGConnectCloudDBZone 方法 ========================

  private handleGetCloudDBZoneConfig(call: MethodCall, result: MethodResult): void {
    try {
      let args = call.args as Map<string, Object>;
      let zoneId = args.get('zoneId') as string;
      let config = this.zoneManager.getCloudDBZoneConfig(zoneId);
      result.success(config);
    } catch (err) {
      this.handleError(err, result);
    }
  }

  private handleExecuteUpsert(call: MethodCall, result: MethodResult): void {
    let args = call.args as Map<string, Object>;
    let zoneId = args.get('zoneId') as string;
    let objectTypeName = args.get('zoneObjectTypeName') as string;
    let entries = args.get('zoneObjectDataEntries') as Array<Map<string, Object>>;

    this.zoneManager.executeUpsert(zoneId, objectTypeName, entries).then((count: number) => {
      result.success(count);
    }).catch((err: BusinessError) => {
      this.handleError(err, result);
    });
  }

  private handleExecuteDelete(call: MethodCall, result: MethodResult): void {
    let args = call.args as Map<string, Object>;
    let zoneId = args.get('zoneId') as string;
    let objectTypeName = args.get('zoneObjectTypeName') as string;
    let entries = args.get('zoneObjectDataEntries') as Array<Map<string, Object>>;

    this.zoneManager.executeDelete(zoneId, objectTypeName, entries).then((count: number) => {
      result.success(count);
    }).catch((err: BusinessError) => {
      this.handleError(err, result);
    });
  }

  private handleExecuteQuery(call: MethodCall, result: MethodResult): void {
    let args = call.args as Map<string, Object>;
    let zoneId = args.get('zoneId') as string;
    let queryMap = args.get('query') as Map<string, Object>;

    this.zoneManager.executeQuery(zoneId, queryMap).then((data: Map<string, Object>) => {
      result.success(data);
    }).catch((err: BusinessError) => {
      this.handleError(err, result);
    });
  }

  private handleExecuteCalculateQuery(call: MethodCall, result: MethodResult): void {
    let args = call.args as Map<string, Object>;
    let zoneId = args.get('zoneId') as string;
    let queryMap = args.get('query') as Map<string, Object>;
    let fieldName = args.get('field') as string;

    this.zoneManager.executeCalculateQuery(zoneId, queryMap, fieldName, call.method).then((num: number) => {
      result.success(num);
    }).catch((err: BusinessError) => {
      this.handleError(err, result);
    });
  }

  private handleExecuteQueryUnsynced(call: MethodCall, result: MethodResult): void {
    let args = call.args as Map<string, Object>;
    let zoneId = args.get('zoneId') as string;
    let queryMap = args.get('query') as Map<string, Object>;

    this.zoneManager.executeQueryUnsynced(zoneId, queryMap).then((data: Map<string, Object>) => {
      result.success(data);
    }).catch((err: BusinessError) => {
      this.handleError(err, result);
    });
  }

  private handleExecuteServerStatusQuery(call: MethodCall, result: MethodResult): void {
    try {
      let args = call.args as Map<string, Object>;
      let zoneId = args.get('zoneId') as string;
      let data = this.zoneManager.executeServerStatusQuery();
      result.success(data);
    } catch (err) {
      this.handleError(err, result);
    }
  }

  private handleRunTransaction(call: MethodCall, result: MethodResult): void {
    let args = call.args as Map<string, Object>;
    let zoneId = args.get('zoneId') as string;
    let transactionElements = args.get('transactionElements') as Array<Map<string, Object>>;

    this.zoneManager.runTransaction(zoneId, transactionElements).then(() => {
      result.success(null);
    }).catch((err: BusinessError) => {
      this.handleError(err, result);
    });
  }

  private handleSubscribeSnapshot(call: MethodCall, result: MethodResult): void {
    // HarmonyOS cloudDatabase 不直接支持快照订阅
    // 返回成功，但不会主动推送数据变化事件
    hilog.warn(DOMAIN, TAG, 'subscribeSnapshot: HarmonyOS 不直接支持快照订阅');
    result.success(null);
  }

  // ======================== 错误处理 ========================

  private handleError(err: Object, result: MethodResult): void {
    let error = err as BusinessError;
    let code = error.code?.toString() ?? 'UNKNOWN';
    let message = error.message ?? '未知错误';
    hilog.error(DOMAIN, TAG, `操作失败, code: ${code}, message: ${message}`);
    result.error(code, message, null);
  }
}
