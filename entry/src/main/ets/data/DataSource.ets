import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import { DataResponse, Headers, Model } from '../models/chatgpt';

const BASE_URL = "https://api.chatanywhere.org"

const getModel = BASE_URL + "/v1/models"

class chatDataSource {
  constructor() {
  }

  // 定义HTTP请求逻辑
  async fetchModels(): Promise<Model[]> {
    return new Promise<Model[]>((resolve, reject) => {
      let httpRequest = http.createHttp()
      httpRequest.request(getModel,
        {
          method: http.RequestMethod.GET, // 请求方法
          header: new Headers("sk-wJc5pQkW0ZKz9gP1ITTSAxxNoH27Ri50lA4IaRFqL69KxOZs"), // 请求头
          expectDataType: http.HttpDataType.STRING, // 返回数据类型
          readTimeout: 30000, // 读取超时时间
          connectTimeout: 30000, // 连接超时时间
        },
        (err: BusinessError, data: http.HttpResponse) => {
          if (!err) {
            try {
              // 请求成功，处理响应数据
              let responseData: DataResponse = JSON.parse(data.result as string)
              resolve(responseData.data); // 请求成功，返回数据
            } catch (error) {
              reject('Failed to parse response data'); // 捕获解析错误
            }
            finally {
              httpRequest.off('headersReceive');
              httpRequest.destroy();
            }
          } else {
            // 请求失败，处理错误
            reject('Error: ' + err); // 请求失败，返回错误
          }
        })
    })

    // 创建 HTTP 请求实例
    const httpRequest = http.createHttp();

    // 监听响应头
    httpRequest.on('headersReceive', (header: Object) => {
      console.info('Headers received: ' + JSON.stringify(header));
    });

    // 设置请求参数
    httpRequest.request(
      getModel, // 请求的URL
      {
        method: http.RequestMethod.GET, // 请求方法
        header: new Headers("sk-wJc5pQkW0ZKz9gP1ITTSAxxNoH27Ri50lA4IaRFqL69KxOZs"), // 请求头
        expectDataType: http.HttpDataType.STRING, // 返回数据类型
        readTimeout: 30000, // 读取超时时间
        connectTimeout: 30000, // 连接超时时间
      },
      (err: BusinessError, data: http.HttpResponse) => {
        if (!err) {
          // 请求成功，处理响应数据
          console.info('Response Data: ' + JSON.stringify(data.result));
          console.info('Response Code: ' + JSON.stringify(data.responseCode));
          console.info('Response Type: ' + JSON.stringify(data.resultType));
          console.info('Response Headers: ' + JSON.stringify(data.header));
          console.info('Response Cookies: ' + JSON.stringify(data.cookies));

          // 销毁 HTTP 请求对象
          httpRequest.off('headersReceive');
          httpRequest.destroy();
        } else {
          // 请求失败，处理错误
          console.error('Error: ' + JSON.stringify(err));

          // 销毁 HTTP 请求对象
          httpRequest.off('headersReceive');
          httpRequest.destroy();
        }
      }
    );
  }

  async fetchHttpCode(): Promise<number> {
    try {
      let httpRequest = http.createHttp();
      const response = await new Promise<number>((resolve, reject) => {
        httpRequest.request(BASE_URL, (err: Error, data: http.HttpResponse) => {
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
}


// 调用函数执行请求
export { chatDataSource }
