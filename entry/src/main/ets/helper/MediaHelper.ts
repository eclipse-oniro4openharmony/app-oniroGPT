import { MediaBean } from '../bean/MediaBean';
import { Log } from '../utils/Log';
import { StringUtils } from '../utils/StringUtils';
import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { picker } from '@kit.CoreFileKit';
import { buffer } from '@kit.ArkTS';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { dataSharePredicates } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

export class MediaHelper {
  private readonly TAG: string = 'MediaHelper';
  private base64 = ''
  private mContext: common.Context;
  private uri: string = ''
  private profileImage: image.PixelMap = new Object() as image.PixelMap

  constructor(context: common.Context) {
    this.mContext = context;
  }

  // Select Image

  private urlIntoSandbox(srcPath: string, dstPath: string): string {
    let file = fs.openSync(srcPath, fs.OpenMode.READ_ONLY) // 系统资源图片
    let file2 = fs.openSync(dstPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE) // 目的地图片
    Log.info(this.TAG, 'filePath: ', srcPath)

    // Image copy from imageUri to the sandbox
    fs.copyFileSync(file.fd, file2.fd)
    fs.closeSync(file.fd)
    fs.closeSync(file2.fd)
    return dstPath
  }

  public selectPicture(): Promise<MediaBean> {

    try {
      let photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      let photoPicker = new photoAccessHelper.PhotoViewPicker();
      return photoPicker.select(photoSelectOptions)
        .then((photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
          Log.info(this.TAG, 'PhotoViewPicker.select successfully, PhotoSelectResult uri: ' + JSON.stringify(photoSelectResult));

          if (photoSelectResult && photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {

            // get selected image uri
            let filePath = photoSelectResult.photoUris[0]
            Log.info(this.TAG, 'PhotoViewPicker.select successfully, PhotoSelectResult uri: ' + filePath)
            Log.info(this.TAG, 'mContext: ', this.mContext.filesDir)

            // get application context path
            let filesDir = this.mContext.filesDir
            let fileName = "userUploadedImages"

            // get filepath in sandbox
            let path = filesDir + "/" + fileName + "." + filePath.split(".")[1] // 提取文件后缀
            Log.info(this.TAG, '沙箱中文件路径(before copy): ', path)
            // let file = fs.openSync(filePath, fs.OpenMode.READ_ONLY) // 系统资源图片
            // let file2 = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE) // 目的地图片
            // Log.info(this.TAG, 'filePath: ', filePath)
            //
            // // Image copy from imageUri to the sandbox
            // fs.copyFileSync(file.fd, file2.fd)
            // fs.closeSync(file.fd)
            // fs.closeSync(file2.fd)

            // Get image sandbox path corresponding uri
            this.uri = this.urlIntoSandbox(filePath, path)
            Log.info(this.TAG, '沙箱中文件路径(after copy): ', this.uri)
            if (fs.accessSync(path)) {
              console.info(this.TAG, 'Fileq exists:', path);
            } else {
              console.error(this.TAG, 'Fileq does not exist:', path)
            }

            if (fs.accessSync(this.uri)) {
              console.info(this.TAG, 'Fileq url exists:', this.uri)
            } else {
              console.error(this.TAG, 'Fileq url does not exist:', this.uri)
            }
            return filePath
          }

        }).catch((err) => {
          Log.error(this.TAG, 'PhotoViewPicker.select failed with err: ' + err)
          return err
        }).then(async (filePath) => {
          const mediaBean = await this.buildMediaBean(filePath)
          return mediaBean
        })
    } catch (err) {
      Log.error(this.TAG, 'PhotoViewPicker failed with err: ' + err);
      return Promise.reject(err);
    }
  }

  public checkFileExist() {
    let testPath = this.uri
    if (fs.accessSync(testPath)) {
      console.info('Fileq exists:', testPath);
    } else {
      console.error('Fileq does not exist:', testPath);
    }
  }

  public readFileAsUint8Array(): Promise<Uint8Array> {
    try {
      let testPath: string = this.uri
      // 打开文件
      //这里报错的话大部分是因为路径下文件为只读模式，可你写的模式为读写模式
      const openedFile = fs.openSync(testPath, fs.OpenMode.READ_WRITE)

      // 获取文件大小
      const stats = fs.statSync(testPath)
      // 根据文件大小开辟对应缓存空间
      let buffer: ArrayBuffer = new ArrayBuffer(stats.size)
      Log.info('Base 64', 'opened path:', openedFile.path)
      Log.info('Base 64', 'pathDir:', this.mContext.filesDir)
      Log.info('Base 64', 'File descriptor:', openedFile.fd)

      // todo: 问题所在之处， 无法将文件数据读取到缓存中

      fs.readSync(openedFile.fd, buffer, { offset: 0, length: stats.size })

      // Log.info('Base 64', 'File allocated buffer after read:', stringUtils.arrayBuffer2String(buffer))

      // convert arrayBuffer flow into Unit8Array flow
      // const uint8Array = new Uint8Array(buffer)

      // 关闭文件
      fs.closeSync(openedFile);

      // return uint8Array;

      return new Promise<Uint8Array>((resolve) => {
        let uint8Array = new Uint8Array(buffer)
        Log.info('Base 64', 'File successfully read as Uint8Array:', uint8Array);
        // unit8ArrayPrint()
        resolve(uint8Array)
      })
    } catch (err) {
      Log.error('Base 64', 'Error reading file:', err);
      Log.error('Base 64', 'Error reading file:', this.mContext);
      return Promise.reject(err);
    }
  }

  public async convertToBase64() {
    try {
      // // 读取文件内容为 Uint8Array
      // let uint8Array = await this.readFileAsUint8Array();
      //
      // // 创建 Base64Helper 实例
      // const base64 = new util.Base64Helper();
      //
      // // 转换为 Base64 字符串
      // const base64Str = base64.encodeToStringSync(uint8Array, util.Type.MIME);
      // console.info(this.TAG, 'Base 64 Encoded String:', base64Str);
      await this.getPixelMap(); // 确保 PixelMap 创建完成
      await this.pixelToBase64(); // 再进行 Base64 转换
      return this.base64
    } catch (err) {
      Log.error(this.TAG, 'Base 64', 'Error converting to Base64:', err);
      return err as string
    }
  }

  public async getPixelMap(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        // 通过uri打开图片文件，获取文件fd
        let file = fs.openSync(this.uri, fs.OpenMode.READ_WRITE);
        const imageSourceApi = image.createImageSource(file.fd);

        // 将图片解码为pixelmap
        imageSourceApi.createPixelMap({ editable: true }).then(pixelmap => {
          this.profileImage = pixelmap;
          console.log('Succeeded in creating pixelmap object through image decoding parameters.');
          resolve(); // 解码完成后，返回成功
        }).catch((err: BusinessError) => {
          console.error('Failed to create pixelmap object through image decoding parameters.', err);
          reject(err); // 处理错误
        });
      } catch (error) {
        console.error('Error in getPixelMap:', error);
        reject(error);
      }
    });
  }

  // PixelMap to Base 64
  public async pixelToBase64(): Promise<void> {
    try {
      if (!this.profileImage) {
        console.error('PixelMap not initialized.');
        return;
      }

      const imagePackerApi: image.ImagePacker = image.createImagePacker();
      let packOpts: image.PackingOption = { format: 'image/jpeg', quality: 100 };
      const data: ArrayBuffer = await imagePackerApi.packToData(this.profileImage, packOpts);
      let buf: buffer.Buffer = buffer.from(data);
      this.base64 = 'data:image/jpeg;base64,' + buf.toString('base64', 0, buf.length);
      console.log('Base64 Encoded Image:', this.base64);
    } catch (error) {
      console.error('Error in pixelToBase64:', error);
    }
  }

  // Select file

  public selectFile(): Promise<MediaBean> {
    try {
      let documentSelectOptions = new picker.DocumentSelectOptions();
      let documentPicker = new picker.DocumentViewPicker();
      return documentPicker.select(documentSelectOptions)
        .then((documentSelectResult) => {
          Log.info(this.TAG, 'DocumentViewPicker.select successfully, DocumentSelectResult uri: ' + JSON.stringify(documentSelectResult));

          if (documentSelectResult && documentSelectResult.length > 0) {
            let filePath = documentSelectResult[0];
            Log.info(this.TAG, 'DocumentViewPicker.select successfully, DocumentSelectResult uri: ' + filePath);
            return filePath;
          }

        }).catch((err) => {
          Log.error(this.TAG, 'PhotoViewPicker.select failed with err: ' + err);
          return err;
        }).then(async (filePath) => {

          const mediaBean = await this.buildMediaBean(filePath);
          return mediaBean;

        });
    } catch (err) {
      Log.error(this.TAG, 'PhotoViewPicker failed with err: ' + err);
      return Promise.reject(err);
    }
  }

  // Take photo
  public async takePhoto(context: common.UIAbilityContext): Promise<MediaBean> {


    let want = {
      'uri': '',
      'action': 'ohos.want.action.imageCapture',
      'parameters': {},
    };
    return context.startAbilityForResult(want)
      .then((result) => {
        Log.info(this.TAG, `startAbility call back , ${JSON.stringify(result)}`);
        Log.info(this.TAG, `startAbility call back outside ${(result.want.parameters['resourceUri'])} ${StringUtils.isNotNullOrEmpty(result.want.uri)}`);
        let photoUrl: string = (result.want.parameters['resourceUri']).toString()
        if (result.resultCode === 0 && result.want && StringUtils.isNotNullOrEmpty(photoUrl)) {
          //拍照成功
          Log.info(this.TAG, `startAbility call back inside`);
          // Log.info(this.TAG, 'takePhoto successfully, takePhotoResult uri: ' + result.want.uri);
          result.want.uri = photoUrl
          Log.info(this.TAG, 'takePhoto successfully, takePhotoResult uri: ' + result.want.uri);

          // todo: add upload current taken photo image
          // 拍照后调用openSync方法报错

          let filePath = photoUrl

          // get application context path
          let filesDir = this.mContext.filesDir
          let fileName = "userUploadedImages"

          // get filepath in sandbox
          let path = filesDir + "/" + fileName + "." + filePath.split(".")[1] // 提取文件后缀
          Log.info(this.TAG, '沙箱中文件路径(before copy): ', path)
          // let file = fs.openSync(filePath, fs.OpenMode.READ_ONLY) // 系统资源图片
          // let file2 = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE) // 目的地图片
          //
          // // Image copy from imageUri to the sandbox
          // fs.copyFileSync(file.fd, file2.fd)
          // fs.closeSync(file.fd)
          // fs.closeSync(file2.fd)

          // Get image sandbox path corresponding uri
          return result.want.uri;
        }
      }).catch((error) => {
        Log.info(this.TAG, `startAbility error , ${JSON.stringify(error)}`);
        return error;
      }).then(async (uri: string) => {
        const mediaBean = await this.buildMediaBean(uri);
        return mediaBean;
      });
  }


  // encapsulate attached entity class
  // @param uri (file path)
  private async buildMediaBean(uri: string): Promise<MediaBean> {

    if (StringUtils.isNullOrEmpty(uri)) {
      return null;
    }

    const mediaBean: MediaBean = new MediaBean();
    mediaBean.localUrl = uri;
    await this.appendFileInfoToMediaBean(mediaBean, uri);
    return mediaBean;
  }


  /**
   * Through Uri find selected file info, and insert into MediaBean
   * @param mediaBean
   * @param uri
   */
  private async appendFileInfoToMediaBean(mediaBean: MediaBean, uri: string) {

    if (StringUtils.isNullOrEmpty(uri)) {
      return;
    }
    let fileList: Array<photoAccessHelper.PhotoAsset> = [];

    try {

      let media = photoAccessHelper.getPhotoAccessHelper(this.mContext);
      let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
      predicates.equalTo('user_display_level', 2);
      let mediaFetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: [],
        predicates: predicates
        // selections: mediaLibrary.FileKey.ID + '= ?',
        // selectionArgs: [id],
        // uri: uri
      };

      let fetchFileResult = await media.getAssets(mediaFetchOptions);
      Log.info(this.TAG, `fileList getFileAssetsFromType fetchFileResult.count = ${fetchFileResult.getCount()}`);
      fileList = await fetchFileResult.getAllObjects();
      fetchFileResult.close();
      await media.release();

    } catch (e) {
      Log.error(this.TAG, "query: file data  exception ");
    }

    if (fileList && fileList.length > 0) {

      let fileInfoObj = fileList[0];
      // Log.info(this.TAG, `file id = ${JSON.stringify(fileInfoObj.id)} , uri = ${JSON.stringify(fileInfoObj.uri)}`);
      // Log.info(this.TAG, `file fileList displayName = ${fileInfoObj.displayName} ,size = ${fileInfoObj.size} ,mimeType = ${fileInfoObj.mimeType}`);

      mediaBean.fileName = fileInfoObj.displayName;
      // mediaBean.fileSize = fileInfoObj.size;
      mediaBean.fileType = fileInfoObj.photoType.toString()

    }
  }
}