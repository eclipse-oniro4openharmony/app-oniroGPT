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
  // Model name: dall-e-3, dall-e-2
  model: string;
  prompt: string;
  /**
   * Number of images to generate. Must be between 1 and 10.
   */
  n: number;
  /**
   * Text description of the desired image. Maximum length is 1000 characters.
   */
  /**
   * If calling hd, fill in hd here
   */
  // quality?: string;
  /**
   * Size of the generated image. Must be one of 256x256, 512x512, 1024x1024, or 1024x1792.
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