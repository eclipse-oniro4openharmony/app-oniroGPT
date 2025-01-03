// Model 数据类
class Model {
  id: string; // 模型 ID
  object: string; // 模型类型
  owned_by: string; // 所有者
  created: Date;

  constructor(id: string, object: string, owned_by: string) {
    this.id = id;
    this.object = object;
    this.owned_by = owned_by;
  }
}

// 数据响应类
class DataResponse {
  data: Model[]; // 模型列表
  object: string; // 响应类型

  constructor(data: Model[], object: string) {
    this.data = data;
    this.object = object;
  }
}

// 定义请求头
class Headers {
  Authorization: string;

  constructor(authToken: string) {
    this.Authorization = `Bearer ${authToken}`;
  }
}

export { Headers, DataResponse, Model }