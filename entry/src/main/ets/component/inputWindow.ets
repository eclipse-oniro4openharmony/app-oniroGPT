import promptAction from '@ohos.promptAction'
import { MessageItem } from '../models/message'

@CustomDialog
export struct InputWindowDialog {
  @Link inputMessage: string
  controller: CustomDialogController
  changeInputValue!: (val: string) => void

  build() {
    Column() {
      Column() {
        Text('Please enter topic of this dialog:')
        Row({ space: 10 }) {

          TextInput({ text: this.inputMessage, placeholder: 'topic' })
            .onChange((content: string) => {
              this.inputMessage = content
            })
            .width('70%')

          Button('Save')
            .onClick(() => {
              this.changeInputValue(this.inputMessage)
              promptAction.showToast({ message: 'Topic saved!' })
              this.controller.close()
            })
        }
        .width('100%')
      }
    }
    .width('100%')
  }
}