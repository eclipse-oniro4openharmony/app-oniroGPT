import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import { ChatBodyParams, DataResponse, HeaderForModel, Message, Model, Body, } from '../models/models';
import { ChatResponse, HeaderForChat } from '../models/chat';
import { CreateImageBodyParams, CreateImageResponse, HeaderForImage } from '../models/image';

const BASE_URL = "https://api.openai.com"

const getModel = BASE_URL + "/v1/models"

//Replace the token if necessary
// todo: to be replaced
const authToken = "you token"

const makeChat = BASE_URL + "/v1/chat/completions"

const createImage = BASE_URL +"/v1/images/generations"
// const model: string = 'gpt-3.5-turbo'

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

}


// 调用函数执行请求
export { chatDataSource }
