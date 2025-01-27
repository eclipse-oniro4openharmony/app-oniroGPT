import { MessageTxtImg } from './models'

class MessageItem {
  messages: MessageTxtImg[]
  topic: string
  isSaved: boolean

  constructor(messages: MessageTxtImg[], topic: string) {
    this.messages = messages
    this.topic = topic
    this.isSaved = true
  }
}

export { MessageItem }