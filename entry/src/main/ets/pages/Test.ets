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
import { Log } from '../utils/Log';
import file from '@ohos.file.fs';
import { MessageItem } from '../models/message';
import { InputWindowDialog } from '../component/inputWindow'
import { ReadyNewChatWindow } from '../component/readyWindow';
import Storage from '../preference/Storage'
import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { UIContext } from '@kit.ArkUI';
import { CreateTranscriptionParams, CreateTranscriptionResponse } from '../models/audio';
import { AudioCapturer } from '../media/AudioCapturer';

PersistentStorage.persistProp<MessageTxtImg[]>('currentMessages', [])
PersistentStorage.persistProp<MessageItem[]>('allMessages', [])

class ImageType {
  type: string

  constructor() {
    this.type = 'image/png'
  }
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
  private imageGenerateGuide: string = 'Please describe your image'
  @State isCurrentMessageUploadImage: boolean = false
  @State uploadImageList: string[] = []
  @State currentMessageIndex: number = -1
  @State isCurrentSelectedImageSent: boolean = false
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
  //Voice management
  private recorder: AudioCapturer = new AudioCapturer();
  @State isRecording: boolean = false;
  @State status: string = 'Tap to speak';
  @State fileBaseName: string = '';
  @State lastWavPath: string = '';
  @State lastText: string = '';
  private atManager: abilityAccessCtrl.AtManager | null = null;
  // ---- VAD 参数（可按表盘麦克风调整）----
  // 以 Int16 归一化到 [-1,1] 的 RMS 阈值；0.02≈较敏感，0.03~0.05 更稳
  private readonly VAD_SPEECH_RMS = 0.025;
  // 说话结束判定的“安静时长”
  private readonly VAD_SILENCE_MS_AFTER_SPEECH = 1200;
  // 最长录音时长（兜底）
  private readonly MAX_RECORD_MS = 15000;
  // 起录后允许等待用户开口的最长静音时间（避免一直挂着）
  private readonly PRE_SPEECH_TIMEOUT_MS = 5000;
  private recordStartMs: number = 0;
  private lastVoiceMs: number = 0;
  private hasSpeech: boolean = false;
  @State latestAssistantText: string = ''

  async aboutToAppear(): Promise<void> {
    this.checkPermission()
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

  // 检查权限方法
  async checkPermission() {
    try {
      const manager = abilityAccessCtrl.createAtManager() // 创建程序控制管理器
      // 获取应用信息
      const buildInfo =
        bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      // 获取该应用是否有录音权限
      const status = manager.checkAccessTokenSync(buildInfo.appInfo?.accessTokenId, "ohos.permission.MICROPHONE")
      if (status === abilityAccessCtrl.GrantStatus.PERMISSION_DENIED) {
        // 没有权限，跳转应用设置
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext
        context.startAbility({
          bundleName: 'com.huawei.ohos.settings',
          abilityName: 'com.huawei.ohos.settings.MainAbility',
          uri: "application_info_entry",
          parameters: {
            pushParams: buildInfo.name
          }
        })
      } else {
        // 有权限,可以开始录音

      }
    } catch (error) {
    }
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

  callChatMethod(payload: Body) {
    const source = new chatDataSource()

    source.fetchHttpCode().then(async (code) => {
      this.httpCode = code
      Log.info('callChatResponse', 'inside call Chat')

      if (code === 200) {
        Log.info('callChatResponse', 'inside 200 call Chat')

        const reply: ChatResponse = await source.callChatApi(payload).catch(
          (err: BusinessError) => {
            console.error('Error during callChatApi:', err)
          }
        ) as ChatResponse
        Log.info('callChatResponse', JSON.stringify(reply, null, 2))
        if (reply && reply.choices) {
          this.repliedChoices = reply.choices;
          this.repliedChoices.forEach((item: Choice) => {
            console.info(item.message?.role || 'No role information');
            // console.info(item.message?.content || 'No message content');
            this.currentContent = item.message?.content || []

            // Save current response content
            this.latestAssistantText = this.extractTextFromContents(this.currentContent);

            this.currentContent = item.message?.content || []
            this.messages.push(new Message('assistant', this.currentContent))
            this.messagesWithImage.push(new MessageTxtImg((new Message('assistant', this.currentContent)), ''))
          })
        }
      } else {
        this.isHttpError = true;
        console.error('Failed to fetch data: HTTP Code', code);
      }
    })
  }
  private hasTextField(seg: Content): boolean {
    const t = seg as TextContent;
    return t !== undefined && typeof t.text === 'string';
  }


  // 把 Content[] 或 string 提取为可展示的文本
  private extractTextFromContents(contents: Content[] | string | null | undefined): string {
    if (!contents) return '';
    if (typeof contents === 'string') return contents;

    const parts: string[] = [];
    for (let i = 0; i < contents.length; i++) {
      const seg = contents[i];
      if (this.hasTextField(seg)) {
        const t = seg as TextContent;
        parts.push(t.text);
      }
      // 如果你也想把图片的 alt 展示出来，可取消下面注释（需要 ImageContent 有 alt）
      // else if (seg instanceof ImageContent && typeof (seg as ImageContent).alt === 'string') {
      //   parts.push(`[图片] ${(seg as ImageContent).alt}`);
      // }
    }
    return parts.join('\n').trim();
  }

  callCreateImage(payload: CreateImageBodyParams) {
    const source = new chatDataSource()

    source.fetchHttpCode().then(async (code) => {
      this.httpCode = code

      if (code === 200) {
        this.isCreateImageLoading = true

        const reply: CreateImageResponse = await source.createImage(payload).catch(
          (err: BusinessError) => {
            console.error('Error during callChatApi:', err)
          }
        ) as CreateImageResponse
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

        const reply: CreateImageResponse = await source.editImage(payload).catch(
          (err: BusinessError) => {
            console.error('Error during callChatApi:', err)
          }
        ) as CreateImageResponse
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
    setInterval(() => {
      if (this.createImageTextIndex < this.imageGenerateText.length) {
        this.displayImageGenerateText += this.imageGenerateText[this.createImageTextIndex];
        this.createImageTextIndex++;
      }
    }, 50)
  }

  async getAudioFileFromResourceManager() {
    let context = new UIContext().getHostContext() as common.UIAbilityContext
    let fd = await context.resourceManager.getRawFd('test.mp3')
  }

  private toast(message: string) {
    this.getUIContext().getPromptAction().showToast({ message });
  }

  private async requestMicPermission(): Promise<void> {
    try {
      const perms: Permissions[] = ['ohos.permission.MICROPHONE'];
      if (this.atManager && this.context) {
        await this.atManager.requestPermissionsFromUser(this.context, perms);
      }
    } catch (e) {
      Log.error('[WatchVoice] mic permission: ' + JSON.stringify(e));
    }
  }

  // ---- 开始录音（按钮点击）----
  private async onTap(): Promise<void> {
    if (!this.context) {
      this.toast('No UI context');
      return;
    }

    if (!this.isRecording) {
      // 开始录音
      this.fileBaseName = Date.now().toString();
      this.lastWavPath = '';
      this.lastText = '';
      this.status = 'Listening…';
      this.isRecording = true;

      // VAD 初始化
      this.recordStartMs = Date.now();
      this.lastVoiceMs = this.recordStartMs;
      this.hasSpeech = false;

      // 设置数据回调用于 VAD
      this.recorder.setDataCallback((buffer: ArrayBuffer) => {
        this.onAudioChunk(buffer);
      });

      await this.recorder.createOn(this.fileBaseName, this.getUIContext());
    } else {
      // 录音中再次点击可手动结束（可选）
      await this.autoStopAndTranscribe('Manual stop');
    }
  }

  // ---- 音频分块回调（做简单 VAD）----
  private onAudioChunk(buffer: ArrayBuffer): void {
    // 计算当前块 RMS（0~1）
    const samples = new Int16Array(buffer);
    if (samples.length === 0) {
      return;
    }
    let sum = 0;
    for (let i = 0; i < samples.length; i++) {
      const v = samples[i] / 32768; // 16bit
      sum += v * v;
    }
    const rms = Math.sqrt(sum / samples.length);

    // 推测当前块时长（44100Hz, 立体声, 16bit）
    const bytes = buffer.byteLength;
    const byteRate = 44100 * 2 * 2;
    const chunkMs = Math.floor(bytes * 1000 / byteRate);

    const now = Date.now();

    if (rms >= this.VAD_SPEECH_RMS) {
      this.hasSpeech = true;
      this.lastVoiceMs = now;
    }

    // 兜底：最长录音时长
    if (now - this.recordStartMs >= this.MAX_RECORD_MS) {
      // 不阻塞回调线程，调度到微任务
      Promise.resolve().then(() => this.autoStopAndTranscribe('Max duration'));
      return;
    }

    // 若还未开口，且前置静音超时，自动结束
    if (!this.hasSpeech && now - this.recordStartMs >= this.PRE_SPEECH_TIMEOUT_MS) {
      Promise.resolve().then(() => this.autoStopAndTranscribe('Pre-speech timeout'));
      return;
    }

    // 若已开口，检测一段持续静音则判定说完
    if (this.hasSpeech && now - this.lastVoiceMs >= this.VAD_SILENCE_MS_AFTER_SPEECH) {
      Promise.resolve().then(() => this.autoStopAndTranscribe('Silence after speech'));
      return;
    }

    // 也可以结合 UI 波形：这里不做渲染，仅用于逻辑
    // (void)chunkMs; // 占位以避免未使用告警
  }

  // ---- 自动停止 + 转写 ----
  private async autoStopAndTranscribe(reason: string): Promise<void> {
    if (!this.isRecording) {
      return;
    }
    this.isRecording = false;

    try {
      this.recorder.clearDataCallback?.();

      await this.recorder.stopAndRelease(); // 生成 WAV & 删除 PCM

      // 取 WAV 路径
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const cacheDir: string = ctx.cacheDir;
      this.lastWavPath = `${cacheDir}/${this.fileBaseName}.wav`;
      this.status = 'Processing…';

      // 调转写
      await this.doTranscribe();

      // 展示结果
      if (this.lastText && this.lastText.length > 0) {
        this.status = 'Done';
        Log.info('[WatchVoice][Text] ' + this.lastText);
      } else {
        this.status = 'No speech recognized';
        Log.info('[WatchVoice][Text] <empty>');
      }
    } catch (e) {
      this.status = 'Failed';
      Log.error('[WatchVoice] stop/transcribe error: ' + JSON.stringify(e));
    }
  }

  // ---- 调你封装的 OpenAI 转写接口 ----
  private async doTranscribe(): Promise<void> {
    if (!this.lastWavPath) {
      return;
    }

    let f: file.File | null = null;
    try {
      f = file.openSync(this.lastWavPath, file.OpenMode.READ_ONLY);

      // 你 models/audio 里若是 class，就用 new；若是 interface，就改成对象字面量
      const payload: CreateTranscriptionParams = new CreateTranscriptionParams(f, 'gpt-4o-transcribe');

      const source = new chatDataSource();
      const reply: CreateTranscriptionResponse = await source.createTranscriptions(payload)
        .catch((err: BusinessError) => {
          Log.error('[WatchVoice] transcription http error: ' + JSON.stringify(err));
        }) as CreateTranscriptionResponse;

      if (reply && reply.text !== undefined) {
        this.lastText = reply.text as string;
        // ✅ 转写成功后，自动把文字发给 GPT，并在下方显示回复
        await this.sendTranscriptToGPT();
      } else {
        this.lastText = '';
      }
    } finally {
      try {
        if (f) {
          file.closeSync(f.fd);
        }
      } catch {
      }
    }
  }

  // ---- 把转写结果当作用户消息发给 GPT，并把回复插入列表显示 ----
  private async sendTranscriptToGPT(): Promise<void> {
    if (!this.lastText || this.lastText.length === 0) {
      this.status = 'No speech recognized';
      return;
    }

    // 1) 把“转写文本”作为一条用户消息加入对话（也加入 messagesWithImage 以便 UI 列表展示）
    const userMsg = new Message('user', [new TextContent(this.lastText)]);
    this.messages.push(userMsg);
    // 第二个参数是图片占位，语音转文字这里没有图，传空串即可
    this.messagesWithImage.push(new MessageTxtImg(userMsg, ''));

    // 2) 调用你现有的聊天接口
    this.status = 'Getting reply…';
    const body = new Body(this.selectedModel, this.messages);

    // 复用你已有的封装：它会把助手回复 push 进 this.messages & this.messagesWithImage
    this.callChatMethod(body);
  }

  // builder
  @Builder
  iconComponent(icon: Resource, callback?: () => void) {
    Image(icon)
      .iconStyle()
      .onClick(callback)
  }

  // 顶部“我说”的文案
  private headerUserText(): string {
    return (this.lastText && this.lastText.length > 0)
      ? this.lastText
      : (this.isRecording ? '正在聆听… 请说话' : '点击下方按钮开始说话');
  }

  build() {
    Column() {
      // 顶部：用户语音
      Row() {
        Text('我说：')
          .fontSize(12)
          .fontWeight(600)
          .fontColor('#89CFF0')
          .opacity(0.95)
          .margin({ right: 6 })

        Text(this.headerUserText())   // 上面的方法
          .fontSize(14)
          .fontWeight(600)
          .fontColor('#FFFFFF')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .flexGrow(1)
      }
      .width('100%')
      .padding({
        left: 12,
        right: 12,
        top: 10,
        bottom: 10
      })
      .backgroundColor('#1D1D1D')
      .borderRadius(12)
      .margin({
        left: 8,
        right: 8,
        top: 8,
        bottom: 6
      })
      .shadow({
        radius: 8,
        color: 'rgba(0,0,0,0.25)',
        offsetX: 0,
        offsetY: 2
      })

      // 中间：助手回复
      Column() {
        Text('助手：')
          .fontSize(12)
          .fontWeight(600)
          .fontColor('#FFD580')
          .opacity(0.95)
          .margin({ bottom: 6 })

        Text(this.latestAssistantText)
          .fontSize(16)
          .fontWeight(500)
          .fontColor('#FFFFFF')
          .lineHeight(22)
          .textAlign(TextAlign.Start)
          .margin({ left: 12, right: 12, bottom: 6 })
          .borderRadius(12)
          .padding({
            left: 8,
            right: 8,
            top: 8,
            bottom: 8
          })
          .backgroundColor('#2A2A2A')
          .shadow({
            radius: 10,
            color: 'rgba(0,0,0,0.28)',
            offsetX: 0,
            offsetY: 3
          })
      }
      .width('100%')
      .flexGrow(1)
      .padding({ left: 8, right: 8 })

      // 底部：录音按钮 + 状态
      Column() {
        Button(this.isRecording ? '正在聆听…' : '开始说话')
          .width(88)   // ⬅ 缩小按钮
          .height(88)
          .fontSize(14)
          .fontWeight(700)
          .borderRadius(44)
          .backgroundColor(this.isRecording ? '#FF4D4F' : '#0A59F7')
          .fontColor('#FFFFFF')
          .shadow({
            radius: 8,
            color: 'rgba(0,0,0,0.35)',
            offsetX: 0,
            offsetY: 3
          })
          .onClick(() => this.onTap())

        Text(this.status)
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.7)')
          .textAlign(TextAlign.Center)
          .margin({ top: 4 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#121212')
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

