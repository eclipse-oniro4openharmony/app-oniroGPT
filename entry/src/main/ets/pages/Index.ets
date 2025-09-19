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
import { abilityAccessCtrl, bundleManager, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CreateTranscriptionParams, CreateTranscriptionResponse } from '../models/audio';
import { UIContext } from '@kit.ArkUI';

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
  //Audio transcription
  @State createTranscriptionBody: CreateTranscriptionParams =
    new CreateTranscriptionParams(this.getAudioFile('test'), 'gpt-4o-transcribe')

  getAudioFile(fileName: string): file.File {
    let filePath: string = this.context.filesDir + '/' + fileName
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

  async aboutToAppear(): Promise<void> {
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

  // builder
  @Builder
  iconComponent(icon: Resource, callback?: () => void) {
    Image(icon)
      .iconStyle()
      .onClick(callback)
  }

  build() {
    Flex() {
      SideBarContainer(SideBarContainerType.Embed) {
        Column({ space: 5 }) {
          List() {
            ForEach(this.allMessages, (message: MessageItem) => {
              ListItem() {
                Row() {
                  Text(message.topic)
                    .margin({ left: 5 })
                    .fontColor(this.isBlack ? Color.White : Color.Black)
                }
                .width('100%')
                .backgroundColor(Color.Orange)
                .margin({ bottom: 10 })
                .height(30)
                .onClick(() => {
                  Log.info('onclicktask', 'clicked')
                  this.messagesWithImage = message.messages
                  // message.messages.forEach((item)=>{
                  //   Log.info('onclicktask', item.message.role)
                  // })
                })
              }
            })
          }
        }
        .margin({
          top: 90
        })
        .backgroundColor(this.isBlack ? '#dd2f2d2d' : '#4dffffff')

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
                .borderRadius(10)
                .menuBackgroundColor(Color.Orange)
                .fontColor(this.isBlack ? this.txtColor : Color.Black)
                .backgroundColor(this.isBlack ? '#d5221f1f' : '#51e5bcbc')
              Blank()
                .layoutWeight(0.7)
              Row() {
                Row() {
                  Image(this.isBlack == true ? $r('app.media.icon_sun_light') : $r('app.media.icon_sun_dark'))
                    .width(40)
                }
                .width(50)
                .justifyContent(FlexAlign.End)
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

                Row() {
                  Button('Audio')
                    .onClick(() => {
                      this.callCreateTranscription(this.createTranscriptionBody)
                    })
                }

                Row() {
                  Image($r('app.media.icon_new_dark'))
                    .width(40)
                    .margin({ top: 6, right: 6 })
                }
                .width(50)
                .justifyContent(FlexAlign.End)
                .onClick(() => {
                  this.readyDialogController.open()
                })

                Row() {
                  Image($r('app.media.icon_save_dark'))
                    .width(30)
                    .margin({ right: 10 })
                }
                .width(50)
                .justifyContent(FlexAlign.End)
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
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            } else {
              if (this.isImageIconClick) {
                Column() {
                  Text(`${this.isCreateImageLoading == true ? this.imageGenerateText : this.imageGenerateGuide}`)
                    .fontWeight(600)
                    .fontSize(24)
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
                      }
                    })
                  }
                } else {
                  List() {
                    ForEach(this.messagesWithImage, (item: MessageTxtImg) => {
                      ListItem() {
                        Row({ space: 20 }) {
                          if (item.message.role == 'user') {
                            Column() {
                              Row() {
                                Image(item.img)
                                  .width(200)
                              }

                              Row() {
                                Row() {
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
                              Row() {
                                Text((item.message.content.toString()))
                                  .margin(10)
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
          }.width('100%')
          .layoutWeight(1)

          // todo: Require guide for image generation
          // if (this.isImageIconClick) {
          //   Text('Please describe your image')
          // }
          Column() {
            Row({ space: 20 }) {
              TextArea({ text: this.newMessageContent, placeholder: 'Message', controller: this.textAreaController })
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
                      this.createImageBody.prompt = this.imageGenerateDescription
                      this.startImageGenerateEffect()
                      this.callCreateImage(this.createImageBody)
                    } else {
                      this.currentTextContent.text = this.newMessageContent
                      this.currentContent.push(this.currentTextContent)
                      if (this.mediaBean.localUrl) {
                        this.currentImageContent.image_url.url = this.mediaBean.localUrl
                        this.currentContent.push(this.currentImageContent)
                      }
                      console.info('currentTextContent', this.currentTextContent.text, 'newMsg', this.newMessageContent)
                      this.newMessage = new Message(this.role, this.currentContent)
                      this.newMessageContent = ''
                      this.messages.push(this.newMessage)
                      // this.messagesWithImage.push(new MessageTxtImg(this.newMessage, this.mediaBean.localUrl))
                      this.payload.messages.forEach((item) => {
                        console.info('payload', JSON.stringify(item.content, null, 2))
                      })
                      this.callChatMethod(this.payload)
                    }
                  }
                })
                .width('80%')
                .placeholderColor(this.isBlack ? '#b0ffffff' : '#630e0d0d')
                .fontColor(this.isBlack ? Color.White : Color.Black)
                .backgroundColor(this.isBlack ? '#c8181818' : Color.White)
                .borderWidth(2)
                .borderColor(this.isBlack ? '#46ffffff' : '#65100f0f')

              Image($r('app.media.icon_send'))
                .width(25)
                .borderRadius(3)
                .onClick(() => {
                  this.isCurrentSelectedImageSent = true
                  // 每次发消息的时候都会push一个image到upload列表, 有image的话就有数据
                  if (this.isImageIconClick) {
                    this.createImageBody.prompt = this.imageGenerateDescription
                    this.startImageGenerateEffect()
                    this.callCreateImage(this.createImageBody)
                  } else {
                    this.isWelcomeStatus = false
                    this.currentContent = []
                    this.currentContent.push(new TextContent(this.newMessageContent))

                    if (this.mediaBean.localUrl) {
                      this.mediaHelper.convertToBase64()
                        .then((base64String: string) => {
                          this.currentImageContent.image_url.url = `${base64String}`
                          this.currentContent.push(this.currentImageContent)
                        })
                        .catch((error: BusinessError) => {
                          console.error('Error converting image to Base64:', error);
                        })
                      this.isCurrentMessageUploadImage = true
                    }
                    this.newMessage = new Message(this.role, this.currentContent)
                    this.newMessageContent = ''
                    this.messages.push(this.newMessage)
                    this.messagesWithImage.push(new MessageTxtImg(this.newMessage, this.mediaBean.localUrl))
                    this.newMessage.content.forEach((item: Content) => {
                      Log.info('current text info:', item as TextContent)
                    })
                    // check if image currently uploaded
                    Log.info('Image upload check: ', this.isCurrentMessageUploadImage)
                    if (this.isCurrentMessageUploadImage) {
                      this.uploadImageList.push(this.mediaBean.localUrl)
                    } else {
                      this.uploadImageList.push('')
                    }

                    this.isCurrentMessageUploadImage = false
                    this.currentMessageIndex++
                    this.uploadImageList.forEach((item) => {
                      Log.info('Image uri: ', item)
                    })
                    this.mediaBean.localUrl = ''
                    this.callChatMethod(this.payload)
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
              // this.iconComponent($r("app.media.icon_record"), () => {
              //   // todo: To be developed
              // })

              // Text(`Image:${this.isCreateImageLoading}`)
              if (!this.isCurrentSelectedImageSent) {
                Image(this.mediaBean.localUrl)
                  .width(30)
                  .height(30)
                  .backgroundColor(this.bgColor)
                  .margin({ right: 200 })
              }
              Blank()
                .layoutWeight(1)
            }
          }
          .width('100%')
          .height(80)
          .borderRadius(10)
          .padding(5)

        }
        .width('100%')
        .height('100%')
      }
      .controlButton({
        icons: {
          hidden: $r('app.media.icon_history_light'),
          shown: $r('app.media.icon_history_light'),
          switching: $r('app.media.icon_history_light')
        },
        width: 32,
        height: 32
      })
      .sideBarWidth(150)
      .minSideBarWidth(50)
      .maxSideBarWidth('100%')
    }
    .backgroundColor(this.bgColor)
    .width('100%')
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

