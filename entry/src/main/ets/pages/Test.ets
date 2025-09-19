/*
 * Simple two-button recorder page (Start/End).
 * Saves WAV to app cacheDir, then uploads WAV to OpenAI transcription API.
 */

import { abilityAccessCtrl, Permissions, common } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import file from '@ohos.file.fs';

import { AudioCapturer } from '../media/AudioCapturer'; // ← 路径按你的工程实际调整
import { chatDataSource } from '../data/DataSource';
import { CreateTranscriptionParams, CreateTranscriptionResponse } from '../models/audio';
import { Log } from '../utils/Log';

@Entry
@Component
struct SimpleRecorderPage {
  private recorder: AudioCapturer = new AudioCapturer();
  @State isRecording: boolean = false;
  @State fileBaseName: string = '';
  @State lastWavPath: string = '';
  @State status: string = 'Idle';
  private atManager: abilityAccessCtrl.AtManager | null = null;
  private context: common.UIAbilityContext | undefined = undefined;
  @State lastResult: string = ''

  aboutToAppear(): void {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;

    this.atManager = abilityAccessCtrl.createAtManager();
    this.requestPermissionsAndStart();
  }

  async requestPermissionsAndStart(): Promise<void> {
    const perms: Permissions[] = ['ohos.permission.MICROPHONE'];
    try {
      if (this.atManager && this.context) {
        const result = await this.atManager.requestPermissionsFromUser(this.context, perms);
        Log.info('permission request result: ' + JSON.stringify(result));
        // 简单检查授权状态（生产请详判每个权限）
      }
    } catch (err) {
      console.warn('permission request failed: ' + JSON.stringify(err));
    }
  }

  private toast(message: string) {
    this.getUIContext().getPromptAction().showToast({ message });
  }

  // ---- 开始录音 ----
  private async onStart(): Promise<void> {
    if (this.isRecording) {
      this.toast('Already recording');
      return;
    }
    this.fileBaseName = Date.now().toString();
    await this.recorder.createOn(this.fileBaseName, this.getUIContext());
    this.isRecording = true;
    this.status = 'Recording...';
    this.lastWavPath = '';
  }

  // ---- 结束录音并生成 WAV，然后可直接发起转写 ----
  private async onEnd(): Promise<void> {
    if (!this.isRecording) {
      this.toast('Not recording');
      return;
    }
    await this.recorder.stopAndRelease(); // 生成 <cacheDir>/<timestamp>.wav，并删除 .pcm
    this.isRecording = false;
    this.status = 'Saved';

    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const cacheDir: string = ctx.cacheDir;
    this.lastWavPath = `${cacheDir}/${this.fileBaseName}.wav`;
    this.toast(`Saved: ${this.lastWavPath}`);

    // 可选：结束后立即转写
    // await this.transcribeLastRecording();
  }

  // ---- 打开 lastWavPath -> 构造参数 -> 调用你封装的接口 -> 关闭 fd ----
  private async transcribeLastRecording(): Promise<void> {
    if (!this.lastWavPath) {
      this.toast('No WAV file to transcribe');
      return;
    }

    let f: file.File | null = null;
    try {
      // 打开 WAV 文件（只读）
      f = file.openSync(this.lastWavPath, file.OpenMode.READ_ONLY);

      // 构造你封装的参数（保持你的模型名）
      const payload: CreateTranscriptionParams =
        new CreateTranscriptionParams(f, 'gpt-4o-transcribe');

      const source = new chatDataSource();
      // （如果你有健康检查）可选：先探测 HTTP 状态
      const httpCode = await source.fetchHttpCode().catch(() => 0);
      if (httpCode !== 200) {
        this.toast(`HTTP ${httpCode} from backend`);
        return;
      }

      // 调用你封装的 API
      const reply: CreateTranscriptionResponse = await source
        .createTranscriptions(payload)
        .catch((err: BusinessError) => {
          Log.error('createTranscriptions error: ' + JSON.stringify(err));
        }) as CreateTranscriptionResponse

      if (reply) {
        Log.info('Transcription text: ' + reply.text);
        // 你也可以把结果展示到 UI：
        this.status = 'Transcribed';
        this.lastResult = reply.text;  // 自己加个 @State lastResult: string
        this.toast('Transcription done');
      } else {
        this.toast('Transcription failed');
      }
    } catch (e) {
      Log.error('Transcription open/send failed: ' + JSON.stringify(e));
      this.toast('Transcription failed');
    } finally {
      // 关闭 fd，避免句柄泄露
      try {
        if (f) {
          file.closeSync(f.fd);
        }
      } catch (_) {
      }
    }
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        Text(`Status: ${this.status}`).fontSize(16).fontWeight(FontWeight.Medium)
        if (this.lastWavPath) {
          Text(this.lastWavPath)
            .fontSize(12)
            .fontColor('#666666')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }.width('90%')

      Row({ space: 24 }) {
        Button('Start')
          .width(120)
          .height(44)
          .fontSize(16)
          .enabled(!this.isRecording)
          .onClick(() => {
            this.onStart();
          })

        Button('End')
          .width(120)
          .height(44)
          .fontSize(16)
          .enabled(this.isRecording)
          .onClick(() => {
            this.onEnd();
          })

        Button('test transcription')
          .width(180)
          .height(44)
          .fontSize(16)
          .enabled(!this.isRecording)
          .onClick(() => {
            this.transcribeLastRecording();
          })
      }

      Text('44.1kHz / Stereo / 16-bit WAV')
        .fontSize(12).fontColor('#888').margin({ top: 8 })
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .height('100%')
    .width('100%')
    .padding(24)
    .backgroundColor('#FFFFFF')
  }
}
