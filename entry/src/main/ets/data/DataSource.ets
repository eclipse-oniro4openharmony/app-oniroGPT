import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import { DataResponse, HeaderForModel, Model, Body, } from '../models/models';
import { ChatResponse, HeaderForChat } from '../models/chat';
import { CreateImageBodyParams, CreateImageResponse, EditImageBodyParams, HeaderForImage } from '../models/image';
import { CreateTranscriptionParams, CreateTranscriptionResponse, HeaderForAudio } from '../models/audio';
import { Log } from '../utils/Log';

const BASE_URL = "https://api.openai.com"

const getModel = BASE_URL + "/v1/models"

//Replace the token if necessary
// todo: token to be replaced

// todo: Consider to replace api with DeepSeek rather than openai
const authToken =  ""

const makeChat = BASE_URL + "/v1/chat/completions"

const createImage = BASE_URL + "/v1/images/generations"
// const model: string = 'gpt-3.5-turbo'

const editImage = BASE_URL + "/v1/images/edits"

const createTranscription = BASE_URL + "/v1/audio/transcriptions"

const contentType: string = 'application/json'

interface MultipartFileField {
  fieldName: 'file';
  filename: string;
  mime: string;
  content: Uint8Array;
};

class chatDataSource {
  model?: string
  message?: string

  constructor(model?: string, message?: string) {
    this.model = model
    this.message = message
  }

  async fetchModels(): Promise<Model[]> {
    return new Promise<Model[]>((resolve, reject) => {
      let httpRequest = http.createHttp()
      httpRequest.request(getModel,
        {
          method: http.RequestMethod.GET,
          header: new HeaderForModel(authToken),
          expectDataType: http.HttpDataType.STRING,
          readTimeout: 30000,
          connectTimeout: 30000,
        },
        (err: BusinessError, data: http.HttpResponse) => {
          if (!err) {
            try {
              let responseData: DataResponse = JSON.parse(data.result as string)
              resolve(responseData.data)
            } catch (error) {
              reject('Failed to parse response data')
            }
            finally {
              httpRequest.off('headersReceive');
              httpRequest.destroy();
            }
          } else {
            reject('Error: ' + err)
          }
        })
    })
  }

  async callChatApi(payload: Body): Promise<ChatResponse> {
    return new Promise<ChatResponse>((resolve, reject) => {
      let httpRequest = http.createHttp()
      httpRequest.request(makeChat,
        {
          method: http.RequestMethod.POST,
          header: new HeaderForChat(authToken, contentType),
          extraData: JSON.stringify(payload),
          expectDataType: http.HttpDataType.STRING,
          readTimeout: 30000,
          connectTimeout: 30000
        },

        (err: Error, data: http.HttpResponse) => {
          if (!err) {
            try {
              let responseData: ChatResponse = JSON.parse(data.result as string)
              resolve(responseData)
            } catch (error) {
              reject('Failed to parse response data')
            }
            finally {
              httpRequest.off('headersReceive')
              httpRequest.destroy()
            }
          } else {
            reject('Error: ' + err)
          }
        })
    })
  }

  async fetchHttpCode(): Promise<number> {
    try {
      let httpRequest = http.createHttp();
      const response = await new Promise<number>((resolve, reject) => {
        httpRequest.request(getModel,
          {
            method: http.RequestMethod.GET,
            header: new HeaderForModel(authToken),
            expectDataType: http.HttpDataType.STRING,
            readTimeout: 30000,
            connectTimeout: 30000,
          },
          (err: Error, data: http.HttpResponse) => {
            if (!err) {
              resolve(data.responseCode);
            } else {
              reject(err);
            }
          });
      });
      return response;
    } catch (error) {
      console.error('Error fetching HTTP code:', error);
      return -1;
    }
  }

  async createImage(payload: CreateImageBodyParams): Promise<CreateImageResponse> {
    return new Promise<CreateImageResponse>((resolve, reject) => {
      let httpRequest = http.createHttp()
      httpRequest.request(createImage,
        {
          method: http.RequestMethod.POST,
          header: new HeaderForImage(authToken, contentType),
          extraData: JSON.stringify(payload),
          expectDataType: http.HttpDataType.STRING,
          readTimeout: 30000,
          connectTimeout: 30000
        },

        (err: Error, data: http.HttpResponse) => {
          if (!err) {
            try {
              let responseData: CreateImageResponse = JSON.parse(data.result as string)
              resolve(responseData)
            } catch (error) {
              reject('Failed to parse response data')
            }
            finally {
              httpRequest.off('headersReceive')
              httpRequest.destroy()
            }
          } else {
            reject('Error: ' + err)
          }
        })
    })
  }

  async editImage(payload: EditImageBodyParams): Promise<CreateImageResponse> {
    return new Promise<CreateImageResponse>((resolve, reject) => {
      let httpRequest = http.createHttp()
      httpRequest.request(editImage,
        {
          method: http.RequestMethod.POST,
          header: new HeaderForImage(authToken, contentType),
          extraData: JSON.stringify(payload),
          expectDataType: http.HttpDataType.STRING,
          readTimeout: 30000,
          connectTimeout: 30000
        },

        (err: Error, data: http.HttpResponse) => {
          if (!err) {
            try {
              let responseData: CreateImageResponse = JSON.parse(data.result as string)
              resolve(responseData)
            } catch (error) {
              reject('Failed to parse response data')
            }
            finally {
              httpRequest.off('headersReceive')
              httpRequest.destroy()
            }
          } else {
            reject('Error: ' + err)
          }
        })
    })
  }

// todo: Implement httpPost with curl -F like ability
  async createTranscriptions(payload: CreateTranscriptionParams): Promise<CreateTranscriptionResponse> {


    return new Promise<CreateTranscriptionResponse>((resolve, reject) => {
      let httpRequest = http.createHttp()
      httpRequest.request(createTranscription,
        {
          method: http.RequestMethod.POST,
          header: new HeaderForAudio(authToken, "multipart/form-data"),
          extraData: JSON.stringify(payload),
          readTimeout: 30000,
          connectTimeout: 30000
        },

        (err: Error, data: http.HttpResponse) => {
          if (!err) {
            try {
              let responseData: CreateTranscriptionResponse = JSON.parse(data.result as string)
              resolve(responseData)
              Log.info('Transcription', JSON.stringify(responseData, null, 2))
            } catch (error) {
              reject('Failed to parse response data')
            }
            finally {
              httpRequest.off('headersReceive')
              httpRequest.destroy()
            }
          } else {
            reject('Error: ' + err)
          }
        })
    })
  }

  private _mimeFromName(name: string): string {
    const low = name.toLowerCase();
    if (low.endsWith('.wav')) return 'audio/wav';
    if (low.endsWith('.mp3')) return 'audio/mpeg';
    if (low.endsWith('.m4a')) return 'audio/mp4';
    if (low.endsWith('.ogg')) return 'audio/ogg';
    if (low.endsWith('.webm')) return 'audio/webm';
    return 'application/octet-stream';
  }

  // UTF-8 编码（兼容 ArkTS，无 TextEncoder）
  private _utf8(s: string): Uint8Array {
    const out: number[] = [];
    for (let i = 0; i < s.length; i++) {
      let code = s.charCodeAt(i);
      // 处理代理对 -> 码点
      if (code >= 0xD800 && code <= 0xDBFF && i + 1 < s.length) {
        const next = s.charCodeAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          code = ((code - 0xD800) << 10) + (next - 0xDC00) + 0x10000;
          i++;
        }
      }
      if (code <= 0x7F) {
        out.push(code);
      } else if (code <= 0x7FF) {
        out.push(0xC0 | (code >> 6));
        out.push(0x80 | (code & 0x3F));
      } else if (code <= 0xFFFF) {
        out.push(0xE0 | (code >> 12));
        out.push(0x80 | ((code >> 6) & 0x3F));
        out.push(0x80 | (code & 0x3F));
      } else {
        out.push(0xF0 | (code >> 18));
        out.push(0x80 | ((code >> 12) & 0x3F));
        out.push(0x80 | ((code >> 6) & 0x3F));
        out.push(0x80 | (code & 0x3F));
      }
    }
    return new Uint8Array(out);
  }

  // 组装 multipart（文本字段 = 键值对数组；单文件字段）
  private _buildMultipart(
    boundary: string,
    textPairs: ReadonlyArray<[string, string]>,
    fileField: MultipartFileField
  ): Uint8Array {
    const parts: Uint8Array[] = [];

    // 文本字段（不用解构）
    for (let i = 0; i < textPairs.length; i++) {
      const pair = textPairs[i];
      const k: string = pair[0];
      const v: string = pair[1];
      parts.push(this._utf8(`--${boundary}\r\n`));
      parts.push(this._utf8(`Content-Disposition: form-data; name="${k}"\r\n\r\n`));
      parts.push(this._utf8(v));
      parts.push(this._utf8(`\r\n`));
    }

    // 文件字段（字段名必须是 file）
    parts.push(this._utf8(`--${boundary}\r\n`));
    parts.push(this._utf8(
      `Content-Disposition: form-data; name="${fileField.fieldName}"; filename="${fileField.filename}"\r\n` +
        `Content-Type: ${fileField.mime}\r\n\r\n`
    ));
    parts.push(fileField.content);
    parts.push(this._utf8(`\r\n--${boundary}--\r\n`));

    // 拼接
    let total = 0; for (const p of parts) total += p.length;
    const body = new Uint8Array(total);
    let off = 0;
    for (const p of parts) { body.set(p, off); off += p.length; }
    return body;
  }
}


// 调用函数执行请求
export { chatDataSource }
