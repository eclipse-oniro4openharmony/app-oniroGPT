import { chatDataSource } from '../data/DataSource'
import { ChatBodyParams, DataResponse, HeaderForModel, Message, Model } from '../models/models';
import { BusinessError } from '@ohos.base';
import { ChatResponse, Choice } from '../models/chat';

@Entry
@Component
struct Index {
  @State message: string = 'Test api'
  @State httpCode: number = 0
  @State isHttpError: boolean = false
  @State modelResponse: DataResponse | null = null
  @State modelList: Model[] = []
  @State selectedModel: string = 'gpt-3.5-turbo'
  @State messages: Message[] = []

  //Chat response data
  @State repliedChoices: Choice[] = []


  aboutToAppear(): void {
    const source = new chatDataSource()

    source.fetchHttpCode().then(async (code) => {
      this.httpCode = code

      if (code === 200) {
        this.modelList = await source.fetchModels()

        const reply: ChatResponse = await source.callChatApi().catch(
          (err: BusinessError) => {
            console.error('Error during callChatApi:', err)
          }
        ) as ChatResponse
        //强打印
        // console.log('Chat Response:', JSON.stringify(reply, null, 2));

        this.repliedChoices = reply.choices

//         console.log(`id: ${reply.id}
//                     create time: ${reply.created}
//                     choices: ${this.repliedChoices}
// `)
        this.repliedChoices.forEach((item: Choice)=>{
          console.info(item.message.role)
          console.info(item.message.content)
        })

      } else {
        this.isHttpError = true;
        console.error('Failed to fetch data: HTTP Code', code);
      }
    })
  }

  build() {
    Row() {
      Column() {
        Text(this.message)
          .fontSize(50)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
    }
    .height('100%')
  }
}