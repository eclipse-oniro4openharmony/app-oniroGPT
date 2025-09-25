import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';
import { Constants } from '../common/Constants';

const DOMAIN = 0x0000;
const TAG = 'AudioCapturer';

interface GeneratedObjectLiteralInterface_1 {
  samplingRate: audio.AudioSamplingRate;
  channels: audio.AudioChannel;
  sampleFormat: audio.AudioSampleFormat;
  encodingType: audio.AudioEncodingType;
}

interface GeneratedObjectLiteralInterface_2 {
  source: audio.SourceType;
  capturerFlags: number;
}

interface GeneratedObjectLiteralInterface_3 {
  streamInfo: GeneratedObjectLiteralInterface_1;
  capturerInfo: GeneratedObjectLiteralInterface_2;
}

export class AudioCapturer {
  private sampleValCnt: number = 0;
  private sampleValSum: number = 0;
  private savedDbs: number[] = [];
  private audioCapturer?: audio.AudioCapturer;
  private fd?: number;
  private pcmPath: string = '';
  private uiCtx?: UIContext;
  private externalDataCallback?: (data: ArrayBuffer) => void;
  private audioStreamInfo: GeneratedObjectLiteralInterface_1 = {
    samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
    channels: audio.AudioChannel.CHANNEL_1,
    sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
    encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW,
  };
  private audioCapturerInfo: GeneratedObjectLiteralInterface_2 = {
    source: audio.SourceType.SOURCE_TYPE_MIC,
    capturerFlags: 0,
  };
  private audioCapturerOptions: GeneratedObjectLiteralInterface_3 = {
    streamInfo: this.audioStreamInfo,
    capturerInfo: this.audioCapturerInfo,
  };

  getSavedDbData(): number[] {
    return this.savedDbs;
  }

  calculateDecibelHeight(): number {
    if (this.sampleValCnt === 0) {
      return 0;
    }
    const rms = this.sampleValSum / this.sampleValCnt;
    const db = Math.max(Constants.MIN_DB, Math.min(0, 20 * Math.log10(rms)));
    this.sampleValCnt = 0;
    this.sampleValSum = 0;
    const res =
      Math.max(2, (db + Math.abs(Constants.MIN_DB)) / Math.abs(Constants.MIN_DB) * Constants.WAVE_HEIGHT_RADIO);
    this.savedDbs.push(res);
    return res;
  }

  public setDataCallback(cb: (data: ArrayBuffer) => void): void {
    this.externalDataCallback = cb;
  }

  public clearDataCallback(): void {
    this.externalDataCallback = undefined;
  }

  async createOn(filename: string, context: UIContext) {
    this.uiCtx = context;
    audio.createAudioCapturer(this.audioCapturerOptions, async (err, data) => {
      if (err) {
        hilog.error(DOMAIN, TAG, `createAudioCapturer failed: code=${err.code}, msg=${err.message}`);
        return;
      }
      this.audioCapturer = data;
      this.savedDbs = [];

      const host = context.getHostContext() as Context;
      const dir = host.cacheDir;
      const filePath = `${dir}/${filename}.pcm`;
      const file =
        await fileIo.open(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      this.fd = file.fd;
      this.pcmPath = filePath;

      let written: number = 0;
      const readDataCallback = async (buffer: ArrayBuffer) => {
        const len = buffer.byteLength;
        await fileIo.write(file.fd, buffer, { offset: written, length: len });
        written += len;
        AppStorage.setOrCreate('RecordOffset', written);

        const samples = new Int16Array(buffer);
        for (let i = 0; i < samples.length; i++) {
          const val = samples[i] / Constants.VOLUME_MAX;
          this.sampleValSum += val * val;
          this.sampleValCnt += 1;
        }

        if (this.externalDataCallback) {
          try {
            this.externalDataCallback(buffer);
          } catch (_) {
          }
        }
      };

      this.audioCapturer.on('readData', readDataCallback);
      this.audioCapturer.on('stateChange', (state: audio.AudioState) => {
        if (state === audio.AudioState.STATE_RELEASED) {
          if (this.fd !== undefined) {
            fileIo.close(this.fd).catch(() => {
            });
            this.fd = undefined;
          }
        }
      });

      try {
        await this.audioCapturer.start();
        hilog.info(DOMAIN, TAG, `recording started, PCM -> ${this.pcmPath}`);
      } catch (e) {
        const be = e as BusinessError;
        hilog.error(DOMAIN, TAG, `start failed code=${be.code} msg=${be.message}`);
      }
    });
  }

  async stopAndRelease(outBaseName?: string): Promise<void> {
    if (this.audioCapturer) {
      try {
        await this.audioCapturer.stop();
      } catch {
      }
      try {
        await this.audioCapturer.release();
      } catch {
      }
    }
    if (this.fd !== undefined) {
      try {
        await fileIo.close(this.fd);
      } catch {
      }
      this.fd = undefined;
    }

    const ctx: UIContext | undefined = this.uiCtx;
    if (!ctx || !this.pcmPath) {
      hilog.warn(DOMAIN, TAG, 'skip WAV mux: no context or pcmPath');
      return;
    }

    try {
      const host: Context = ctx.getHostContext() as Context;
      const dir: string = host.cacheDir;
      const pcmBaseName: string = this.pcmPath.substring(this.pcmPath.lastIndexOf('/') + 1).replace(/\.pcm$/i, '');
      const base: string = (outBaseName && outBaseName.length > 0) ? outBaseName : pcmBaseName;
      const wavPath: string = `${dir}/${base}.wav`;

      const stat: fileIo.Stat = await fileIo.stat(this.pcmPath);
      const audioDataSize: number = stat.size;

      const bitsPerSample: number = 16;
      const channels: number = this.channelsToNumber(this.audioStreamInfo.channels); // 2
      const sampleRate: number = this.samplingRateToNumber(this.audioStreamInfo.samplingRate); // 44100
      const byteRate: number = sampleRate * channels * (bitsPerSample / 8);
      const blockAlign: number = channels * bitsPerSample / 8;

      const inFile: fileIo.File = await fileIo.open(this.pcmPath, fileIo.OpenMode.READ_ONLY);
      const outFile: fileIo.File = await fileIo.open(
        wavPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      );

      await this.writeWaveFileHeader(outFile.fd, audioDataSize, sampleRate, channels, bitsPerSample);
      await this.appendPcmDataToWav(inFile.fd, outFile.fd, audioDataSize);

      await fileIo.close(inFile.fd);
      await fileIo.close(outFile.fd);

      try {
        await fileIo.unlink(this.pcmPath);
      } catch {
      }
      this.pcmPath = '';

      hilog.info(DOMAIN, TAG,
        `WAV header -> sr=${sampleRate}, ch=${channels}, bits=${bitsPerSample}, data=${audioDataSize}, byteRate=${byteRate}, blockAlign=${blockAlign}`);
      hilog.info(DOMAIN, TAG, `WAV generated -> ${wavPath}`);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `mux WAV failed: ${(e as Error).message}`);
    }
  }

  private channelsToNumber(ch: audio.AudioChannel): number {
    return ch === audio.AudioChannel.CHANNEL_2 ? 2 : 1;
  }

  private samplingRateToNumber(rate: audio.AudioSamplingRate): number {
    switch (rate) {
      case audio.AudioSamplingRate.SAMPLE_RATE_8000:
        return 8000;
      case audio.AudioSamplingRate.SAMPLE_RATE_11025:
        return 11025;
      case audio.AudioSamplingRate.SAMPLE_RATE_12000:
        return 12000;
      case audio.AudioSamplingRate.SAMPLE_RATE_16000:
        return 16000;
      case audio.AudioSamplingRate.SAMPLE_RATE_22050:
        return 22050;
      case audio.AudioSamplingRate.SAMPLE_RATE_24000:
        return 24000;
      case audio.AudioSamplingRate.SAMPLE_RATE_32000:
        return 32000;
      case audio.AudioSamplingRate.SAMPLE_RATE_44100:
        return 44100;
      case audio.AudioSamplingRate.SAMPLE_RATE_48000:
        return 48000;
      default:
        return 44100;
    }
  }

  private writeString(view: DataView, offset: number, str: string): void {
    for (let i = 0; i < str.length; i++) {
      view.setUint8(offset + i, str.charCodeAt(i));
    }
  }

  private async writeWaveFileHeader(outFd: number, audioDataSize: number, sampleRate: number,
    channels: number, bitsPerSample: number): Promise<void> {
    const byteRate: number = sampleRate * channels * (bitsPerSample / 8);
    const blockAlign: number = channels * bitsPerSample / 8;
    const totalDataLen: number = audioDataSize + 36; // ChunkSize = 36 + Subchunk2Size

    const header: ArrayBuffer = new ArrayBuffer(44);
    const dv: DataView = new DataView(header);

    // RIFF chunk
    this.writeString(dv, 0, 'RIFF');
    dv.setUint32(4, totalDataLen, true); // ChunkSize = fileSize - 8
    this.writeString(dv, 8, 'WAVE');

    // fmt chunk
    this.writeString(dv, 12, 'fmt ');
    dv.setUint32(16, 16, true); // Subchunk1Size
    dv.setUint16(20, 1, true); // PCM
    dv.setUint16(22, channels, true); // NumChannels
    dv.setUint32(24, sampleRate, true); // SampleRate
    dv.setUint32(28, byteRate, true); // ByteRate
    dv.setUint16(32, blockAlign, true); // BlockAlign
    dv.setUint16(34, bitsPerSample, true); // BitsPerSample

    // data chunk
    this.writeString(dv, 36, 'data');
    dv.setUint32(40, audioDataSize, true); // Subchunk2Size

    await fileIo.write(outFd, header, { offset: 0, length: 44 });
  }

  private async appendPcmDataToWav(inFd: number, outFd: number, dataSize: number): Promise<void> {
    const CHUNK: number = 64 * 1024;
    let copied: number = 0;
    while (copied < dataSize) {
      const remain: number = dataSize - copied;
      const len: number = Math.min(CHUNK, remain);
      const buf: ArrayBuffer = new ArrayBuffer(len);
      const read: number = await fileIo.read(inFd, buf, { offset: copied, length: len });
      if (read <= 0) {
        break;
      }
      await fileIo.write(outFd, buf, { offset: 44 + copied, length: read });
      copied += read;
    }
  }
}
