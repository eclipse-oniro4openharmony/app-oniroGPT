@CustomDialog
export struct ReadyNewChatWindow {
  controller: CustomDialogController
  yesButtonAction!: () => void

  build() {
    Column() {
      Column() {
        Row() {
          Text('New Chat')
            .margin(5)
            .fontWeight(FontWeight.Bolder)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height(40)
        .backgroundColor('#fff1e812')

        Row() {
          Text('Do you want create new chat?')
            .margin(5)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .height(60)
        .justifyContent(FlexAlign.Center)

        Row() {
          Text('Remember to save your chat before start new chat')
            .margin(5)
            .fontWeight(FontWeight.Regular)
        }
        .width('85%')
        .height(60)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#5c000000')
        .borderRadius(10)

        Row({ space: 50 }) {
          Button('No')
            .onClick(() => {
              this.controller.close()
            })
            .type(ButtonType.Normal)
            .borderRadius(5)
            .width(120)
            .backgroundColor('#3b000000')
            .fontWeight(FontWeight.Bold)

          Button('Yes')
            .onClick(() => {
              this.yesButtonAction()
              this.controller.close()
            })
            .type(ButtonType.Normal)
            .borderRadius(5)
            .width(120)
            .backgroundColor('#fff1e812')
            .fontColor('#000000')
            .fontWeight(FontWeight.Bold)
        }
        .margin(10)
      }
      .borderRadius(0)
    }
    .width('100%')
  }
}