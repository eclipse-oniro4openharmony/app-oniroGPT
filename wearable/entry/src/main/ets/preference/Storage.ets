import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit'


class Storage {
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  constructor() {
  }

  private async getPreferences() {
    let options: preferences.Options = {
      name: 'myStore'
    }
    let dataPreferences = preferences.getPreferencesSync(this.context, options) as preferences.Preferences
    return dataPreferences
  }

  private async checkPreference(key: string) {
    if ((await this.getPreferences()).hasSync(key)) {
      hilog.info(0x00, 'checkPreferenceResult', `The key ${key} is contained.`)
      return true
    } else {
      hilog.info(0x00, 'checkPreferenceResult', `The key ${key} does not contain.`)
      return false
    }
  }

  public async getValue(key: string) {
    if (await this.checkPreference(key)) {
      let value = (await this.getPreferences()).getSync(key, 'default')
      hilog.info(0x00, 'checkPreferenceResult', `The key ${key} value is ` + value);
      return value as string
    } else {
      hilog.info(0x00, 'checkPreferenceResult', `The key ${key} does not contain.`)
      return null
    }
  }

  public async putValue(key: string, value: string) {
    //Put data
    (await this.getPreferences()).put(key, value, (err: BusinessError) => {
      if (err) {
        hilog.error(0x00, 'checkValueResult', `Failed to put value of ${key}. code =` + err.code + ", message =" + err.message)
        return
      }
      hilog.info(0x00, 'checkValueResult', `Succeeded in putting value of ${key}.`)
    })
  }

  public async setStyle(key: string, value: string[]) {
    ((await this.getPreferences()).put(key, value, (err: BusinessError) => {
      if (err) {
        hilog.error(0x00, 'checkValueResult', `Failed to put value of ${key}. code =` + err.code + ", message =" + err.message)
      return
      }
      hilog.info(0x00, 'checkValueResult', `Succeeded in putting value of ${key}.`)
      this.flushAllData()
    }))
  }

  public async getStyle(key: string) {
    if (await this.checkPreference(key)) {
      let value = (await this.getPreferences()).getSync(key, 'default')
      hilog.info(0x00, 'checkPreferenceResult', `The key ${key} value is ` + value);
      return value as string[]
    } else {
      hilog.info(0x00, 'checkPreferenceResult', `The key ${key} does not contain.`)
      return null
    }
  }

  public async getAllPair() {
    //getAll
    (await this.getPreferences()).getAll((err: BusinessError, value: Object) => {
      if (err) {
        console.error("Failed to get all key-values. code =" + err.code + ", message =" + err.message)
        return
      }
      let allKeys = this.getObjKeys(value)
      console.info("getAll keys = " + allKeys)
      console.info("getAll object = " + JSON.stringify(value))
    })
  }

  public async flushAllData() {
    (await this.getPreferences()).flush((err: BusinessError) => {
      if (err) {
        hilog.error(0x00, 'checkFlushResult', "Failed to flush. code =" + err.code + ", message =" + err.message);
        return;
      }
      hilog.info(0x00, 'checkFlushResult', "Succeeded in flushing.");
    })
  }

  private getObjKeys(obj: Object): string[] {
    let keys = Object.keys(obj)
    return keys
  }
}

export default Storage