import { chatDataSource } from '../data/DataSource'
import { Content, Body, Message, TextContent, MessageTxtImg } from '../models/models'
import { ChatResponse, Choice } from '../models/chat'
import { Log } from '../utils/Log'
import file from '@ohos.file.fs'
import { abilityAccessCtrl, bundleManager, common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { CreateTranscriptionParams, CreateTranscriptionResponse, CreateTranslationParams } from '../models/audio'
import { AudioCapturer } from '../media/AudioCapturer'
import { Constants } from '../common/Constants'

enum Phase {
  Idle = 0,
  Translating = 1,
  Responding = 2
}

@Entry
@Component
struct Test {
  @State httpCode: number = 0
  @State isHttpError: boolean = false
  @State selectedModel: string = Constants.GPT_4O_MINI
  @State messages: Message[] = []
  @StorageLink('currentMessages') messagesWithImage: MessageTxtImg[] = AppStorage.get('currentMessages') ?? []
  //Chat response data
  @State repliedChoices: Choice[] = []
  @State currentContent: Content[] = []
  //Voice management
  private recorder: AudioCapturer = new AudioCapturer()
  @State isRecording: boolean = false
  @State status: string = Constants.TAP_SPEAK
  @State fileBaseName: string = ''
  @State lastWavPath: string = ''
  @State lastText: string = ''
  // ---- VAD parameters ----
  private recordStartMs: number = 0
  private lastVoiceMs: number = 0
  private hasSpeech: boolean = false
  @State latestAssistantText: string = ''
  @State lastTextEn: string = ''
  @State translating: boolean = false
  @State angle: number = 0
  private spinTimer: number = 0
  @State isRestart: boolean = false
  @State currentPhase: Phase = Phase.Idle

  async aboutToAppear(): Promise<void> {
    this.checkPermission()
  }

  async checkPermission() {
    try {
      const manager = abilityAccessCtrl.createAtManager()
      const buildInfo =
        bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      const status = manager.checkAccessTokenSync(buildInfo.appInfo?.accessTokenId, "ohos.permission.MICROPHONE")
      if (status === abilityAccessCtrl.GrantStatus.PERMISSION_DENIED) {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext
        context.startAbility({
          bundleName: Constants.BUNDLE_NAME,
          abilityName: Constants.AbilityName,
          uri: Constants.URI,
          parameters: {
            pushParams: buildInfo.name
          }
        })
      }
    } catch (error) {
    }
  }

  callChatMethod(payload: Body) {
    const source = new chatDataSource()

    source.fetchHttpCode().then(async (code) => {
      this.httpCode = code

      if (code === 200) {

        const reply: ChatResponse = await source.callChatApi(payload).catch(
          (err: BusinessError) => {
            console.error('Error during callChatApi:', err)
          }
        ) as ChatResponse
        if (reply && reply.choices) {
          this.repliedChoices = reply.choices
          this.repliedChoices.forEach((item: Choice) => {
            // Save current response content
            this.latestAssistantText = this.extractTextFromContents(this.currentContent)
            this.currentPhase = Phase.Responding
            this.currentContent = item.message?.content || []
            this.messages.push(new Message(Constants.ASSISTANT, this.currentContent))
            this.messagesWithImage.push(new MessageTxtImg((new Message(Constants.ASSISTANT, this.currentContent)), ''))
          })
        }
      } else {
        this.isHttpError = true
        console.error(Constants.FAILED_HTTP, code)
      }
    })
  }

  private async translateCurrentAudioToEnglish(): Promise<string> {
    if (!this.lastWavPath) {
      return ''
    }

    let f: file.File | null = null
    try {
      this.translating = true
      if (canIUse('SystemCapability.FileManagement.File.FileIO')) {
        f = file.openSync(this.lastWavPath, file.OpenMode.READ_ONLY)
        const params = new CreateTranslationParams(f, Constants.GPT_4O_MINI_TRANSCRIBE)
        const source = new chatDataSource()
        const textEn: string = await source.createTranslation(params)
        this.lastTextEn = textEn ?? ''
        return this.lastTextEn
      } else {
        Log.error("Current device can not use file management")
        return ''
      }
    } catch (e) {
      Log.error('[WatchVoice] translate error: ' + JSON.stringify(e))
      this.lastTextEn = ''
      return ''
    } finally {
      this.translating = false
      try {
        if (f) {
          file.closeSync(f.fd)
        }
      } catch {
      }
    }
  }

  private hasTextField(seg: Content): boolean {
    const t = seg as TextContent
    return t !== undefined && typeof t.text === 'string'
  }

  private extractTextFromContents(contents: Content[] | string | null | undefined): string {
    if (!contents) {
      return ''
    }
    if (typeof contents === 'string') {
      return contents
    }

    const parts: string[] = []
    for (let i = 0; i < contents.length; i++) {
      const seg = contents[i]
      if (this.hasTextField(seg)) {
        const t = seg as TextContent
        parts.push(t.text)
      }
    }
    return parts.join('\n').trim()
  }

  private onAudioChunk(buffer: ArrayBuffer): void {
    const samples = new Int16Array(buffer)
    if (samples.length === 0) {
      return
    }
    let sum = 0
    for (let i = 0; i < samples.length; i++) {
      const v = samples[i] / 32768 // 16bit
      sum += v * v
    }
    const rms = Math.sqrt(sum / samples.length)

    const now = Date.now()

    if (rms >= Constants.VAD_SPEECH_RMS) {
      this.hasSpeech = true
      this.lastVoiceMs = now
    }

    if (now - this.recordStartMs >= Constants.MAX_RECORD_MS) {
      Promise.resolve().then(() => this.autoStopAndTranscribe(Constants.MAX_DURATION))
      return
    }

    if (!this.hasSpeech && now - this.recordStartMs >= Constants.PRE_SPEECH_TIMEOUT_MS) {
      Promise.resolve().then(() => this.autoStopAndTranscribe(Constants.PRE_SPEECH_TIMEOUT))
      return
    }

    if (this.hasSpeech && now - this.lastVoiceMs >= Constants.VAD_SILENCE_MS_AFTER_SPEECH) {
      Promise.resolve().then(() => this.autoStopAndTranscribe(Constants.SILENCE_AFTER_SPEECH))
      return
    }
  }

  private async autoStopAndTranscribe(reason: string): Promise<void> {
    Log.info(reason)
    if (!this.isRecording) {
      return
    }
    this.isRecording = false

    try {
      this.recorder.clearDataCallback?.()
      await this.recorder.stopAndRelease()

      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      this.lastWavPath = `${ctx.cacheDir}/${this.fileBaseName}.wav`
      this.status = Constants.PROCESSING
      this.currentPhase = Phase.Idle

      await this.doTranscribe()
    } catch (e) {
      this.status = Constants.FAILED
      this.currentPhase = Phase.Idle
    }
  }

  private async doTranscribe(): Promise<void> {
    if (!this.lastWavPath) {
      return
    }

    let f: file.File | null = null
    try {
      if (canIUse('SystemCapability.FileManagement.File.FileIO')) {
        f = file.openSync(this.lastWavPath, file.OpenMode.READ_ONLY)
        const payload = new CreateTranscriptionParams(f, Constants.GPT_4O_TRANSCRIBE)

        const source = new chatDataSource()
        const reply = await source.createTranscriptions(payload)
          .catch((err: BusinessError) => {
            Log.error('[Voice] transcription http error: ' + JSON.stringify(err))
          }) as CreateTranscriptionResponse

        if (reply && typeof reply.text === 'string' && reply.text.length > 0) {
          this.lastText = reply.text

          this.status = Constants.GET_READY
          this.translating = true
          this.currentPhase = Phase.Translating

          let en = await this.translateCurrentAudioToEnglish()
          if (!en || en.trim().length === 0) {
            en = this.lastText
          }
          this.lastTextEn = en
          this.translating = false

          await this.sendTranscriptToGPT()
        } else {
          this.lastText = ''
          this.status = Constants.FAILED
          this.currentPhase = Phase.Idle
        }

      } else {
        Log.error('Current device not support file management')
        this.currentPhase = Phase.Idle
      }
    } finally {
      try {
        if (f) {
          file.closeSync(f.fd)
        }
      } catch {
      }
    }
  }

  private async sendTranscriptToGPT(): Promise<void> {
    if (!this.lastTextEn || this.lastTextEn.trim().length === 0) {
      this.status = Constants.PROCESSING
      return
    }
    const userMsg = new Message('user', [new TextContent(this.lastTextEn)])
    this.messages.push(userMsg)
    this.messagesWithImage.push(new MessageTxtImg(userMsg, ''))

    this.status = Constants.GET_READY
    const body = new Body(this.selectedModel, this.messages)
    this.callChatMethod(body)
  }

  private startSpin() {
    if (this.spinTimer) {
      return
    }
    this.spinTimer = setInterval(() => {
      this.angle = (this.angle + 6) % 360
    }, 16) as number
  }

  private async startNewTurnAndRecord(): Promise<void> {
    this.lastText = ''
    this.lastTextEn = ''
    this.latestAssistantText = ''
    this.angle = 0

    this.status = Constants.LISTENING
    this.isRecording = true
    this.currentPhase = Phase.Idle

    this.fileBaseName = Date.now().toString()
    this.lastWavPath = ''
    this.recordStartMs = Date.now()
    this.lastVoiceMs = this.recordStartMs
    this.hasSpeech = false

    this.startSpin?.()

    this.recorder.setDataCallback((buffer: ArrayBuffer) => {
      this.onAudioChunk(buffer)
    })

    await this.recorder.createOn(this.fileBaseName, this.getUIContext())
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {

      // ===== Phase.Idle =====
      if (this.currentPhase === Phase.Idle) {
        Column() {
          Image($r('app.media.icon_oniro'))
            .objectFit(ImageFit.Fill)
            .width(100)
            .height(100)
            .borderRadius(44)
            .rotate({ angle: this.angle })
            .onClick(() => this.startNewTurnAndRecord())

          // Status: TAP_SPEAK / LISTENING / PROCESSING
          Text(this.status)
            .fontSize(12)
            .fontColor(Color.Black)
            .textAlign(TextAlign.Center)
            .fontWeight(FontWeight.Bold)
            .fontColor('#700f0000')
            .margin({ top: 4 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .zIndex(1)
      }

      // ===== Phase.Translating: Display user input text only =====
      if (this.currentPhase === Phase.Translating) {
        Text(
          (this.lastTextEn && this.lastTextEn.length > 0)
            ? this.lastTextEn
            : 'Recognizing…'  // placeholder
        )
          .fontWeight(FontWeight.Bold)
          .fontColor('#700f0000')
          .fontSize(15)
          .zIndex(1)
          .margin({ left: 12, right: 12 })
      }

      // ===== Phase.Responding =====
      if (this.currentPhase === Phase.Responding) {
        Column() {
          Scroll() {
            Column() {
              Row() {
                Text(this.lastTextEn)
                  .fontColor('#700f0000')
                  .fontSize(14)
                  .textAlign(TextAlign.Center)
                  .fontWeight(FontWeight.Bold)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .margin({ bottom: 6 })

              Text(this.latestAssistantText)
                .fontColor('#8f0f0000')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .textAlign(TextAlign.Start)
                .lineHeight(20)
                .width('100%')
            }
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.On)
          .edgeEffect(EdgeEffect.Spring)
          .clip(true)

          Image($r('app.media.icon_oniro'))
            .width(40)
            .height(40)
            .onClick(() => this.startNewTurnAndRecord())
            .margin({ bottom: 16 })
        }
        .justifyContent(FlexAlign.End)
        .width('90%')
        .height('70%')
        .padding(8)
        .backgroundColor($r('sys.color.comp_background_list_card'))
        .borderRadius(8)
        .zIndex(1)
      }

      // BACKGROUND LAYER
      Column().width('100%').height('100%').backgroundColor(Color.White).zIndex(0)
    }
    .width('100%')
    .height('100%')
  }
}
