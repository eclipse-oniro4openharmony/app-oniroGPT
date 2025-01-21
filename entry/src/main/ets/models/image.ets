class HeaderForImage {
  Authorization: string
  ContentType: string

  constructor(authToken: string, type: string) {
    this.Authorization = `Bearer ${authToken}`;
    this.ContentType = type
  }
}

class CreateImageBodyParams {
  // 模型名称dall-e-3,dall-e-2
  model: string;

  prompt: string;
  /**
   * 要生成的图像数。必须介于 1 和 10 之间。
   */
  n: number;
  /**
   * 所需图像的文本描述。最大长度为 1000 个字符。
   */
  /**
   * 如果过调用hd 此处填hd
   */
  // quality?: string;
  /**
   * 生成图像的大小。必须是256x256、512x512或 之一1024x1024, 1024x1792。
   */
  size: string;

  constructor(model: string, prompt: string, n: number, size: string) {
    this.model = model
    this.prompt = prompt
    this.n = n
    this.size = size
  }
}

interface CreateImageResponse {
  created: number
  data: Image[]
}

interface Image {
  url: string
  revised_prompt: string
}

export { HeaderForImage, CreateImageBodyParams, CreateImageResponse }