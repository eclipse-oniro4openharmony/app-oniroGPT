import { chatDataSource } from '../data/DataSource'
import { DataResponse, Headers, Model } from '../models/chatgpt';

@Entry
@Component
struct Index {
  @State message: string = 'Test api'
  @State httpCode: number = 0
  @State isHttpError: boolean = false
  @State modelResponse: DataResponse | null = null
  @State modelList: Model[] = []

  aboutToAppear(): void {
    const source = new chatDataSource()

    source.fetchHttpCode().then(async (code) => {
      this.httpCode = code

      if (code === 200) {
        this.modelList = await source.fetchModels()
        this.modelList.forEach((item: Model) => {
          console.info(`id: ${item.id}`)
          console.info(`object: ${item.object}`)
          console.info(`ownedBy: ${item.owned_by}`)
          console.info(`Created: ${item.created}`)
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