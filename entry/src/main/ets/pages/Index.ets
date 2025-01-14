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

        if (reply && reply.choices) {
          this.repliedChoices = reply.choices;
          this.repliedChoices.forEach((item: Choice) => {
            console.info(item.message?.role || '无角色信息');
            console.info(item.message?.content || '无内容信息');
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
        Text(this.message)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
  }
}