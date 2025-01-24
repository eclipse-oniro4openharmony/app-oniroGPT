import file from '@ohos.file.fs'; //用于读取普通文件
import util from '@ohos.util';
import { Log } from './Log';
import { BusinessError } from '@ohos.base';
import common from '@ohos.app.ability.common';
import { StringUtils } from './StringUtils';

let base64 = new util.Base64Helper();
let context = getContext(this) as common.UIAbilityContext;
let pathDir = context.filesDir
let stringUtils = new StringUtils()


async function convertToBase64() {
  try {
    // 读取文件内容为 Uint8Array
    const uint8Array = await readFileAsUint8Array();

    // 创建 Base64Helper 实例
    const base64 = new util.Base64Helper();

    // 转换为 Base64 字符串
    const base64Str = base64.encodeToStringSync(uint8Array, util.Type.MIME);
    console.info('Base 64 Encoded String:', base64Str);

    return base64Str;
  } catch (err) {
    Log.error('Base 64', 'Error converting to Base64:', err);
    return err as string
  }
}

// 拉起用户图库选择图片：
// 使用图片类用户文件选择器PhotoViewPicker拉起用户图库并选择图片，
// 与此同时获取到选中图片的uri。
// 由于图库中图片属于系统资源，可被其他程序删除，修改，最终造成图库中uri路径失效，
// 因此通常是将获取的图片资源推送至应用沙箱中指定路径或上传应用服务器中。
// 采用选择图库图片后将图片拷贝至应用沙箱中指定路径中。

// todo: 将获取的图片资源推送至应用沙箱中指定路径
// todo: 选择图库图片后将图片拷贝至应用沙箱中指定路径中

async function readFileAsUint8Array(): Promise<Uint8Array> {
  try {
    let testPath: string = pathDir
    // 打开文件
    //这里报错的话大部分是因为路径下文件为只读模式，可你写的模式为读写模式
    const openedFile = file.openSync(testPath, file.OpenMode.READ_ONLY)

    // 获取文件大小
    const stats = file.statSync(testPath)
    // 根据文件大小开辟对应缓存空间
    let buffer: ArrayBuffer = new ArrayBuffer(stats.size)
    Log.info('Base 64', 'opened path:', openedFile.path)
    Log.info('Base 64', 'pathDir:', pathDir)

    // Read file into arrayBuffer flow
    Log.info('Base 64', 'File descriptor:', openedFile.fd)
    Log.info('Base 64', 'File allocated buffer before read:', stringUtils.arrayBuffer2String(buffer))
    // Log.info('Base 64', 'File allocated buffer byte length:', buffer.byteLength)

    // todo: 问题所在之处， 无法将文件数据读取到缓存中

    file.readSync(openedFile.fd, buffer, { offset: 0, length: stats.size })

    Log.info('Base 64', 'File allocated buffer after read:', stringUtils.arrayBuffer2String(buffer))

    // convert arrayBuffer flow into Unit8Array flow
    // const uint8Array = new Uint8Array(buffer)

    // 关闭文件
    file.closeSync(openedFile);

    // return uint8Array;

    return new Promise<Uint8Array>((resolve) => {
      let uint8Array = new Uint8Array(buffer)
      Log.info('Base 64', 'File successfully read as Uint8Array:', uint8Array);
      // unit8ArrayPrint()
      resolve(uint8Array)
    })
  } catch (err) {
    Log.error('Base 64', 'Error reading file:', err);
    Log.error('Base 64', 'Error reading file:', pathDir);
    return Promise.reject(err);
  }
}

async function testReadUrl(filePath: string) {
  let testPath: string = pathDir
  try {
    Log.info('Base 64', 'pathDir:', pathDir)
    Log.info('Base 64', 'filePath:', filePath)
    Log.info('Base 64', 'filePath:', testPath)
    const openedFile = file.openSync(testPath, file.OpenMode.READ_ONLY)
    const stats = file.statSync(testPath)
    let buffer: ArrayBuffer = new ArrayBuffer(stats.size)
    file.readSync(openedFile.fd, buffer, { offset: 0, length: stats.size })
    file.closeSync(openedFile)
    return new Promise<Uint8Array>((resolve) => {
      let uint8Array = new Uint8Array(buffer)
      Log.info('Base 64', 'File successfully read as Uint8Array:', uint8Array);
      // unit8ArrayPrint()
      resolve(uint8Array)
    })
  } catch (err) {
    Log.error('Base 64', 'Error reading file:', err);
    Log.error('Base 64', 'Error reading file:', testPath);
    return Promise.reject(err);
  }
}

function checkFileExist(imageFilePath: string) {
  let testPath = pathDir + '/res.jpg'
  const openedFile = file.openSync(testPath, file.OpenMode.CREATE)
  if (file.accessSync(testPath)) {
    console.info('Fileq exists:', testPath);
  } else {
    console.error('Fileq does not exist:', testPath);
  }
}

// function unit8ArrayPrint(){
//   const uint8Array = new Uint8Array([1, 2, 3, 4, 5]);
//   Log.info('Base 64', 'Print sample Uint8Array:', uint8Array);
// }

//
// function getFileSize() {
//   let stat = file.statSync(pathDir); // async
//   Log.info("get file info succeed, the size of file is " + stat.size);
// }
//
// function OpenFile() {
//   const res = file.openSync(pathDir)
//   Log.info('get file into open inside')
//   // let stat = file.statSync(pathDir);// async
//   Log.info('get file info opened succeed, the size of file is', res.fd, 'File path', res.path, 'File name', res.name, 'res type', typeof (res))
// }
//
// function ReadFile() {
//   // get size
//   let stats = file.statSync(pathDir)
//   let buffer: ArrayBuffer = new ArrayBuffer(stats.size)
//   const openedFile = file.openSync(pathDir)
//   Log.info('get file into read inside before sync')
//   let num = file.read(openedFile.fd, buffer, { offset: 0, length: stats.size });
//   Log.info('get file into read inside after sync num ==', num)
//   const uint8Array = new Uint8Array(buffer)
//   Log.info('Base 64', 'File successfully read as Uint8Array:', uint8Array);
// }

export { convertToBase64, testReadUrl, readFileAsUint8Array, checkFileExist }