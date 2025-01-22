import file from '@ohos.file.fs'; //用于读取普通文件
import { MediaHelper } from '../helper/MediaHelper';


class fileUtils {
  private filePath: string = '';
  private mediaHelper: MediaHelper = new MediaHelper(getContext());

  constructor(path: string) {
    this.filePath = path
  }

  async openFile(): Promise<file.File> {
    let res = await file.open(this.filePath, 0o666);
    return res
  }
}