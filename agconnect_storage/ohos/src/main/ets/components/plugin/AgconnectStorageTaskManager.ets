import {
  FlutterPluginBinding,
  MethodCall,
  MethodResult,
  EventChannel,
  EventSink,
} from '@ohos/flutter_ohos';
import { BusinessError, request } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';

/** EventChannel 前缀，与 Dart 层 AGCStorageConstants 保持一致 */
const TASK_EVENT_CHANNEL_PREFIX = 'com.huawei.agconnect.cloudstorage/eventChannel/task/';

/**
 * 管理上传/下载任务，维护任务 ID 映射，以及 EventChannel 进度推送。
 */
export class AgconnectStorageTaskManager {
  /** 上传任务：taskId -> request.agent.Task */
  private uploadTasks: Map<string, request.agent.Task | null> = new Map();
  /** 下载任务：taskId -> request.agent.Task */
  private downloadTasks: Map<string, request.agent.Task | null> = new Map();
  /** 任务 ID 计数器 */
  private nextId: number = 0;

  constructor() {
  }

  /** 生成唯一上传任务 ID */
  generateUploadTaskId(): string {
    let taskId = String(this.nextId++);
    this.uploadTasks.set(taskId, null);
    return taskId;
  }

  /** 生成唯一下载任务 ID */
  generateDownloadTaskId(): string {
    let taskId = String(this.nextId++);
    this.downloadTasks.set(taskId, null);
    return taskId;
  }

  /**
   * 注册上传任务并建立 EventChannel 进度监听。
   * @param taskId 任务 ID
   * @param task 鸿蒙上传任务
   * @param binding Flutter 插件绑定
   * @param cloudPath 云端路径（用于构建 metadata）
   * @param cachePath 缓存文件路径（任务完成后清理）
   */
  registerUploadTask(
    taskId: string,
    task: request.agent.Task,
    binding: FlutterPluginBinding,
    cloudPath: string,
    cachePath: string,
  ): void {
    this.uploadTasks.set(taskId, task);

    let eventChannel = new EventChannel(
      binding.getBinaryMessenger(),
      TASK_EVENT_CHANNEL_PREFIX + taskId,
    );

    eventChannel.setStreamHandler({
      onListen: (_args: Object, sink: EventSink) => {
        // 监听进度
        task.on('progress', (progress: request.agent.Progress) => {
          let event: Record<string, Object> = {};
          event['taskState'] = 'progress';
          event['bytesTransferred'] = progress.processed;
          event['totalByteCount'] = progress.sizes.length > 0 ? progress.sizes[0] : 0;
          let emptyMeta: Record<string, Object> = {};
          event['metadata'] = emptyMeta;
          sink.success(event);
        });

        // 监听完成
        task.on('completed', (progress: request.agent.Progress) => {
          let event: Record<string, Object> = {};
          event['taskState'] = 'success';
          event['bytesTransferred'] = progress.processed;
          event['totalByteCount'] = progress.sizes.length > 0 ? progress.sizes[0] : 0;
          // 上传完成时返回基本 metadata
          let meta: Record<string, Object> = {};
          meta['path'] = cloudPath;
          meta['name'] = cloudPath.split('/').pop() ?? '';
          event['metadata'] = meta;
          sink.success(event);

          // 清理缓存文件和任务记录
          fs.unlink(cachePath).catch(() => {});
          this.uploadTasks.delete(taskId);
        });

        // 监听失败
        task.on('failed', (progress: request.agent.Progress) => {
          let event: Record<string, Object> = {};
          event['taskState'] = 'failure';
          event['errorCode'] = 'UPLOAD_FAILED';
          event['errorMessage'] = '上传失败';
          sink.success(event);

          fs.unlink(cachePath).catch(() => {});
          this.uploadTasks.delete(taskId);
        });
      },
      onCancel: (_args: Object) => {
        // EventChannel 取消监听
      },
    });
  }

  /**
   * 注册下载任务并建立 EventChannel 进度监听。
   * @param taskId 任务 ID
   * @param task 鸿蒙下载任务
   * @param binding Flutter 插件绑定
   * @param destPath 最终目标文件路径（Dart 传入的）
   * @param cachePath 缓存中的下载路径
   */
  registerDownloadTask(
    taskId: string,
    task: request.agent.Task,
    binding: FlutterPluginBinding,
    destPath: string,
    cachePath: string,
  ): void {
    this.downloadTasks.set(taskId, task);

    let eventChannel = new EventChannel(
      binding.getBinaryMessenger(),
      TASK_EVENT_CHANNEL_PREFIX + taskId,
    );

    eventChannel.setStreamHandler({
      onListen: (_args: Object, sink: EventSink) => {
        task.on('progress', (progress: request.agent.Progress) => {
          let event: Record<string, Object> = {};
          event['taskState'] = 'progress';
          event['bytesTransferred'] = progress.processed;
          event['totalByteCount'] = progress.sizes.length > 0 ? progress.sizes[0] : 0;
          sink.success(event);
        });

        task.on('completed', (progress: request.agent.Progress) => {
          // 将缓存中的文件移动到最终目标路径
          try {
            fs.copyFileSync(cachePath, destPath);
            fs.unlink(cachePath).catch(() => {});
          } catch (e) {
            console.error(`[CloudStorage] 复制下载文件失败: ${(e as Error).message}`);
          }

          let event: Record<string, Object> = {};
          event['taskState'] = 'success';
          event['bytesTransferred'] = progress.processed;
          event['totalByteCount'] = progress.sizes.length > 0 ? progress.sizes[0] : 0;
          sink.success(event);

          this.downloadTasks.delete(taskId);
        });

        task.on('failed', (progress: request.agent.Progress) => {
          let event: Record<string, Object> = {};
          event['taskState'] = 'failure';
          event['errorCode'] = 'DOWNLOAD_FAILED';
          event['errorMessage'] = '下载失败';
          sink.success(event);

          fs.unlink(cachePath).catch(() => {});
          this.downloadTasks.delete(taskId);
        });
      },
      onCancel: (_args: Object) => {
      },
    });
  }

  /** 获取活跃的上传任务 ID 列表 */
  getActiveUploadTaskIds(): string[] {
    let ids: string[] = [];
    this.uploadTasks.forEach((task, key) => {
      if (task !== null) {
        ids.push(key);
      }
    });
    return ids;
  }

  /** 获取活跃的下载任务 ID 列表 */
  getActiveDownloadTaskIds(): string[] {
    let ids: string[] = [];
    this.downloadTasks.forEach((task, key) => {
      if (task !== null) {
        ids.push(key);
      }
    });
    return ids;
  }

  /**
   * 处理 AGCStorageTask# 前缀的方法调用（暂停/恢复/取消）。
   *
   * 注意：鸿蒙 request.agent.Task 的暂停/恢复/取消 API 与 Android 不同，
   * 使用 task.pause() / task.resume() / task.stop() 方法。
   */
  onMethodCall(call: MethodCall, result: MethodResult): void {
    let taskId = call.argument('taskId') as string;
    let method = (call.method as string).split('#')[1];

    switch (method) {
      case 'uploadTask/pause':
        this.pauseTask(taskId, true, result);
        break;
      case 'uploadTask/resume':
        this.resumeTask(taskId, true, result);
        break;
      case 'uploadTask/cancel':
        this.cancelTask(taskId, true, result);
        break;
      case 'downloadTask/pause':
        this.pauseTask(taskId, false, result);
        break;
      case 'downloadTask/resume':
        this.resumeTask(taskId, false, result);
        break;
      case 'downloadTask/cancel':
        this.cancelTask(taskId, false, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private pauseTask(taskId: string, isUpload: boolean, result: MethodResult): void {
    let task = isUpload ? this.uploadTasks.get(taskId) : this.downloadTasks.get(taskId);
    if (task) {
      task.pause((err: BusinessError) => {
        if (err) {
          result.success(false);
        } else {
          result.success(true);
        }
      });
    } else {
      result.success(false);
    }
  }

  private resumeTask(taskId: string, isUpload: boolean, result: MethodResult): void {
    let task = isUpload ? this.uploadTasks.get(taskId) : this.downloadTasks.get(taskId);
    if (task) {
      task.resume((err: BusinessError) => {
        if (err) {
          result.success(false);
        } else {
          result.success(true);
        }
      });
    } else {
      result.success(false);
    }
  }

  private cancelTask(taskId: string, isUpload: boolean, result: MethodResult): void {
    let task = isUpload ? this.uploadTasks.get(taskId) : this.downloadTasks.get(taskId);
    if (task) {
      task.stop((err: BusinessError) => {
        if (err) {
          result.success(false);
        } else {
          if (isUpload) {
            this.uploadTasks.delete(taskId);
          } else {
            this.downloadTasks.delete(taskId);
          }
          result.success(true);
        }
      });
    } else {
      result.success(false);
    }
  }
}
