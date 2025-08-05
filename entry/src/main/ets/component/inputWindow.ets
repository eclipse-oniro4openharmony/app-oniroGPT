@CustomDialog
export struct InputWindowDialog {
  @Link inputMessage: string
  controller: CustomDialogController
  changeInputValue!: (val: string) => void

  build() {
    Column() {
      Column() {
        Row() {
          Text('Enter Topic')
            .margin(5)
            .fontWeight(FontWeight.Bolder)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height(40)
        .backgroundColor('#fff1e812')

        Row() {
          Text('Please enter the topic of your chat')
            .margin(5)
            .fontWeight(FontWeight.Regular)
        }
        .width('100%')
        .height(60)
        .justifyContent(FlexAlign.Center)


        Row({ space: 10 }) {
          TextInput({ text: this.inputMessage, placeholder: 'topic' })
            .onChange((content: string) => {
              this.inputMessage = content
            })
            .width('90%')
            .height(50)
            .margin(10)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height(60)

        Row({ space: 50 }) {
          Button('Not Ready')
            .onClick(() => {
              this.controller.close()
            })
            .type(ButtonType.Normal)
            .borderRadius(5)
            .width(120)
            .backgroundColor('#3b000000')
            .fontWeight(FontWeight.Bold)

          Button('Confirm')
            .onClick(() => {
              this.changeInputValue(this.inputMessage)
              this.inputMessage = ''
              this.getUIContext().getPromptAction().showToast({
                message: 'Topic saved!'
              })
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