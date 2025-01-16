import { chatDataSource } from '../data/DataSource'
import { Body, ChatBodyParams, DataResponse, HeaderForModel, Message, Model } from '../models/models';
import { BusinessError, Callback } from '@ohos.base';
import { ChatResponse, Choice } from '../models/chat';
import { SelectModel } from '../models/index'

@Entry
@Component
struct Index {
  @State httpCode: number = 0
  @State isHttpError: boolean = false
  @State modelResponse: DataResponse | null = null
  @State modelList: Model[] = []
  @State selectedModel: string = 'gpt-3.5-turbo'
  @State messages: Message[] = [] // todo: Consider to place all the data into database
  //Select model list
  @State selectList: SelectModel[] = []
  @State selectIndex: number = 0
  //Chat response data
  @State repliedChoices: Choice[] = []
  private textAreaController: TextAreaController = new TextAreaController()
  @State newMessageContent: string = ''
  @State newReplyContent: string = ''
  private role: string = 'user'
  @State newMessage: Message = new Message('', '')
  @State payload: Body = new Body(this.selectedModel, this.messages)
  @State repliedMessage: Message = new Message('assistant', '')
  //Initial app page status
  @State isWelcomeStatus: boolean = true
  //Dynamic layout text
  @State displayedText: string = ''
  private welcomeText: string = 'How can I help you today?'
  private index: number = 0 //Current text index

  // const message: Message = new Message('user', 'Hello, can you summarize this document for me?')
  //
  // let messages: Message[] = []
  //
  // messages.push(message)
  //
  // const payload: Body = new Body(model, messages)


  // todo: 逻辑上是一开始调用出所有的模型，然后问ai的时候消息应该即时调用对应的消息接口
  aboutToAppear(): void {

    this.startTypingEffect()

    const source = new chatDataSource()

    source.fetchHttpCode().then(async (code) => {
      this.httpCode = code

      if (code === 200) {

        this.modelList = await source.fetchModels()

        this.modelList.forEach((item: Model) => {
          this.selectList.push(new SelectModel(item.id, $r("app.media.icon")))
        })

        // const reply: ChatResponse = await source.callChatApi().catch(
        //   (err: BusinessError) => {
        //     console.error('Error during callChatApi:', err)
        //   }
        // ) as ChatResponse
        //强打印
        // console.log('Chat Response:', JSON.stringify(reply, null, 2));

        // if (reply && reply.choices) {
        //   this.repliedChoices = reply.choices;
        //   this.repliedChoices.forEach((item: Choice) => {
        //     console.info(item.message?.role || '无角色信息');
        //     console.info(item.message?.content || '无内容信息');
        //   })
        // }


      } else {
        this.isHttpError = true;
        console.error('Failed to fetch data: HTTP Code', code);
      }
    })
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
          this.repliedChoices = reply.choices;
          this.repliedChoices.forEach((item: Choice) => {
            console.info(item.message?.role || 'No role information');
            console.info(item.message?.content || 'No message content');

            this.newReplyContent = item.message?.content || 'No role information'
            this.messages.push(new Message('assistant', this.newReplyContent))
          })
        }
      } else {
        this.isHttpError = true;
        console.error('Failed to fetch data: HTTP Code', code);
      }
    })
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

  // builder
  @Builder
  iconComponent(icon: Resource, callback?: () => void) {
    Image(icon)
      .iconStyle()
      .onClick(callback)
  }

  build() {
    Flex() {
      Column() {

        // todo: Implement select bar
        Column() {
          Select(this.selectList)
            .selected(this.selectIndex)
            .value(this.selectedModel)
            .onSelect((index: number, text?: string | undefined) => {
              this.selectIndex = index
              if (text) {
                this.selectedModel = text
              }
            })
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
            List() {
              ForEach(this.messages, (item: Message) => {
                ListItem() {
                  Row({ space: 20 }) {
                    Text(item.role)
                    Text(item.content)
                  }
                }
              })
            }
          }
        }.width('100%')
        .layoutWeight(1)

        Column() {
          Row({space: 20}) {
            TextArea({ text: this.newMessageContent, placeholder: 'Message', controller: this.textAreaController })
              .type(TextAreaType.NORMAL)
              .onChange((content: string) => {
                this.newMessageContent = content
                console.log(this.newMessageContent)
              })
              .enterKeyType(EnterKeyType.Send)// Configure enter key to trigger event "Send"
              .onSubmit((enterKey: EnterKeyType) => {
                if (enterKey == EnterKeyType.Send) {
                  this.isWelcomeStatus = false
                  //Upload current message
                  this.newMessage = new Message(this.role, this.newMessageContent)
                  this.newMessageContent = ''
                  this.messages.push(this.newMessage)
                  this.callChatMethod(this.payload)
                }
              })
              .width('80%')
            Button('Send')
              .type(ButtonType.Normal)
              .borderRadius(3)
              .onClick(()=>{
                this.isWelcomeStatus = false
                //Upload current message
                this.newMessage = new Message(this.role, this.newMessageContent)
                this.newMessageContent = ''
                this.messages.push(this.newMessage)
                this.callChatMethod(this.payload)
              })
          }
          .width('100%')

          // Row of many functional labels
          // todo: Implement onClick methods of each icon
          Row({ space: 10 }) {
            this.iconComponent($r('app.media.icon_add'), () => {
            })
            this.iconComponent($r('app.media.icon_record'), () => {
            })
            this.iconComponent($r('app.media.icon_earth'), () => {
            })
            Blank()
              .layoutWeight(1)
            this.iconComponent($r('app.media.icon_conversation'), () => {
            })
          }
        }
        .width('100%')
        .height(80)
        .borderRadius(10)
        .borderWidth(1)
        .padding(5)

      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
  }
}

@Extend(Image)
function iconStyle() {
  .width(30)
  .height(30)
  .objectFit(ImageFit.Contain)
}


