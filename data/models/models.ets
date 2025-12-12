class Model {
  id: string // Model ID
  object: string // Model type
  owned_by: string // Owner
  created: Date

  constructor(id: string, object: string, owned_by: string, created: Date) {
    this.id = id
    this.object = object
    this.owned_by = owned_by
    this.created = created
  }
}

// Data response class
class DataResponse {
  data: Model[] // Model list
  object: string // Response type

  constructor(data: Model[], object: string) {
    this.data = data
    this.object = object
  }
}

// Define request header
class HeaderForModel {
  Authorization: string

  constructor(authToken: string) {
    this.Authorization = `Bearer ${authToken}`;
  }
}

class ImageUrl {
  url: string = ''
}

class ImageContent {
  type: string = 'image_url'
  image_url: ImageUrl = new ImageUrl()

  constructor(url: string) {
    this.image_url.url = url
  }
}

class TextContent {
  type: string = 'text'
  text: string = ''

  constructor(text: string) {
    this.text = text
  }
}

type Content = TextContent | ImageContent

class Message {
  role: string
  content: Content[]

  constructor(role: string, content: Content[]) {
    this.role = role
    this.content = content
  }
}

class ChatBodyParams {
  messages: Message[]
  model: string

  constructor(messages: Message[], model: string) {
    this.messages = messages
    this.model = model
  }
}

class Body {
  model: string
  messages: Message[]
  temperature?: number
  max_tokens?: number

  constructor(model: string, messages: Message[], temperature?: number, max_tokens?: number) {
    this.model = model
    this.messages = messages
    this.temperature = temperature
    this.max_tokens = max_tokens
  }
}

class imageExist {
  exist: boolean = false
  img: string = ''

  constructor(exist: boolean, img: string) {
    this.exist = exist
    this.img = img
  }
}

class MessageTxtImg {
  message: Message
  img: string

  constructor(msg: Message, img: string) {
    this.message = msg
    this.img = img
  }
}

export {
  HeaderForModel,
  DataResponse,
  Model,
  ChatBodyParams,
  Body,
  Message,
  Content,
  ImageContent,
  TextContent,
  imageExist,
  MessageTxtImg
}