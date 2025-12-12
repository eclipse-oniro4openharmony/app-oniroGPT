import { abilityAccessCtrl, bundleManager, Permissions } from "@kit.AbilityKit";

class PermissionHandler {

  private atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();

  checkPermissions(permissions: Permissions[]) {
    const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    const tokenId = bundleInfo.appInfo.accessTokenId;
    const grantStatus = permissions.map(item => this.atManager.checkAccessTokenSync(tokenId, item));
    return grantStatus.every(item => item === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED);
  }

  async requestPermissions(permissions: Permissions[]) {
    const requestRes = await this.atManager.requestPermissionsFromUser(getContext(), permissions);
    const isAuth = requestRes.authResults.every(item => item === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED);
    return isAuth === true ? Promise.resolve(true) : Promise.reject(false);
  }
}

export const permissionHandler = new PermissionHandler();