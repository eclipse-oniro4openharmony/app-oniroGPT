/*
 * Simple two-button recorder page (Start/End).
 * Saves WAV to app cacheDir, e.g. /data/storage/.../cache/<timestamp>.wav
 */

import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { AudioCapturer } from '../media/AudioCapturer'; // ← 路径按你的工程实际调整
import { Log } from '../utils/Log'
import { chatDataSource } from '../data/DataSource'
import {
  Content,
  Body,
  DataResponse,
  Message,
  Model,
  TextContent,
  ImageContent,
  MessageTxtImg
} from '../models/models';
import { ChatResponse, Choice } from '../models/chat';
import { SelectModel } from '../models/index'
import { CreateImageBodyParams, CreateImageResponse, EditImageBodyParams } from '../models/image';
import { MediaBean } from '../bean/MediaBean';
import { MediaHelper } from '../helper/MediaHelper';
import file from '@ohos.file.fs';
import { MessageItem } from '../models/message';
import { InputWindowDialog } from '../component/inputWindow'
import { ReadyNewChatWindow } from '../component/readyWindow';
import Storage from '../preference/Storage'
import { BusinessError } from '@kit.BasicServicesKit';
import { CreateTranscriptionParams, CreateTranscriptionResponse } from '../models/audio';
import { UIContext } from '@kit.ArkUI';

@Entry
@Component
struct SimpleRecorderPage {
  private recorder: AudioCapturer = new AudioCapturer();
  @State isRecording: boolean = false;
  @State fileBaseName: string = ''; // 录音文件基名（时间戳）
  @State lastWavPath: string = ''; // 最近一次生成的 WAV 路径
  @State status: string = 'Idle';
  private atManager: abilityAccessCtrl.AtManager | null = null;
  //edit image
  @State isImageSelected: boolean = false
  @State selectedFileUrl: string = ''
  @State isHttpError: boolean = false
  @State httpCode: number = 0

  private toast(message: string) {
    this.getUIContext().getPromptAction().showToast({ message });
  }

  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  //Audio transcription
  @State createTranscriptionBody: CreateTranscriptionParams =
    new CreateTranscriptionParams(this.getAudioFile(), 'gpt-4o-transcribe')

  getAudioFile(): file.File {
    let filePath: string = ""
    const f = file.openSync(filePath, file.OpenMode.READ_ONLY)
    try {
      const buffer = new ArrayBuffer(4096)
      const bytesRead = file.readSync(f.fd, buffer, { length: buffer.byteLength })
      Log.info('Audio file content:', buffer.byteLength)
    } catch (error) {
      Log.error(`Read file failed: ${error}`)
    }
    return f
  }

  aboutToAppear(): void {
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

  // Start：创建并开始录音
  private async onStart(): Promise<void> {
    if (this.isRecording) {
      this.toast('Already recording');
      return;
    }

    this.fileBaseName = Date.now().toString(); // 例如 1726755300000
    await this.recorder.createOn(this.fileBaseName, this.getUIContext());
    this.isRecording = true;
    this.status = 'Recording...';
    this.lastWavPath = '';
  }

  // End：停止、转封装 WAV、删除 PCM
  private async onEnd(): Promise<void> {
    if (!this.isRecording) {
      this.toast('Not recording');
      return;
    }
    await this.recorder.stopAndRelease(); // 会生成 .wav 并删除 .pcm
    this.isRecording = false;
    this.status = 'Saved';

    // 计算 WAV 路径（与 AudioCapturer 一致：写到 cacheDir）
    const ctx: Context = this.getUIContext().getHostContext() as Context;
    const cacheDir = ctx.cacheDir;
    this.lastWavPath = `${cacheDir}/${this.fileBaseName}.wav`;
    this.toast(`Saved: ${this.lastWavPath}`);
  }

  callCreateTranscription(payload: CreateTranscriptionParams) {
    const source = new chatDataSource()
    Log.info('Audio response', 'enter CreateTranscriptionParams')
    source.fetchHttpCode().then(async (code) => {
      this.httpCode = code
      Log.info('Audio response', JSON.stringify(payload, null, 2))

      if (code === 200) {

        const reply: CreateTranscriptionResponse = await source.createTranscriptions(payload).catch(
          (err: BusinessError) => {
            Log.error('Error during callChatApi:', err)
          }
        ) as CreateTranscriptionResponse
        Log.info('Audio response', JSON.stringify(reply, null, 2))
        if (reply) {
          Log.info('Audio response1', reply.text.toString())
          Log.info('Audio response2', reply.usage.toString())
          Log.info('Audio response3', reply.output_tokens.toString())
          Log.info('Audio response4', reply.total_tokens.toString())
        }
      } else {
        this.isHttpError = true;
        console.error('Failed to fetch data: HTTP Code', code);
      }
    })
  }

  build() {
    Column({ space: 16 }) {
      // 状态与路径提示
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

      // 两个按钮
      Row({ space: 24 }) {
        Button('Start')
          .width(120)
          .height(44)
          .fontSize(16)
          .onClick(() => {
            this.onStart();
          })
          .enabled(!this.isRecording)

        Button('End')
          .width(120)
          .height(44)
          .fontSize(16)
          .onClick(() => {
            this.onEnd();
          })
          .enabled(this.isRecording)

        Button('test transcription')
          .onClick(()=>{
            this.callCreateTranscription(this.createTranscriptionBody)
          })
      }

      // 小提示
      Text('44.1kHz / Stereo / 16-bit WAV')
        .fontSize(12)
        .fontColor('#888')
        .margin({ top: 8 })
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .height('100%')
    .width('100%')
    .padding(24)
    .backgroundColor('#FFFFFF')
  }
}
