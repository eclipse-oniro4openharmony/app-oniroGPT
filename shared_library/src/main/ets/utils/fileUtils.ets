import file from '@ohos.file.fs';
import util from '@ohos.util';
import { Log } from './Log';
import common from '@ohos.app.ability.common';
import { StringUtils } from './StringUtils';

// Do not get context at module top level, will cause undefined error
// let context = getContext(this) as common.UIAbilityContext;
// let pathDir = context.filesDir
const stringUtils = new StringUtils();

// Helper function to get context lazily
function getFilesDir(): string {
  const context = getContext() as common.UIAbilityContext;
  return context.filesDir;
}


async function convertToBase64() {
  try {
    // Read file content as Uint8Array
    const uint8Array = await readFileAsUint8Array();

    // Create Base64Helper instance
    const base64 = new util.Base64Helper();

    // Convert to Base64 string
    const base64Str = base64.encodeToStringSync(uint8Array, util.Type.MIME);
    console.info('Base 64 Encoded String:', base64Str);

    return base64Str;
  } catch (err) {
    Log.error('Base 64', 'Error converting to Base64:', err);
    return err as string
  }
}

// Open user gallery to select images:
// Use PhotoViewPicker to open user gallery and select images,
// and get the uri of the selected image.
// Since images in the gallery are system resources and can be deleted or modified by other programs,
// which may cause the uri path in the gallery to become invalid,
// it is usually necessary to push the obtained image resources to the specified path in the application sandbox or upload them to the application server.
// Copy the image to the specified path in the application sandbox after selecting from the gallery.

// TODO: Push the obtained image resources to the specified path in the application sandbox
// TODO: Copy the image to the specified path in the application sandbox after selecting from the gallery

async function readFileAsUint8Array(): Promise<Uint8Array> {
  try {
    let pathDir = getFilesDir();
    let testPath: string = pathDir
    // Open file
    // If an error occurs here, it is mostly because the file under the path is in read-only mode, but the mode you wrote is read-write mode
    const openedFile = file.openSync(testPath, file.OpenMode.READ_ONLY)

    // Get file size
    const stats = file.statSync(testPath)
    // Allocate buffer space according to file size
    let buffer: ArrayBuffer = new ArrayBuffer(stats.size)
    Log.info('Base 64', 'opened path:', openedFile.path)
    Log.info('Base 64', 'pathDir:', pathDir)

    // Read file into arrayBuffer flow
    Log.info('Base 64', 'File descriptor:', openedFile.fd)
    Log.info('Base 64', 'File allocated buffer before read:', stringUtils.arrayBuffer2String(buffer))
    // Log.info('Base 64', 'File allocated buffer byte length:', buffer.byteLength)

    // TODO: Issue location, unable to read file data into cache

    file.readSync(openedFile.fd, buffer, { offset: 0, length: stats.size })

    Log.info('Base 64', 'File allocated buffer after read:', stringUtils.arrayBuffer2String(buffer))

    // convert arrayBuffer flow into Unit8Array flow
    // const uint8Array = new Uint8Array(buffer)

    // Close file
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
    return Promise.reject(err);
  }
}

async function testReadUrl(filePath: string) {
  let pathDir = getFilesDir();
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
  let pathDir = getFilesDir();
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