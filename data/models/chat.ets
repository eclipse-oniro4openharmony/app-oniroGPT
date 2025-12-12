import { Message } from './models'

class ChatResponse {
  id: string
  object: string
  created: number
  choices: Choice[]
  usage: Usage

  constructor(id: string, object: string, created: number, choices: Choice[], usage: Usage) {
    this.id = id
    this.object = object
    this.created = created
    this.choices = choices
    this.usage = usage
  }
}

class Choice {
  finishReason?: string
  index?: number
  message?: Message

  constructor(index?: number, message?: Message, finishReason?: string) {
    this.finishReason = finishReason
    this.index = index
    this.message = message
  }
}

class Usage {
  completionTokens: number;
  promptTokens: number;
  totalTokens: number;

  constructor(completionTokens: number, promptTokens: number, totalTokens: number) {
    this.completionTokens = completionTokens
    this.promptTokens = promptTokens
    this.totalTokens = totalTokens
  }
}

class HeaderForChat {
  Authorization: string
  ContentType: string

  // [property: string]: any;
  constructor(authToken: string, type: string) {
    this.Authorization = `Bearer ${authToken}`
    this.ContentType = type
  }
}

export {HeaderForChat, ChatResponse, Choice}