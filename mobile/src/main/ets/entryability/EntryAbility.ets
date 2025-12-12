import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import hilog from '@ohos.hilog';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import preferences from '@ohos.data.preferences';
import util from '@ohos.util';
import { Log } from '@ohos/shared_library';

let dataPreferences: preferences.Preferences | null = null;
let Tag: string = 'onWindowStageCreate'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Get Preferences instance.
    let options: preferences.Options = {
      name: 'myStore'
    };
    dataPreferences = preferences.getPreferencesSync(this.context, options);

    if (dataPreferences.hasSync('startup')) {
      Log.info(Tag, "The key 'startup' is contained.");
    } else {
      Log.info(Tag, "The key 'startup' does not contain.");
      // Write data when this key-value pair does not exist
      dataPreferences.putSync('startup', 'auto');
      // When a string has special characters, it needs to be converted to Uint8Array type before storage, with a maximum length of 16 * 1024 * 1024 bytes.
      let uInt8Array1 = new util.TextEncoder().encodeInto("~！@#￥%……&*（）——+？");
      dataPreferences.putSync('uInt8', uInt8Array1);
    }
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err, data) => {
      let keyboardAvoidMode  = windowStage.getMainWindowSync().getUIContext().getKeyboardAvoidMode();
      // Set keyboard avoid mode to compress page size by keyboard height when virtual keyboard is raised
      windowStage.getMainWindowSync().getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
