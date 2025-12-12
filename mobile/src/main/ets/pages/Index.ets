import {
  Content,
  Body,
  DataResponse,
  Message,
  Model,
  TextContent,
  ImageContent,
  MessageTxtImg,
  chatDataSource,
  ChatResponse,
  Choice,
  SelectModel,
  CreateImageBodyParams,
  CreateImageResponse,
  EditImageBodyParams,
  MessageItem,
  CreateTranscriptionParams,
  CreateTranscriptionResponse,
  CreateTranslationParams,
  Constants
} from '@ohos/data';

import {
  MediaBean, MediaHelper, Log, Storage, AudioCapturer
} from '@ohos/shared_library';

import file from '@ohos.file.fs';
import { InputWindowDialog } from '../component/inputWindow'
import { ReadyNewChatWindow } from '../component/readyWindow';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

PersistentStorage.persistProp<MessageTxtImg[]>('currentMessages', [])
PersistentStorage.persistProp<MessageItem[]>('allMessages', [])

class ImageType {
  type: string

  constructor() {
    this.type = 'image/png'
  }
}

enum Phase {
  Idle = 0,
  Translating = 1,
  Responding = 2
}

@Entry
@Component
struct Index {
  @State httpCode: number = 0
  @State isHttpError: boolean = false
  @State modelResponse: DataResponse | null = null
  @State modelList: Model[] = []
  @State selectedModel: string = 'gpt-4o-mini' //'gpt-3.5-turbo'
  @State messages: Message[] = [] // todo: Consider to place all the data into database
  @StorageLink('currentMessages') messagesWithImage: MessageTxtImg[] = AppStorage.get('currentMessages') ?? []
  @State currentSavedMessage: MessageItem = new MessageItem(this.messagesWithImage, '')
  @State isSaved: boolean = false
  // @State messagesWithImage: MessageTxtImg[] = []
  //Select model list
  @State selectList: SelectModel[] = []
  @State selectIndex: number = 0
  //Chat response data
  @State repliedChoices: Choice[] = []
  private textAreaController: TextAreaController = new TextAreaController()
  @State newMessageContent: string = ''
  @State newReplyContent: string = ''
  @State currentContent: Content[] = []
  @State currentTextContent: TextContent = new TextContent('')
  // todo: Image required to be `Base64 encoded` data, can't be url

  @State currentImageContent: ImageContent = new ImageContent('')
  private role: string = 'user'
  @State newMessage: Message = new Message('', [])
  @State payload: Body = new Body(this.selectedModel, this.messages)
  @State createImageBody: CreateImageBodyParams =
    new CreateImageBodyParams('dall-e-3', 'A colorful sunset over the mountains',
      1, '1024x1024')
  @State repliedMessage: Message = new Message('assistant', [])
  //Initial app page status
  @State isWelcomeStatus: boolean = true
  //Dynamic layout text
  @State displayedText: string = ''
  private welcomeText: string = 'How can I help you today?'
  private index: number = 0 //Current text index
  //Image
  @State isCreateImageLoading: boolean = false
  @State displayImageGenerateText: string = ''
  private imageGenerateText: string = 'Image generating...'
  private createImageTextIndex: number = 0
  @State imageList: string[] = []
  @State isImageIconClick: boolean = false
  @State imageGenerateDescription: string = ''
  @State imageGenerateKeyword: string = '' // Store the keyword for image generation
  private imageGenerateGuide: string = 'Please describe your image'
  @State isCurrentMessageUploadImage: boolean = false
  @State uploadImageList: string[] = []
  @State currentMessageIndex: number = -1
  @State isCurrentSelectedImageSent: boolean = false
  @State showSideBar: boolean = false
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  // Media
  private mediaHelper: MediaHelper = new MediaHelper(this.context);
  @State mediaBean: MediaBean = new MediaBean();
  //edit image
  @State isImageSelected: boolean = false
  @State selectedFileUrl: string = 'file://media/Photo/5/IMG_1737541853_004/IMG_2025122_182913.jpg'
  //Database
  // @State messageList: Message[][] = []

  // Custom Dialog
  @State inputMessage: string = ''
  inputDialogController: CustomDialogController = new CustomDialogController({
    builder: InputWindowDialog({
      inputMessage: $inputMessage,
      changeInputValue: (val: string) => {
        this.currentSavedMessage.topic = val
        this.currentSavedMessage.isSaved = true
        this.allMessages.push(this.currentSavedMessage)
        this.currentSavedMessage = new MessageItem([], '')
      }
    }),
    alignment: DialogAlignment.Center
  })
  @StorageLink('allMessages') allMessages: MessageItem[] = AppStorage.get('allMessages') ?? []
  readyDialogController: CustomDialogController = new CustomDialogController({
    builder: ReadyNewChatWindow({
      yesButtonAction: () => {
        this.messagesWithImage = []
      }
    }),
    alignment: DialogAlignment.Center
  })
  //Preferences
  private localStorage = new Storage()
  @State style: string[] = []
  @State bgColor: string = ''
  @State txtColor: string = ''
  @State isBlack: boolean = false
  //Image generation
  @State isImageGenerateMode: boolean = false
  @State isSpeakMode: boolean = false
  //Voice management
  @Prop icon?: Resource // Optional: custom microphone icon
  @Prop textColor?: Resource // Optional: prompt text color
  // ===== Internal state =====
  @State isRecording: boolean = false
  @State status: string = 'Tap to speak'
  @State fileBaseName: string = ''
  @State lastWavPath: string = ''
  @State translating: boolean = false
  // Simple VAD (can be simplified or retained as needed)
  private recordStartMs: number = 0
  private lastVoiceMs: number = 0
  private ctx: common.UIAbilityContext | undefined
  private atManager: abilityAccessCtrl.AtManager | null = null
  //Voice management
  private recorder: AudioCapturer = new AudioCapturer()
  @State lastText: string = ''
  // ---- VAD parameters ----
  private hasSpeech: boolean = false
  @State latestAssistantText: string = ''
  @State lastTextEn: string = ''
  @State angle: number = 0
  private spinTimer: number = 0
  @State isRestart: boolean = false
  @State currentPhase: Phase = Phase.Idle

  private async ensureMicPermission(): Promise<void> {
    if (!this.atManager || !this.ctx) {
      return
    }
    const perms: Permissions[] = ['ohos.permission.MICROPHONE']
    try {
      await this.atManager.requestPermissionsFromUser(this.ctx, perms)
    } catch (e) {
      Log.error('[VoiceCapture] mic permission failed: ' + JSON.stringify(e))
    }
  }

  async aboutToAppear(): Promise<void> {
    try {
      this.ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    } catch {
      this.ctx = undefined
    }
    this.atManager = abilityAccessCtrl.createAtManager()
    this.ensureMicPermission()

    let temp: string[] = (await this.localStorage.getStyle('style')) as string[]

    if (this.messagesWithImage[0]) {
      this.isWelcomeStatus = false
    }

    if (this.isWelcomeStatus) {
      this.startTypingEffect()
    }

    const source = new chatDataSource()

    source.fetchHttpCode().then(async (code) => {
      this.httpCode = code
      Log.info('Model items code', code)

      if (code === 200) {

        this.modelList = await source.fetchModels()
        Log.info('Model items len', this.modelList.length)

        this.modelList.forEach((item: Model) => {
          this.selectList.push(new SelectModel(item.id, $r("app.media.icon_oniro")))
          Log.info('Model items', item.id)
        })
      } else {
        this.isHttpError = true;
        console.error('Failed to fetch data: HTTP Code', code);
      }
    })

    if (temp.length !== 0) {
      this.bgColor = temp[temp.length-2]
      this.txtColor = temp[temp.length-1]
      if (temp[temp.length-2] == '#ff000000') {
        this.isBlack = true
      } else if (temp[temp.length-2] == '#ffffffff') {
        this.isBlack = false
      }
    } else {
      this.isBlack = false
    }
  }

  callChatMethod(payload: Body) {
    const source = new chatDataSource()

    // Add loading placeholder message
    const loadingMessage = new Message(Constants.ASSISTANT, [new TextContent('Generating...')])
    this.messages.push(loadingMessage)
    this.messagesWithImage.push(new MessageTxtImg(loadingMessage, ''))

    // Log the message content being sent
    console.log('=== Sending message ===')
    console.log('Payload model:', payload.model)
    console.log('Number of messages:', payload.messages.length)
    if (payload.messages.length > 0) {
      const lastMsg = payload.messages[payload.messages.length - 1]
      console.log('Last message role:', lastMsg.role)
      console.log('Last message content count:', lastMsg.content.length)
      lastMsg.content.forEach((item, index) => {
        if (item.type === 'text') {
          const textItem = item as TextContent
          console.log(`Content[${index}] type: text, text length: ${textItem.text.length}`)
        } else if (item.type === 'image_url') {
          const imgItem = item as ImageContent
          const imgUrl = imgItem.image_url.url
          console.log(`Content[${index}] type: image_url, url prefix: ${imgUrl.substring(0, 50)}...`)
          console.log(`Content[${index}] url length: ${imgUrl.length}`)
        }
      })
    }

    source.fetchHttpCode().then(async (code) => {
      this.httpCode = code

      if (code === 200) {

        const reply: ChatResponse | null = await source.callChatApi(payload).catch(
          (err: Error) => {
            console.error('Error during callChatApi:', err)
            this.isHttpError = true
            this.status = Constants.FAILED
            return null
          }
        )

        if (reply && reply.choices) {
          this.repliedChoices = reply.choices

          // Remove the loading placeholder message
          if (this.messages.length > 0 && this.messages[this.messages.length - 1].role === Constants.ASSISTANT &&
            this.messages[this.messages.length - 1].content.length === 1 &&
            (this.messages[this.messages.length - 1].content[0] as TextContent).text === 'Generating...') {
            this.messages.pop()
            this.messagesWithImage.pop()
          }

          this.repliedChoices.forEach((item: Choice) => {
            // Handle response content - can be string or Content[]
            let replyContent: Content[] = []
            if (item.message?.content) {
              // Check if content is a string (API might return string instead of array)
              if (typeof item.message.content === 'string') {
                replyContent = [new TextContent(item.message.content)]
              } else {
                replyContent = item.message.content as Content[]
              }
            }

            this.latestAssistantText = this.extractTextFromContents(replyContent)
            this.currentPhase = Phase.Responding
            this.messages.push(new Message(Constants.ASSISTANT, replyContent))
            this.messagesWithImage.push(new MessageTxtImg(new Message(Constants.ASSISTANT, replyContent), ''))

            // Log for debugging
            console.info('Assistant reply added:', JSON.stringify(replyContent))
          })
          // Clear error status on success
          this.isHttpError = false
        } else {
          // Remove the loading placeholder message on error
          if (this.messages.length > 0 && this.messages[this.messages.length - 1].role === Constants.ASSISTANT &&
            this.messages[this.messages.length - 1].content.length === 1 &&
            (this.messages[this.messages.length - 1].content[0] as TextContent).text === 'Generating...') {
            this.messages.pop()
            this.messagesWithImage.pop()
          }

          this.isHttpError = true
          this.status = Constants.FAILED
          console.error('No reply received from API')
        }
      } else {
        this.isHttpError = true
        this.status = Constants.FAILED
        console.error(Constants.FAILED_HTTP, code)
      }
    }).catch((err: Error) => {
      this.isHttpError = true
      this.status = Constants.FAILED
      console.error('Error fetching HTTP code:', err)
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
        let reply: CreateTranscriptionResponse | null = null
        try {
          reply = await source.createTranscriptions(payload)
        } catch (err) {
          const error = err as BusinessError
          Log.error('[Voice] transcription http error: ' + JSON.stringify(error))
          this.status = Constants.FAILED
          this.currentPhase = Phase.Idle
        }

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
    this.isSpeakMode = false;
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

  async handleClick(option: MediaOption) {
    let mediaBean!: MediaBean;
    switch (option) {
      case MediaOption.Picture:
        mediaBean = await this.mediaHelper.selectPicture();
        break;
      case MediaOption.File:
        mediaBean = await this.mediaHelper.selectFile();
        break;
      case MediaOption.TakePhoto:
        mediaBean = await this.mediaHelper.takePhoto(this.context);
        break;
      default:
        break;
    }
    if (mediaBean) {
      this.mediaBean = mediaBean;
    }
  }

  callCreateImage(payload: CreateImageBodyParams) {
    const source = new chatDataSource()
    // Clear text area when starting image generation
    this.imageGenerateDescription = ''
    this.textAreaController.setTextSelection(0, 0)
    // Force UI refresh by reassigning
    this.imageGenerateDescription = ''

    source.fetchHttpCode().then(async (code) => {
      this.httpCode = code

      if (code === 200) {
        this.isCreateImageLoading = true

        let reply: CreateImageResponse | null = null
        try {
          reply = await source.createImage(payload)
        } catch (err) {
          const error = err as BusinessError
          console.error('Error during createImage:', error)
          this.isHttpError = true
          this.status = Constants.FAILED
        }
        if (reply) {
          this.isCreateImageLoading = false
          console.info('time', reply.created.toString())
          reply.data.forEach((item) => {
            console.info('imageUrl', item.url)
            this.imageList.push(item.url)
            this.createImageBody.prompt = ''
          })
          this.isImageIconClick = false
        }
      } else {
        this.isHttpError = true;
        console.error('Failed to fetch data: HTTP Code', code);
      }
    })
  }

  callEditImage(payload: EditImageBodyParams) {
    const source = new chatDataSource()
    Log.info('Edit response', 'enter callEditImage')

    source.fetchHttpCode().then(async (code) => {
      this.httpCode = code
      Log.info('Edit response', JSON.stringify(payload, null, 2))

      if (code === 200) {

        let reply: CreateImageResponse | null = null
        try {
          reply = await source.editImage(payload)
        } catch (err) {
          const error = err as BusinessError
          console.error('Error during editImage:', error)
          this.isHttpError = true
          this.status = Constants.FAILED
        }
        Log.info('Edit response', JSON.stringify(reply, null, 2))
        if (reply) {
          console.info('reply param', reply.created.toString())
          reply.data.forEach((item) => {
            console.info('reply param', item.url)
            this.imageList.push(item.url)
            this.createImageBody.prompt = ''
          })
        }
      } else {
        this.isHttpError = true;
        console.error('Failed to fetch data: HTTP Code', code);
      }
    })
  }

  async urlToFile(filePath: string) {
    let f = await file.open(filePath);
    let editPayload: EditImageBodyParams = new EditImageBodyParams(f, 'Modify it')
    this.callEditImage(editPayload)
  }

  //methods about typing welcome page text
  startTypingEffect() {
    setInterval(() => {
      if (this.index < this.welcomeText.length) {
        this.displayedText += this.welcomeText[this.index];
        this.index++;
      }
    }, 50)
  }

  //methods about typing welcome page text
  startImageGenerateEffect() {
    this.displayImageGenerateText = ''
    this.createImageTextIndex = 0
    const fullText = `Image "${this.imageGenerateKeyword}" generating...`
    setInterval(() => {
      if (this.createImageTextIndex < fullText.length) {
        this.displayImageGenerateText = fullText.substring(0, this.createImageTextIndex + 1)
        this.createImageTextIndex++
      }
    }, 50)
  }

  // builder
  @Builder
  iconComponent(icon: Resource, callback?: () => void) {
    Button({ type: ButtonType.Circle }) {
      Image(icon)
        .width(24)
        .height(24)
        .fillColor(this.isBlack ? '#FFFFFF' : '#000000')
    }
    .width(44)
    .height(44)
    .backgroundColor(this.isBlack ? '#d53c3737' : '#E5E5EA')
    .onClick(callback)
  }

  build() {
    SideBarContainer(SideBarContainerType.Overlay) {
      Column({ space: 8 }) {
        // Sidebar header
        Row() {
          // Chat History title - show when sidebar is open
          if (this.showSideBar) {
            Text('Chat History')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isBlack ? Color.White : '#333333')
              .padding({ left: 12 })
          }

          Blank()
            .layoutWeight(1)

          // History icon button - always show
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.icon_history_light'))
              .width(24)
              .height(24)
              .fillColor(this.isBlack ? '#FFFFFF' : '#000000')
          }
          .width(44)
          .height(44)
          .backgroundColor(this.isBlack ? '#d53c3737' : '#E5E5EA')
          .onClick(() => {
            this.showSideBar = !this.showSideBar
          })
        }
        .width('100%')
        .height(52)
        .padding({
          left: 8,
          right: 12,
          top: 0,
          bottom: 0
        })
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.isBlack ? '#dd2f2d2d' : '#F2F2F7')

        List({ space: 8 }) {
          ForEach(this.allMessages, (message: MessageItem) => {
            ListItem() {
              Row() {
                Column() {
                  Text(message.topic)
                    .fontSize(14)
                    .fontColor(this.isBlack ? '#E8E8E8' : '#333333')
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .wordBreak(WordBreak.BREAK_ALL)
                    .width('100%')
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
              }
              .width('100%')
              .padding({
                left: 12,
                right: 12,
                top: 10,
                bottom: 10
              })
              .backgroundColor(Color.Orange)
              .borderRadius(8)
              .onClick(() => {
                Log.info('onclicktask', 'clicked')
                this.messagesWithImage = message.messages
              })
            }
          })
        }
        .padding({ left: 8, right: 8 })
        .scrollBar(BarState.Auto)
      }
      .margin({ top: 0 })
      .padding({ top: 0, bottom: 8 })
      .width('100%')
      .height('100%')
      .backgroundColor(this.isBlack ? '#dd2f2d2d' : '#F2F2F7')

      Column() {
        // todo: Implement select bar
        Column() {
          Row() {
            Select(this.selectList)
              .selected(this.selectIndex)
              .value(this.selectedModel)
              .onSelect((index: number, text?: string | undefined) => {
                this.selectIndex = index
                if (text) {
                  this.selectedModel = text
                }
              })
              .borderRadius(12)
              .menuBackgroundColor(Color.Orange)
              .fontColor(this.isBlack ? this.txtColor : Color.Black)
              .backgroundColor(this.isBlack ? '#d5221f1f' : '#51e5bcbc')
              .font({ size: 14, weight: FontWeight.Medium })
            Blank()
              .layoutWeight(0.7)
            Row({ space: 4 }) {
              // Theme toggle button
              Button({ type: ButtonType.Circle }) {
                Image(this.isBlack == true ? $r('app.media.icon_sun_light') : $r('app.media.icon_sun_dark'))
                  .width(22)
                  .height(22)
              }
              .width(40)
              .height(40)
              .backgroundColor(this.isBlack ? '#d53c3737' : '#E5E5EA')
              .onClick(() => {
                this.isBlack = !this.isBlack
                if (this.isBlack == true) {
                  this.bgColor = "#ff000000"
                  this.txtColor = "#ffffffff"
                  this.style.push(this.bgColor)
                  this.style.push(this.txtColor)
                  this.localStorage.setStyle('style', this.style)
                } else {
                  this.bgColor = "#ffffffff"
                  this.txtColor = "#ff000000"
                  this.style.push(this.bgColor)
                  this.style.push(this.txtColor)
                  this.localStorage.setStyle('style', this.style)
                }
              })

              // New chat button
              Button({ type: ButtonType.Circle }) {
                Image($r('app.media.icon_new_dark'))
                  .width(22)
                  .height(22)
              }
              .width(40)
              .height(40)
              .backgroundColor(this.isBlack ? '#d53c3737' : '#E5E5EA')
              .onClick(() => {
                this.readyDialogController.open()
              })

              // Save button
              Button({ type: ButtonType.Circle }) {
                Image($r('app.media.icon_save_dark'))
                  .width(22)
                  .height(22)
              }
              .width(40)
              .height(40)
              .backgroundColor(this.isBlack ? '#d53c3737' : '#E5E5EA')
              .onClick(() => {
                if (this.currentSavedMessage.isSaved) {
                  this.currentSavedMessage.isSaved = false
                }
                this.inputDialogController.open()
                this.currentSavedMessage.messages = this.messagesWithImage
                this.currentSavedMessage.topic = this.inputMessage
              })
            }
            .justifyContent(FlexAlign.End)
            .layoutWeight(1)
          }
          .width('100%')
        }
        .width('100%')
        .height(50)
        .alignItems(HorizontalAlign.Start)

        Column() {
          if (this.isWelcomeStatus) {
            Column() {
              Text(this.displayedText)
                .fontWeight(600)
                .fontSize(24)
                .fontColor(this.isBlack ? '#FFFFFF' : '#000000')
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
          } else {
            if (this.isImageIconClick) {
              Column() {
                if (this.isCreateImageLoading) {
                  Row({ space: 0 }) {
                    Text('Image "')
                      .fontWeight(600)
                      .fontSize(24)
                    Text(this.imageGenerateKeyword)
                      .fontWeight(600)
                      .fontSize(24)
                      .fontColor('#800020') // Maroon color for keyword
                    Text('" generating...')
                      .fontWeight(600)
                      .fontSize(24)
                  }
                } else {
                  Text(this.imageGenerateGuide)
                    .fontWeight(600)
                    .fontSize(24)
                    .fontColor(this.txtColor)
                }
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            } else {
              if (this.isImageGenerateMode) {
                List() {
                  ForEach(this.imageList, (item: string) => {
                    ListItem() {
                      Row() {
                        Image(item)
                          .width('50%')
                      }
                      .width('100%')
                      .justifyContent(FlexAlign.Center)
                      .margin(10)
                    }
                  })
                }
              } else {
                if (this.isSpeakMode) {
                  Stack({ alignContent: Alignment.Center }) {

                    // ===== Phase.Idle =====
                    if (this.currentPhase === Phase.Idle) {
                      Column() {
                        Image(this.isBlack ? $r('app.media.icon_oniro_dark') : $r('app.media.icon_oniro'))
                          .objectFit(ImageFit.Fill)
                          .width(100)
                          .height(100)
                          .borderRadius(44)
                          .rotate({ angle: this.angle })
                          .onClick(() => this.startNewTurnAndRecord())

                        // Status: TAP_SPEAK / LISTENING / PROCESSING
                        Text(this.status)
                          .fontSize(12)
                          .fontColor(this.txtColor)
                          .textAlign(TextAlign.Center)
                          .fontWeight(FontWeight.Bold)
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
                    Column()
                      .width('100%')
                      .height('100%')
                      .backgroundColor(this.isBlack ? Color.Black : Color.White)
                      .zIndex(0)
                  }
                  .width('100%')
                  .height('100%')
                } else {
                  List() {
                    ForEach(this.messagesWithImage, (item: MessageTxtImg) => {
                      ListItem() {
                        Row({ space: 20 }) {
                          if (item.message.role == 'user') {
                            Column({ space: 8 }) {
                              if (item.img) {
                                Row() {
                                  Image(item.img)
                                    .width(180)
                                    .borderRadius(12)
                                    .margin({ right: 10 })
                                }
                                .width('100%')
                                .justifyContent(FlexAlign.End)
                              }

                              Row() {
                                Column() {
                                  if ((item.message.content[0] as TextContent).text !== '') {
                                    Text((item.message.content[0] as TextContent).text)
                                      .margin(10)
                                      .fontColor(this.txtColor)
                                  }
                                }
                                .borderRadius(10)
                                .borderWidth(1)
                                .borderColor(this.txtColor)
                                .margin(10)
                              }
                              .width('100%')
                              .justifyContent(FlexAlign.End)
                            }
                            .width('100%')
                          } else if (item.message.role == 'assistant') {
                            Row() {
                              Column() {
                                if (item.message.content && item.message.content.length > 0) {
                                  Text((item.message.content[0] as TextContent).text)
                                    .margin(10)
                                }
                              }
                              .borderRadius(10)
                              .borderWidth(1)
                              .margin(10)
                              .backgroundColor(Color.Orange)
                            }
                            .width('100%')
                            .justifyContent(FlexAlign.Start)
                          }
                        }
                        .width('100%')
                      }
                    })
                  }
                }
              }
            }
          }
        }.width('100%')
        .layoutWeight(1)

        // todo: Require guide for image generation
        // if (this.isImageIconClick) {
        //   Text('Please describe your image')
        // }
        Column() {
          Row({ space: 20 }) {
            TextArea({
              text: this.isImageIconClick ? this.imageGenerateDescription : this.newMessageContent,
              placeholder: 'Message',
              controller: this.textAreaController
            })
              .type(TextAreaType.NORMAL)
              .onChange((content: string) => {
                if (this.isImageIconClick) {
                  this.imageGenerateDescription = content
                } else {
                  this.newMessageContent = content
                  console.log(this.newMessageContent)
                }
              })
              .enterKeyType(EnterKeyType.Send)// Configure enter key to trigger event "Send"
              .onSubmit((enterKey: EnterKeyType) => {
                if (enterKey == EnterKeyType.Send) {
                  this.isCurrentSelectedImageSent = true
                  this.isWelcomeStatus = false
                  //Upload current message
                  if (this.isImageIconClick) {
                    // imageGenerateDescription is already updated via onChange
                    this.createImageBody.prompt = this.imageGenerateDescription
                    this.imageGenerateKeyword = this.imageGenerateDescription
                    this.startImageGenerateEffect()
                    this.callCreateImage(this.createImageBody)
                  } else {
                    this.currentContent = []
                    this.currentContent.push(new TextContent(this.newMessageContent))

                    if (this.mediaBean.localUrl) {
                      // Use Promise chain to ensure Base64 conversion completes before sending
                      this.mediaHelper.convertToBase64()
                        .then((base64String: string) => {
                          this.currentImageContent.image_url.url = base64String
                          this.currentContent.push(this.currentImageContent)

                          // Create and send message AFTER base64 conversion is complete
                          this.newMessage = new Message(this.role, this.currentContent)
                          this.newMessageContent = ''
                          this.messages.push(this.newMessage)
                          this.messagesWithImage.push(new MessageTxtImg(this.newMessage, this.mediaBean.localUrl))
                          this.mediaBean.localUrl = ''

                          this.payload = new Body(this.selectedModel, this.messages)
                          this.callChatMethod(this.payload)
                        })
                        .catch((error: BusinessError) => {
                          console.error('Error converting image to Base64:', error);

                          // Still send message even if image failed
                          this.newMessage = new Message(this.role, this.currentContent)
                          this.newMessageContent = ''
                          this.messages.push(this.newMessage)
                          this.messagesWithImage.push(new MessageTxtImg(this.newMessage, ''))
                          this.mediaBean.localUrl = ''

                          this.payload = new Body(this.selectedModel, this.messages)
                          this.callChatMethod(this.payload)
                        })
                    } else {
                      // No image, send message directly
                      this.newMessage = new Message(this.role, this.currentContent)
                      this.newMessageContent = ''
                      this.messages.push(this.newMessage)
                      this.messagesWithImage.push(new MessageTxtImg(this.newMessage, ''))

                      this.payload = new Body(this.selectedModel, this.messages)
                      this.callChatMethod(this.payload)
                    }
                  }
                }
              })
              .width('100%')
              .maxLines(4)
              .placeholderColor(this.isBlack ? '#b0ffffff' : '#630e0d0d')
              .fontColor(this.isBlack ? Color.White : Color.Black)
              .backgroundColor(this.isBlack ? '#c8181818' : Color.White)
              .borderRadius(20)
              .padding({
                left: 16,
                right: 16,
                top: 8,
                bottom: 8
              })
              .borderWidth(2)
              .borderColor(this.isBlack ? '#46ffffff' : '#65100f0f')

            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.icon_send'))
                .width(24)
                .height(24)
                .fillColor(Color.White)
            }
            .width(44)
            .height(44)
            .backgroundColor('#007AFF')
            .onClick(() => {
              this.isCurrentSelectedImageSent = true
              Log.info('SendButton', '=== SEND BUTTON CLICKED ===');
              Log.info('SendButton', 'mediaBean.localUrl:', this.mediaBean.localUrl);
              if (this.isImageIconClick) {
                this.createImageBody.prompt = this.imageGenerateDescription
                this.imageGenerateKeyword = this.imageGenerateDescription
                this.startImageGenerateEffect()
                this.callCreateImage(this.createImageBody)
              } else {
                this.isWelcomeStatus = false
                this.currentContent = []
                this.currentContent.push(new TextContent(this.newMessageContent))
                Log.info('SendButton', 'Text content added to currentContent');

                if (this.mediaBean.localUrl) {
                  Log.info('SendButton', 'Image selected, starting conversion...');
                  this.mediaHelper.convertToBase64()
                    .then((base64String: string) => {
                      Log.info('SendButton', '✅ Base64 conversion succeeded');
                      Log.info('SendButton', 'Base64 length:', base64String.length);
                      Log.info('SendButton', 'Base64 prefix (first 80):', base64String.substring(0, 80));
                      this.currentImageContent.image_url.url = `${base64String}`
                      this.currentContent.push(this.currentImageContent)
                      Log.info('SendButton', 'ImageContent added to currentContent, now content length:',
                        this.currentContent.length);
                      this.isCurrentMessageUploadImage = true

                      // Create and send message AFTER base64 conversion is complete
                      this.newMessage = new Message(this.role, this.currentContent)
                      this.newMessageContent = ''
                      this.messages.push(this.newMessage)
                      this.messagesWithImage.push(new MessageTxtImg(this.newMessage, this.mediaBean.localUrl))
                      this.uploadImageList.push(this.mediaBean.localUrl)
                      this.mediaBean.localUrl = ''

                      // Update payload and send after image is ready
                      this.newMessage.content.forEach((item: Content, index: number) => {
                        if ((item as ImageContent).image_url) {
                          Log.info('SendButton', `Content[${index}] is ImageContent, url prefix:`,
                            (item as ImageContent).image_url.url.substring(0, 80));
                        } else {
                          Log.info('SendButton', `Content[${index}] is TextContent, text:`, (item as TextContent).text);
                        }
                      });
                      this.payload = new Body(this.selectedModel, this.messages)
                      Log.info('SendButton', 'Calling API with message count:', this.messages.length);
                      this.callChatMethod(this.payload)
                    })
                    .catch((error: BusinessError) => {
                      Log.error('SendButton', '❌ Base64 conversion failed:', JSON.stringify(error));
                      this.isCurrentMessageUploadImage = false

                      // Still send message even if image failed
                      this.newMessage = new Message(this.role, this.currentContent)
                      this.newMessageContent = ''
                      this.messages.push(this.newMessage)
                      this.messagesWithImage.push(new MessageTxtImg(this.newMessage, ''))
                      this.mediaBean.localUrl = ''

                      this.payload = new Body(this.selectedModel, this.messages)
                      this.callChatMethod(this.payload)
                    })
                } else {
                  // No image, send message directly
                  this.newMessage = new Message(this.role, this.currentContent)
                  this.newMessageContent = ''
                  this.messages.push(this.newMessage)
                  this.messagesWithImage.push(new MessageTxtImg(this.newMessage, ''))

                  this.payload = new Body(this.selectedModel, this.messages)
                  this.callChatMethod(this.payload)
                }
              }
            })
          }
          .width('100%')

          // Row of many functional labels
          // todo: Implement onClick methods of each icon
          Row({ space: 10 }) {
            this.iconComponent($r('app.media.icon_ai_dark'), () => {
              this.isImageGenerateMode = true
              this.isWelcomeStatus = false
              this.isImageIconClick = !this.isImageIconClick
              this.createImageTextIndex = 0
            })
            this.iconComponent($r('app.media.icon_upload'), () => {
              this.isImageGenerateMode = false
              this.isCurrentSelectedImageSent = false
              this.handleClick(MediaOption.Picture)
              if (this.mediaBean.localUrl) {
                Log.info('Edit response', this.mediaBean.localUrl)

                this.urlToFile(this.mediaBean.localUrl)
              }
            })
            this.iconComponent(this.isBlack ? $r("app.media.icon_record_white") : $r("app.media.icon_record"), () => {
              this.isSpeakMode = true
              this.startNewTurnAndRecord()
            })

            // Text(`Image:${this.isCreateImageLoading}`)
            if (!this.isCurrentSelectedImageSent) {
              Image(this.mediaBean.localUrl)
                .width(30)
                .height(30)
                .backgroundColor(this.bgColor)
                .margin({ right: 12 })
            }
            Blank()
              .layoutWeight(1)
          }
        }
        .width('100%')
        .height(90)
        .borderRadius(0)
        .padding({
          left: 12,
          right: 12,
          top: 8,
          bottom: 8
        })
        .backgroundColor(this.isBlack ? '#000000' : '#F2F2F7')

      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.isBlack ? '#000000' : '#F2F2F7')
    }
    .divider({
      strokeWidth: 0
    })
    .sideBarWidth(240)
    .minSideBarWidth(200)
    .maxSideBarWidth(280)
    .showSideBar(this.showSideBar)
    .onChange((isShow: boolean) => {
      this.showSideBar = isShow
    })
  }
}

@Extend(Image)
function iconStyle() {
  .width(30)
  .height(30)
  .objectFit(ImageFit.Contain)
}

enum MediaOption {
  Picture = 0,
  File = 1,
  TakePhoto = 2
}

