import file from '@ohos.file.fs';

class FileForAudio {
  filePath: string
  fileModel: string = 'gpt-4o-transcribe'
  constructor(filePath: string) {
    this.filePath = filePath
  }
}

class CreateTranscriptionParams {
  file: file.File;
  // model choice: gpt-4o-transcribe, gpt-4o-mini-transcribe, whisper-1
  model: string;

  constructor(file: file.File, model: string) {
    this.file = file
    this.model = model
  }
}

class CreateTranscriptionResponse {
  text: string
  usage: Usage
  output_tokens: number
  total_tokens: number

  constructor(text: string, usage: Usage, output_tokens: number, total_tokens: number) {
    this.text = text
    this.usage = usage
    this.output_tokens = output_tokens
    this.total_tokens = total_tokens
  }
}


class CreateTranslationParams {
  file: file.File;
  // model choice: gpt-4o-transcribe, gpt-4o-mini-transcribe, whisper-1
  model: string;

  constructor(file: file.File, model: string) {
    this.file = file
    this.model = model
  }
}



class Usage {
  type: string
  input_tokens: number
  input_token_details: InputTokenDetails

  constructor(type: string, input_tokens: number, input_token_details: InputTokenDetails) {
    this.type = type
    this.input_tokens = input_tokens
    this.input_token_details = input_token_details
  }
}

class InputTokenDetails {
  text_tokens: number
  audio_tokens: number

  constructor(text_tokens: number, audio_tokens: number) {
    this.text_tokens = text_tokens
    this.audio_tokens = audio_tokens
  }
}

export { CreateTranscriptionParams, CreateTranscriptionResponse, FileForAudio, CreateTranslationParams }
