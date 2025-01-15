import { chatDataSource } from '../data/DataSource'
import { Body, ChatBodyParams, DataResponse, HeaderForModel, Message, Model } from '../models/models';
import { BusinessError } from '@ohos.base';
import { ChatResponse, Choice } from '../models/chat';

@Entry
@Component
struct Index {
  @State httpCode: number = 0
  @State isHttpError: boolean = false
  @State modelResponse: DataResponse | null = null
  @State modelList: Model[] = []
  @State selectedModel: string = 'gpt-3.5-turbo'
  @State messages: Message[] = [] // todo: Consider to place all the data into database
  //Chat response data
  @State repliedChoices: Choice[] = []
  private textAreaController: TextAreaController = new TextAreaController()
  @State newMessageContent: string = ''
  @State newReplyContent: string = ''
  private role: string = 'user'
  @State newMessage: Message = new Message('', '')
  @State payload: Body = new Body(this.selectedModel, this.messages)
  @State repliedMessage: Message = new Message('assistant', '')

  // const message: Message = new Message('user', 'Hello, can you summarize this document for me?')
  //
  // let messages: Message[] = []
  //
  // messages.push(message)
  //
  // const payload: Body = new Body(model, messages)


  // todo: 逻辑上是一开始调用出所有的模型，然后问ai的时候消息应该即时调用对应的消息接口
  aboutToAppear(): void {
    const source = new chatDataSource()

    source.fetchHttpCode().then(async (code) => {
      this.httpCode = code

      if (code === 200) {
        this.modelList = await source.fetchModels()

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

  build() {
    Flex() {
      Column() {

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

        TextArea({ text: this.newMessageContent, placeholder: 'Message', controller: this.textAreaController })
          .type(TextAreaType.NORMAL)
          .onChange((content: string) => {
            this.newMessageContent = content
            console.log(this.newMessageContent)
          })
          .enterKeyType(EnterKeyType.Send)// Configure enter key to trigger event "Send"
          .onSubmit((enterKey: EnterKeyType) => {
            if (enterKey == EnterKeyType.Send) {
              //Upload current message
              this.newMessage = new Message(this.role, this.newMessageContent)
              this.newMessageContent = ''
              this.messages.push(this.newMessage)
              this.callChatMethod(this.payload)
            }
          })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
  }
}