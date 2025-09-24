import file from '@ohos.file.fs';
// Image Generation
class HeaderForImage {
  Authorization: string
  ContentType: string

  constructor(authToken: string, type: string) {
    this.Authorization = `Bearer ${authToken}`;
    this.ContentType = type
  }
}

class CreateImageBodyParams {
  // model: dall-e-3,dall-e-2
  model: string;
  prompt: string;
  n: number;
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

// Image Edit
class EditImageBodyParams {
  image: file.File
  prompt: string

  constructor(image: file.File, prompt: string) {
    this.image = image
    this.prompt = prompt
  }
}

// Image Variations

export { HeaderForImage, CreateImageBodyParams, CreateImageResponse, EditImageBodyParams }