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
    let file = fs.openSync(srcPath, fs.OpenMode.READ_ONLY) // System resource image
    let file2 = fs.openSync(dstPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE) // Destination image
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
            let path = filesDir + "/" + fileName + "." + filePath.split(".")[1] // Extract file extension
            Log.info(this.TAG, 'Sandbox file path (before copy): ', path)
            // let file = fs.openSync(filePath, fs.OpenMode.READ_ONLY) // System resource image
            // let file2 = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE) // Destination image
            // Log.info(this.TAG, 'filePath: ', filePath)
            //
            // // Image copy from imageUri to the sandbox
            // fs.copyFileSync(file.fd, file2.fd)
            // fs.closeSync(file.fd)
            // fs.closeSync(file2.fd)

            // Get image sandbox path corresponding uri
            this.uri = this.urlIntoSandbox(filePath, path)
            Log.info(this.TAG, 'Sandbox file path (after copy): ', this.uri)
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
      // Open file
      // Error here is mostly because the file at the path is in read-only mode, but you wrote it in read-write mode
      const openedFile = fs.openSync(testPath, fs.OpenMode.READ_WRITE)

      // Get file size
      const stats = fs.statSync(testPath)
      // Allocate buffer based on file size
      let buffer: ArrayBuffer = new ArrayBuffer(stats.size)
      Log.info('Base 64', 'opened path:', openedFile.path)
      Log.info('Base 64', 'pathDir:', this.mContext.filesDir)
      Log.info('Base 64', 'File descriptor:', openedFile.fd)

      // todo: Problem location, unable to read file data into buffer

      fs.readSync(openedFile.fd, buffer, { offset: 0, length: stats.size })

      // Log.info('Base 64', 'File allocated buffer after read:', stringUtils.arrayBuffer2String(buffer))

      // convert arrayBuffer flow into Unit8Array flow
      // const uint8Array = new Uint8Array(buffer)

      // Close file
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

  public convertToBase64(): Promise<string> {
    return new Promise((resolve, reject) => {
      try {
        Log.info(this.TAG, '=== convertToBase64 START ===');
        Log.info(this.TAG, 'this.uri:', this.uri);
        
        if (!this.uri || this.uri.length === 0) {
          const msg = 'ERROR: this.uri is not set or empty';
          Log.error(this.TAG, msg);
          reject(new Error(msg));
          return;
        }
        
        // Open image file through uri, get file fd
        let file = fs.openSync(this.uri, fs.OpenMode.READ_WRITE);
        Log.info(this.TAG, 'File opened successfully, fd:', file.fd);
        const imageSourceApi = image.createImageSource(file.fd);
        Log.info(this.TAG, 'ImageSource created');

        // Decode image to pixelmap
        imageSourceApi.createPixelMap({ editable: true }).then((pixelmap: image.PixelMap) => {
          Log.info(this.TAG, '✅ Pixelmap created successfully');
          this.profileImage = pixelmap;
          console.log('Succeeded in creating pixelmap object through image decoding parameters.');

          // Convert pixelmap to base64
          const imagePackerApi: image.ImagePacker = image.createImagePacker();
          let packOpts: image.PackingOption = { format: 'image/jpeg', quality: 100 };

          imagePackerApi.packToData(this.profileImage, packOpts).then((data: ArrayBuffer) => {
            let buf: buffer.Buffer = buffer.from(data);
            this.base64 = 'data:image/jpeg;base64,' + buf.toString('base64', 0, buf.length);
            Log.info(this.TAG, '✅ Base64 conversion complete!');
            Log.info(this.TAG, 'Base64 length:', this.base64.length);
            Log.info(this.TAG, 'Base64 prefix (first 80 chars):', this.base64.substring(0, 80));
            Log.info(this.TAG, '=== convertToBase64 END ===');
            resolve(this.base64);
            fs.closeSync(file.fd);
          }).catch((err: BusinessError) => {
          Log.error(this.TAG, '❌ Failed to pack pixelmap to data:', JSON.stringify(err));
          fs.closeSync(file.fd);
          Log.error(this.TAG, '=== convertToBase64 FAILED ===');
          reject(err);
        });
        }).catch((err: BusinessError) => {
          Log.error(this.TAG, '❌ Failed to create pixelmap:', JSON.stringify(err));
          fs.closeSync(file.fd);
          Log.error(this.TAG, '=== convertToBase64 FAILED ===');
          reject(err);
        });
      } catch (error) {
        Log.error(this.TAG, '❌ Exception in convertToBase64:', JSON.stringify(error));
        Log.error(this.TAG, '=== convertToBase64 FAILED ===');
        reject(error);
      }
    });
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
          // Photo taken successfully
          Log.info(this.TAG, `startAbility call back inside`);
          // Log.info(this.TAG, 'takePhoto successfully, takePhotoResult uri: ' + result.want.uri);
          result.want.uri = photoUrl
          Log.info(this.TAG, 'takePhoto successfully, takePhotoResult uri: ' + result.want.uri);

          // todo: add upload current taken photo image
          // Error calling openSync method after taking photo

          let filePath = photoUrl

          // get application context path
          let filesDir = this.mContext.filesDir
          let fileName = "userUploadedImages"

          // get filepath in sandbox
          let path = filesDir + "/" + fileName + "." + filePath.split(".")[1] // Extract file extension
          Log.info(this.TAG, 'Sandbox file path (before copy): ', path)
          // let file = fs.openSync(filePath, fs.OpenMode.READ_ONLY) // System resource image
          // let file2 = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE) // Destination image
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
    // Ensure this.uri is set to the sandbox path for convertToBase64()
    // Note: if uri is already the sandbox path (from urlIntoSandbox), this.uri should already be set
    // If uri is the original path, we need to use the sandbox path stored in this.uri
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