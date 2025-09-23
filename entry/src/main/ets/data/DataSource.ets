import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import { DataResponse, HeaderForModel, Model, Body, } from '../models/models';
import { ChatResponse, HeaderForChat } from '../models/chat';
import { CreateImageBodyParams, CreateImageResponse, EditImageBodyParams, HeaderForImage } from '../models/image';
import {
  CreateTranscriptionParams,
  CreateTranscriptionResponse,
  HeaderForAudio,
  CreateTranslationParams
} from '../models/audio';
import { Log } from '../utils/Log';
import fs from "@ohos.file.fs"

const BASE_URL = "https://api.openai.com"

const getModel = BASE_URL + "/v1/models"

//Replace the token if necessary
// todo: token to be replaced

// todo: Consider to replace api with DeepSeek rather than openai
const authToken = ""

const makeChat = BASE_URL + "/v1/chat/completions"

const createImage = BASE_URL + "/v1/images/generations"
// const model: string = 'gpt-3.5-turbo'

const editImage = BASE_URL + "/v1/images/edits"

const createTranscription = BASE_URL + "/v1/audio/transcriptions"

const contentType: string = 'application/json'

const createTranslation = BASE_URL + "/v1/audio/translations"

class GetFileBytesAndMetaResponse {
  fileName: string;
  mime: string;
  bytes: Uint8Array;

  constructor(fileName: string, mime: string, bytes: Uint8Array) {
    this.fileName = fileName
    this.mime = mime
    this.bytes = bytes
  }
}
;

interface MultipartFileField {
  fieldName: 'file';
  filename: string;
  mime: string;
  content: Uint8Array;
};

interface GeneratedTypeLiteralInterface_1 {
  text?: string;
  error?: BusinessError;
}

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
            } finally {
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
            } finally {
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
            } finally {
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
            } finally {
              httpRequest.off('headersReceive')
              httpRequest.destroy()
            }
          } else {
            reject('Error: ' + err)
          }
        })
    })
  }

  // 读取 file.File 或 路径，返回文件名/字节/MIME
  private _getFileBytesAndMeta(f: fs.File | string): GetFileBytesAndMetaResponse {
    if (typeof f === 'string') {
      const filename: string = f.substring(f.lastIndexOf('/') + 1) || 'audio.wav';
      const bytes: Uint8Array = this._readAllBytesFromPath(f); // statSync(path) + 读满
      const mime: string = this._mimeFromName(filename);
      let m: GetFileBytesAndMetaResponse = new GetFileBytesAndMetaResponse(filename, mime, bytes)
      return m;
    } else {
      const bytes: Uint8Array = this._readAllBytesFromFd(f.fd); // 分块循环直到 0
      // 如果拿不到真实文件名，就给个合理缺省
      const filename: string = 'audio.wav';
      const mime: string = 'audio/wav';
      let m: GetFileBytesAndMetaResponse = new GetFileBytesAndMetaResponse(filename, mime, bytes)
      return m;
    }
  }

  private _readAllBytes(path: string): Uint8Array {
    const st = fs.statSync(path);
    const ab = new ArrayBuffer(st.size);
    const f = fs.openSync(path, fs.OpenMode.READ_ONLY);
    let off = 0;
    while (off < st.size) {
      const n = fs.readSync(f.fd, ab, { offset: off, length: st.size - off });
      if (n <= 0) {
        break;
      }
      off += n;
    }
    fs.closeSync(f.fd);
    return new Uint8Array(ab, 0, off);
  }

  // 路径读取（用 statSync 拿大小一次分配）
  private _readAllBytesFromPath(path: string): Uint8Array {
    const st = fs.statSync(path);
    const ab = new ArrayBuffer(st.size);
    const fh = fs.openSync(path, fs.OpenMode.READ_ONLY);
    let off = 0;
    while (off < st.size) {
      const n = fs.readSync(fh.fd, ab, { offset: off, length: st.size - off });
      if (n <= 0) {
        break;
      }
      off += n;
    }
    fs.closeSync(fh.fd);
    return new Uint8Array(ab, 0, off);
  }

  // 基于 fd 的分块读取（不依赖文件大小，也不需要 fstatSync）
  private _readAllBytesFromFd(fd: number): Uint8Array {
    const CHUNK = 64 * 1024;
    const chunks: Uint8Array[] = [];
    let offset = 0;
    for (;; ) {
      const buf = new ArrayBuffer(CHUNK);
      const n = fs.readSync(fd, buf, { offset, length: CHUNK });
      if (n <= 0) {
        break;
      }
      chunks.push(new Uint8Array(buf, 0, n));
      offset += n;
    }
    let total = 0;
    for (let i = 0; i < chunks.length; i++) {
      total += chunks[i].length;
    }
    const out = new Uint8Array(total);
    let pos = 0;
    for (let i = 0; i < chunks.length; i++) {
      out.set(chunks[i], pos);
      pos += chunks[i].length;
    }
    return out;
  }

  // todo: Implement httpPost with curl -F like ability
  async createTranscriptions(payload: CreateTranscriptionParams): Promise<CreateTranscriptionResponse> {
    // 1) 读取文件字节 + 文件名/MIME
    const meta = this._getFileBytesAndMeta(payload.file); // { filename, bytes, mime }

    // 2) 文本字段 -> 键值对数组（避免 ArkTS 索引签名/unknown）
    const textPairs: Array<[string, string]> = [['model', payload.model]];
    // 如果你的 CreateTranscriptionParams 里还支持这些字段，可按需追加
    // if (payload.language)        textPairs.push(['language', payload.language]);
    // if (payload.prompt)          textPairs.push(['prompt', payload.prompt]);
    // if (payload.response_format) textPairs.push(['response_format', payload.response_format]);
    // if (typeof payload.temperature === 'number') textPairs.push(['temperature', String(payload.temperature)]);

    // 3) 组装 multipart/form-data
    const boundary: string = '----ohosFormBoundary' + Math.random().toString(16).slice(2);
    const body: Uint8Array = this._buildMultipart(
      boundary,
      textPairs,
      {
        fieldName: 'file',
        filename: meta.fileName,
        mime: meta.mime,
        content: meta.bytes
      }
    );
    // 4) 发送 HTTP（⚠️ 此处不要再用 HeaderForAudio；要把 boundary 拼进 Content-Type）
    const httpRequest = http.createHttp();
    return new Promise<CreateTranscriptionResponse>((resolve, reject) => {
      httpRequest.request(
        createTranscription,
        {
          method: http.RequestMethod.POST,
          header: {
            'Authorization': `Bearer ${authToken}`,
            'Content-Type': `multipart/form-data; boundary=${boundary}`,
            'Accept': 'application/json'
          },
          extraData: body.buffer, // 关键：二进制，不是 JSON
          expectDataType: http.HttpDataType.STRING,
          readTimeout: 60000,
          connectTimeout: 30000
        },
        (err: Error, data: http.HttpResponse) => {
          try {
            if (err) {
              return reject(err);
            }
            // 2xx 返回
            const text = (data.result ?? '') as string;
            const json = JSON.parse(text) as CreateTranscriptionResponse;
            resolve(json);
          } catch (e) {
            reject(e);
          } finally {
            try {
              httpRequest.off('headersReceive');
            } catch {
            }
            try {
              httpRequest.destroy();
            } catch {
            }
          }
        }
      );
    });
  }

  async createTranslation(payload: CreateTranslationParams): Promise<string> {
    // 1) 固定全量 URL（不要只传 /v1/...）
    const TRANSLATE_URL = 'https://api.openai.com/v1/audio/translations';
    const meta = this._getFileBytesAndMeta(payload.file);

    // 2) whisper-1 才支持这个端点
    const textPairs: Array<[string, string]> = [
      ['model', 'whisper-1'],                          // ← 不要用 gpt-4o-transcribe
    // ['prompt', 'optional...'],                    // 可选
    // ['response_format', 'json' | 'text'],         // 默认 json
    // ['temperature', '0']                          // 可选
    ];

    const boundary = '----ohosFormBoundary' + Math.random().toString(16).slice(2);
    const body = this._buildMultipart(boundary, textPairs, {
      fieldName: 'file',
      filename: meta.fileName,                         // *.wav / *.mp3 / *.m4a
      mime: meta.mime,                                 // audio/wav 等
      content: meta.bytes
    });

    const httpRequest = http.createHttp();
    return new Promise<string>((resolve, reject) => {
      httpRequest.request(
        TRANSLATE_URL,                                 // ← 确保就是这个完整 URL
        {
          method: http.RequestMethod.POST,
          header: {
            'Authorization': `Bearer ${authToken}`,
            'Content-Type': `multipart/form-data; boundary=${boundary}`,
            'Accept': 'application/json'
          },
          // ArkTS http 这里传 ArrayBuffer 即可
          extraData: body.buffer,
          expectDataType: http.HttpDataType.STRING,
          readTimeout: 60000,
          connectTimeout: 30000
        },
        (err: Error, res: http.HttpResponse) => {
          try {
            if (err) return reject(err);

            const raw = (res.result ?? '') as string;
            Log.info('[createTranslation] status=' + res.responseCode);
            Log.info('[createTranslation] raw=' + raw);

            // 返回形如 { text: "..." } 或 { error: {...} }
            const obj = JSON.parse(raw) as GeneratedTypeLiteralInterface_1;
            if (obj?.text) return resolve(obj.text);

            return reject(new Error('Translation failed: ' + raw));
          } catch (e) {
            reject(e);
          } finally {
            try { httpRequest.off('headersReceive'); } catch {}
            try { httpRequest.destroy(); } catch {}
          }
        }
      );
    });
  }
  private _mimeFromName(name: string): string {
    const low = name.toLowerCase();
    if (low.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (low.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (low.endsWith('.m4a')) {
      return 'audio/mp4';
    }
    if (low.endsWith('.ogg')) {
      return 'audio/ogg';
    }
    if (low.endsWith('.webm')) {
      return 'audio/webm';
    }
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
    let total = 0;
    for (const p of parts) {
      total += p.length;
    }
    const body = new Uint8Array(total);
    let off = 0;
    for (const p of parts) {
      body.set(p, off);
      off += p.length;
    }
    return body;
  }
}


// 调用函数执行请求
export { chatDataSource }
