import file from '@ohos.file.fs'; //用于读取普通文件
import util from '@ohos.util';

let base64 = new util.Base64Helper();

async function convertToBase64(filePath: string): Promise<string> {
  try {
    // 读取文件内容为 Uint8Array
    const uint8Array = await readFileAsUint8Array(filePath);

    // 创建 Base64Helper 实例
    const base64 = new util.Base64Helper();

    // 转换为 Base64 字符串
    const base64Str = base64.encodeToStringSync(uint8Array);
    console.info('Base64 Encoded String:', base64Str);

    return base64Str;
  } catch (err) {
    console.error('Error converting to Base64:', err);
    return err
  }
}

async function readFileAsUint8Array(filePath: string): Promise<Uint8Array> {
  try {
    // 打开文件
    const fd = file.openSync(filePath, file.OpenMode.READ_ONLY);

    // 获取文件大小
    const stats = file.statSync(filePath);
    const buffer = new ArrayBuffer(stats.size);

    // 创建 Uint8Array 并读取文件内容
    const uint8Array = new Uint8Array(buffer)
    const bytesRead = file.readSync(fd.fd, uint8Array as ArrayBuffer, { offset: 0, length: stats.size });

    // 关闭文件
    file.closeSync(fd);

    console.info('File successfully read as Uint8Array:', uint8Array);
    return uint8Array;
  } catch (err) {
    console.error('Error reading file:', err);
    return Promise.reject(err);
  }
}

export { convertToBase64 }