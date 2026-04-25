import {
  FlutterPluginBinding,
  MethodCall,
  MethodResult,
} from '@ohos/flutter_ohos';
import { cloudStorage } from '@kit.CloudFoundationKit';
import { BusinessError, request } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { handleError, metadataToMap } from './AgconnectStorageUtils';
import { AgconnectStorageTaskManager } from './AgconnectStorageTaskManager';

/**
 * 处理 AGCStorageReference# 前缀的方法调用。
 * 对应 Dart 层 AGCStorageReference 中的所有操作方法。
 */
export class AgconnectStorageReferenceHandler {
  private binding: FlutterPluginBinding;
  private context: common.Context;
  private taskManager: AgconnectStorageTaskManager;

  constructor(binding: FlutterPluginBinding, taskManager: AgconnectStorageTaskManager) {
    this.binding = binding;
    this.context = binding.getApplicationContext();
    this.taskManager = taskManager;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    let method = (call.method as string).split('#')[1];
    switch (method) {
      case 'getMetadata':
        this.getMetadata(call, result);
        break;
      case 'updateMetadata':
        this.updateMetadata(call, result);
        break;
      case 'deleteFile':
        this.deleteFile(call, result);
        break;
      case 'uploadFile':
        this.uploadFile(call, result);
        break;
      case 'uploadData':
        this.uploadData(call, result);
        break;
      case 'downloadToFile':
        this.downloadToFile(call, result);
        break;
      case 'downloadData':
        this.downloadData(call, result);
        break;
      case 'getDownloadUrl':
        this.getDownloadUrl(call, result);
        break;
      case 'list':
        this.list(call, result);
        break;
      case 'listAll':
        this.listAll(call, result);
        break;
      case 'getActiveUploadTasks':
        this.getActiveUploadTasks(call, result);
        break;
      case 'getActiveDownloadTasks':
        this.getActiveDownloadTasks(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /** 获取文件元数据 */
  private getMetadata(call: MethodCall, result: MethodResult): void {
    let cloudPath = this.stripLeadingSlash(call.argument('objectPath') as string);
    let bucket = this.getBucket(call);
    bucket.getMetadata(cloudPath)
      .then((meta: cloudStorage.Metadata) => {
        result.success(metadataToMap(meta));
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 更新元数据（覆盖模式） */
  private updateMetadata(call: MethodCall, result: MethodResult): void {
    let cloudPath = this.stripLeadingSlash(call.argument('objectPath') as string);
    let metadataMap = call.argument('metadata') as Record<string, Object>;
    let bucket = this.getBucket(call);

    // 构建 setMetadata 参数
    let metaParam: Record<string, Object> = {};
    if (metadataMap['cacheControl']) {
      metaParam['cacheControl'] = metadataMap['cacheControl'] as Object;
    }
    if (metadataMap['contentType']) {
      metaParam['contentType'] = metadataMap['contentType'] as Object;
    }
    if (metadataMap['contentDisposition']) {
      metaParam['contentDisposition'] = metadataMap['contentDisposition'] as Object;
    }
    if (metadataMap['contentEncoding']) {
      metaParam['contentEncoding'] = metadataMap['contentEncoding'] as Object;
    }
    if (metadataMap['contentLanguage']) {
      metaParam['contentLanguage'] = metadataMap['contentLanguage'] as Object;
    }
    if (metadataMap['customMetadata']) {
      metaParam['customMetadata'] = metadataMap['customMetadata'] as Object;
    }

    bucket.setMetadata(cloudPath, metaParam as Object as cloudStorage.Metadata)
      .then(() => {
        // setMetadata 成功后再获取一次完整的 metadata 返回
        return bucket.getMetadata(cloudPath);
      })
      .then((meta: cloudStorage.Metadata) => {
        result.success(metadataToMap(meta));
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 删除云端文件 */
  private deleteFile(call: MethodCall, result: MethodResult): void {
    let cloudPath = this.stripLeadingSlash(call.argument('objectPath') as string);
    let bucket = this.getBucket(call);
    bucket.deleteFile(cloudPath)
      .then(() => {
        result.success(null);
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /**
   * 上传本地文件到云端。
   * Dart 层传入 filePath（本地绝对路径）和 objectPath（云端路径）。
   * 鸿蒙端需要先将文件拷贝到缓存目录，再调用 bucket.uploadFile()。
   */
  private uploadFile(call: MethodCall, result: MethodResult): void {
    let cloudPath = this.stripLeadingSlash(call.argument('objectPath') as string);
    let filePath = call.argument('filePath') as string;
    let bucket = this.getBucket(call);

    try {
      // 生成唯一的缓存文件名
      let fileName = filePath.split('/').pop() as string;
      let cacheFile = `${Date.now()}_${fileName}`;
      let cachePath = this.context.cacheDir + '/' + cacheFile;

      // 将源文件拷贝到缓存目录（uploadFile 要求文件在缓存目录中）
      let srcFile = fs.openSync(filePath);
      let dstFile = fs.openSync(cachePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.copyFileSync(srcFile.fd, dstFile.fd);
      fs.closeSync(srcFile);
      fs.closeSync(dstFile);

      // 生成任务 ID 并返回给 Dart
      let taskId = this.taskManager.generateUploadTaskId();

      bucket.uploadFile(this.context, {
        localPath: cacheFile,
        cloudPath: cloudPath,
        mode: request.agent.Mode.FOREGROUND,
      })
        .then((task: request.agent.Task) => {
          // 先注册 EventChannel，确保 Dart 端 listen 时 StreamHandler 已就绪
          this.taskManager.registerUploadTask(taskId, task, this.binding, cloudPath, cachePath);

          // 返回 taskId 给 Dart（必须在 EventChannel 注册之后）
          result.success(taskId);

          // 启动任务
          task.start((err: BusinessError) => {
            if (err) {
              console.error(`[CloudStorage] 上传任务启动失败: ${err.message}`);
            }
          });
        })
        .catch((err: BusinessError) => {
          // 清理缓存文件
          fs.unlink(cachePath).catch(() => {});
          handleError(result, err);
        });
    } catch (e) {
      handleError(result, e as Error);
    }
  }

  /**
   * 上传字节数据到云端。
   * 鸿蒙 CloudStorage 没有直接上传字节的 API，
   * 需先将字节写入临时文件，再使用 uploadFile 上传。
   */
  private uploadData(call: MethodCall, result: MethodResult): void {
    let cloudPath = this.stripLeadingSlash(call.argument('objectPath') as string);
    let bytes = call.argument('bytes') as Uint8Array;
    let bucket = this.getBucket(call);

    try {
      // 将字节数据写入临时文件
      let tempFileName = `upload_data_${Date.now()}.tmp`;
      let tempPath = this.context.cacheDir + '/' + tempFileName;
      let file = fs.openSync(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, bytes.buffer);
      fs.closeSync(file);

      let taskId = this.taskManager.generateUploadTaskId();

      bucket.uploadFile(this.context, {
        localPath: tempFileName,
        cloudPath: cloudPath,
        mode: request.agent.Mode.FOREGROUND,
      })
        .then((task: request.agent.Task) => {
          // 先注册 EventChannel，确保 Dart 端 listen 时 StreamHandler 已就绪
          this.taskManager.registerUploadTask(taskId, task, this.binding, cloudPath, tempPath);

          // 返回 taskId 给 Dart（必须在 EventChannel 注册之后）
          result.success(taskId);

          task.start((err: BusinessError) => {
            if (err) {
              console.error(`[CloudStorage] 上传数据任务启动失败: ${err.message}`);
            }
          });
        })
        .catch((err: BusinessError) => {
          fs.unlink(tempPath).catch(() => {});
          handleError(result, err);
        });
    } catch (e) {
      handleError(result, e as Error);
    }
  }

  /** 下载云端文件到本地指定路径 */
  private downloadToFile(call: MethodCall, result: MethodResult): void {
    let cloudPath = this.stripLeadingSlash(call.argument('objectPath') as string);
    let filePath = call.argument('filePath') as string;
    let bucket = this.getBucket(call);

    try {
      // 计算相对于 cacheDir 的路径
      let fileName = filePath.split('/').pop() as string;
      let localRelativePath = `./${Date.now()}_${fileName}`;

      let taskId = this.taskManager.generateDownloadTaskId();

      bucket.downloadFile(this.context, {
        localPath: localRelativePath,
        cloudPath: cloudPath,
      })
        .then((task: request.agent.Task) => {
          let cachePath = this.context.cacheDir + '/' + localRelativePath.replace('./', '');
          // 先注册 EventChannel，确保 Dart 端 listen 时 StreamHandler 已就绪
          this.taskManager.registerDownloadTask(taskId, task, this.binding, filePath, cachePath);

          // 返回 taskId 给 Dart（必须在 EventChannel 注册之后）
          result.success(taskId);

          task.start((err: BusinessError) => {
            if (err) {
              console.error(`[CloudStorage] 下载任务启动失败: ${err.message}`);
            }
          });
        })
        .catch((err: BusinessError) => {
          handleError(result, err);
        });
    } catch (e) {
      handleError(result, e as Error);
    }
  }

  /**
   * 下载云端数据到内存（Uint8List）。
   * 鸿蒙 SDK 没有直接的 downloadData API，
   * 需先下载到临时文件，再读取文件内容返回。
   */
  private downloadData(call: MethodCall, result: MethodResult): void {
    let cloudPath = this.stripLeadingSlash(call.argument('objectPath') as string);
    let bucket = this.getBucket(call);

    try {
      let tempFileName = `download_data_${Date.now()}.tmp`;
      let tempPath = this.context.cacheDir + '/' + tempFileName;

      bucket.downloadFile(this.context, {
        localPath: `./${tempFileName}`,
        cloudPath: cloudPath,
      })
        .then((task: request.agent.Task) => {
          task.on('completed', () => {
            try {
              // 读取下载的临时文件并返回字节数据
              let file = fs.openSync(tempPath, fs.OpenMode.READ_ONLY);
              let stat = fs.statSync(tempPath);
              let buf = new ArrayBuffer(stat.size);
              fs.readSync(file.fd, buf);
              fs.closeSync(file);
              // 清理临时文件
              fs.unlink(tempPath).catch(() => {});
              result.success(new Uint8Array(buf));
            } catch (readErr) {
              handleError(result, readErr as Error);
            }
          });
          task.on('failed', () => {
            fs.unlink(tempPath).catch(() => {});
            let errDetails: Record<string, Object> = {};
            errDetails['exceptionType'] = 'StorageException';
            result.error('DOWNLOAD_FAILED', '下载数据失败', errDetails);
          });
          task.start((err: BusinessError) => {
            if (err) {
              fs.unlink(tempPath).catch(() => {});
              handleError(result, err);
            }
          });
        })
        .catch((err: BusinessError) => {
          handleError(result, err);
        });
    } catch (e) {
      handleError(result, e as Error);
    }
  }

  /** 获取文件的下载 URL */
  private getDownloadUrl(call: MethodCall, result: MethodResult): void {
    let cloudPath = this.stripLeadingSlash(call.argument('objectPath') as string);
    let bucket = this.getBucket(call);
    bucket.getDownloadURL(cloudPath)
      .then((downloadURL: string) => {
        result.success(downloadURL);
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 分页列出目录下的文件和子目录 */
  private list(call: MethodCall, result: MethodResult): void {
    let cloudPath = this.stripLeadingSlash(call.argument('objectPath') as string);
    let max = call.argument('max') as number;
    let bucket = this.getBucket(call);

    // 鸿蒙 bucket.list 支持 maxResults 参数
    let listPath = cloudPath ?? '';
    bucket.list(listPath, { maxResults: max })
      .then((listResult: Object) => {
        result.success(this.listResultToMap(listResult));
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 列出目录下所有文件和子目录 */
  private listAll(call: MethodCall, result: MethodResult): void {
    let cloudPath = this.stripLeadingSlash(call.argument('objectPath') as string);
    let bucket = this.getBucket(call);
    let listPath = cloudPath ?? '';
    bucket.list(listPath)
      .then((listResult: Object) => {
        result.success(this.listResultToMap(listResult));
      })
      .catch((err: BusinessError) => {
        handleError(result, err);
      });
  }

  /** 获取当前活跃的上传任务 ID 列表 */
  private getActiveUploadTasks(call: MethodCall, result: MethodResult): void {
    result.success(this.taskManager.getActiveUploadTaskIds());
  }

  /** 获取当前活跃的下载任务 ID 列表 */
  private getActiveDownloadTasks(call: MethodCall, result: MethodResult): void {
    result.success(this.taskManager.getActiveDownloadTaskIds());
  }

  /** 获取 StorageBucket 实例 */
  private getBucket(call: MethodCall): cloudStorage.StorageBucket {
    let bucketName = call.argument('bucket') as string | null;
    if (bucketName) {
      return cloudStorage.bucket(bucketName);
    }
    return cloudStorage.bucket();
  }

  /**
   * 去掉云端路径前缀的 '/'。
   * Dart 层 AGCStorageReference 构造函数会自动给 path 加前缀 '/'，
   * 但鸿蒙 CloudStorage SDK 的 cloudPath 参数不应以 '/' 开头。
   * 例如：'/users/uid/avatar/xxx.jpg' → 'users/uid/avatar/xxx.jpg'
   */
  private stripLeadingSlash(path: string): string {
    if (path.startsWith('/')) {
      return path.substring(1);
    }
    return path;
  }

  /**
   * 将鸿蒙 list 返回结果转换为 Dart 层期望的 Map。
   * Dart 层期望：{ fileList: [String], dirList: [String], pageMarker: String? }
   */
  private listResultToMap(listResult: Object): Record<string, Object> {
    let map: Record<string, Object> = {};
    let resultObj = listResult as Record<string, Object>;

    // 鸿蒙 list 返回的结构可能是 { fileList: [], dirList: [], pageMarker: '' }
    let fileList: string[] = [];
    let dirList: string[] = [];

    if (resultObj['fileList'] && Array.isArray(resultObj['fileList'])) {
      let files = resultObj['fileList'] as Object[];
      for (let item of files) {
        // 每个 item 可能是字符串路径或对象
        if (typeof item === 'string') {
          fileList.push(item as string);
        } else if ((item as Record<string, Object>)['path']) {
          fileList.push((item as Record<string, Object>)['path'] as string);
        }
      }
    }

    if (resultObj['dirList'] && Array.isArray(resultObj['dirList'])) {
      let dirs = resultObj['dirList'] as Object[];
      for (let item of dirs) {
        if (typeof item === 'string') {
          dirList.push(item as string);
        } else if ((item as Record<string, Object>)['path']) {
          dirList.push((item as Record<string, Object>)['path'] as string);
        }
      }
    }

    map['fileList'] = fileList;
    map['dirList'] = dirList;
    map['pageMarker'] = resultObj['pageMarker'] !== undefined ? resultObj['pageMarker'] : '' as Object;
    return map;
  }
}
