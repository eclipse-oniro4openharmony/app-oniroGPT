/**
 * String Utilities for ArkTS
 */
export class StringUtils {
  /**
   * Checks if the provided string is null, undefined, or an empty string.
   *
   * @param str - The string to check
   * @returns True if the string is null, undefined, or empty; otherwise, false
   */
  static isNullOrEmpty(str: string | undefined | null): boolean {
    return !str || str.trim().length === 0;
  }

  /**
   * Checks if the provided string is not null, undefined, or empty.
   *
   * @param str - The string to check
   * @returns True if the string is not null, undefined, or empty; otherwise, false
   */
  static isNotNullOrEmpty(str: string | undefined | null): boolean {
    return !!str && str.trim().length > 0;
  }
}
