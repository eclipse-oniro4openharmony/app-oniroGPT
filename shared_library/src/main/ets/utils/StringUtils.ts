/**
 * String Utilities for ArkTS
 */
import { util } from "@kit.ArkTS";

class StringUtils {
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

  /**
   * Convert string to Uint8Array
   * @param value
   * @returns
   */
  string2Uint8Array1(value: string): Uint8Array {
    if (!value) {
      return null;
    }
    //
    let textEncoder = new util.TextEncoder();
    // Get the stream and emit UTF-8 byte stream. All TextEncoder instances only support UTF-8 encoding
    return textEncoder.encodeInto(value)
  }

  /**
   * Convert string to Uint8Array
   * @param value Source string containing the text to be encoded
   * @param dest Uint8Array object instance to store the encoding result
   * @returns Returns an object containing two properties: read and written
   */
  string2Uint8Array2(value: string, dest: Uint8Array) {
    if (!value) {
      return null;
    }
    if (!dest) {
      dest = new Uint8Array(value.length);
    }
    let textEncoder = new util.TextEncoder();
    // read: A numeric value specifying the number of string characters converted to UTF-8. This may be less than src.length (length of source string) if uint8Array does not have enough space.
    // dest: Also a numeric value specifying the number of UTF-8 unicode stored in the destination Uint8Array object Array. It is always equal to read.
    textEncoder.encodeIntoUint8Array(value, dest)
    // let result = textEncoder.encodeIntoUint8Array(value, dest)
    // result.read
    // result.written
  }

  /**
   * Convert Uint8Array to String
   * @param input
   */
  uint8Array2String(input: Uint8Array) {
    let textDecoder = util.TextDecoder.create("utf-8", { ignoreBOM: true })
    return textDecoder.decodeToString(input, { stream: false });
  }

  /**
   * Convert ArrayBuffer to String
   * @param input
   * @returns
   */
  arrayBuffer2String(input: ArrayBuffer) {
    return this.uint8Array2String(new Uint8Array(input))
  }
}

export { StringUtils }