import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import { DataResponse, HeaderForModel, Model, Body, } from '../models/models';
import { ChatResponse, HeaderForChat } from '../models/chat';
import { CreateImageBodyParams, CreateImageResponse, EditImageBodyParams, HeaderForImage } from '../models/image';
import { CreateTranscriptionParams, CreateTranscriptionResponse, HeaderForAudio } from '../models/audio';

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


}


// 调用函数执行请求
export { chatDataSource }
