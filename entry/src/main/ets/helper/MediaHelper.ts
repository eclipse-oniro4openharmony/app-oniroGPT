import common from '@ohos.app.ability.common';
import { MediaBean } from '../bean/MediaBean';
import { Log } from '../utils/Log';
import picker from '@ohos.file.picker';
import wantConstant from '@ohos.ability.wantConstant';
import { StringUtils } from '../utils/StringUtils';
import mediaLibrary from '@ohos.multimedia.mediaLibrary';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import dataSharePredicates from '@ohos.data.dataSharePredicates';

export class MediaHelper {
  private readonly TAG: string = 'MediaHelper';

  private mContext: common.Context;

  constructor(context: common.Context) {
    this.mContext = context;
  }

 // Select Image

  public selectPicture(): Promise<MediaBean> {

    try {
      let photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      let photoPicker = new picker.PhotoViewPicker();
      return photoPicker.select(photoSelectOptions)
        .then((photoSelectResult) => {
          Log.info(this.TAG, 'PhotoViewPicker.select successfully, PhotoSelectResult uri: ' + JSON.stringify(photoSelectResult));

          if (photoSelectResult && photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
            let filePath = photoSelectResult.photoUris[0];
            Log.info(this.TAG, 'PhotoViewPicker.select successfully, PhotoSelectResult uri: ' + filePath);
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
        if (result.resultCode === 0 && result.want && StringUtils.isNotNullOrEmpty(result.want.uri)) {
          //拍照成功
          Log.info(this.TAG, 'takePhoto successfully, takePhotoResult uri: ' + result.want.uri);
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

    const parts: string[] = uri.split('/');
    const id: string = parts.length > 0 ? parts[parts.length - 1] : '-1';

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
