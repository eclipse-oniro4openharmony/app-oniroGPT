import { audio } from '@kit.AudioKit';

export class Constants {
  static MIN_DB = -90;
  static VOLUME_MAX = 32768
  static DRAW_LINE_WIDTH = 2;
  static WAVE_HEIGHT_RADIO = 30;
  static WAVE_RECORDING_COUNT = 25;
  static WAVE_TICK_INTERVAL = 50;
  static WAVE_RENDER_COUNT = 100;
  static CHANNEL_NUM = audio.AudioChannel.CHANNEL_1;
  static SAMPLING_RATE = audio.AudioSamplingRate.SAMPLE_RATE_16000;
  static SAMPLE_FORMAT = audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE;
  static SAMPLE_BIT = 16;
  static SAMPLE_BYTE = Constants.SAMPLE_BIT / 8;
  static WAVE_RECORD_INDEX: number[] = new Array(Constants.WAVE_RECORDING_COUNT).fill(0);
  // ---- VAD parameters ----
  static VAD_SPEECH_RMS = 0.025;
  static VAD_SILENCE_MS_AFTER_SPEECH = 1200;
  // Longest recording time
  static MAX_RECORD_MS = 15000;
  // Silence time
  static PRE_SPEECH_TIMEOUT_MS = 5000;

  static SILENCE_AFTER_SPEECH = 'Silence after speech'
  static PRE_SPEECH_TIMEOUT = 'Pre-speech timeout'
  static MAX_DURATION = 'Max duration'
  static MANUAL_STOP = 'Manual stop'
  static LISTENING = 'Listening..'
  static NO_UI = 'No UI context'
  static FAILED_HTTP = 'Failed to fetch data: HTTP Code'
  static GPT_4O_MINI = 'gpt-4o-mini'
  static GPT_4O_MINI_TRANSCRIBE = 'gpt-4o-mini-transcribe'
  static TAP_SPEAK = 'Tap Oniro to speak'
  static NO_SPEAK ='No speech recognized';
  static GET_READY = 'Get ready'
  static BUNDLE_NAME = 'com.huawei.ohos.settings'
  static AbilityName = 'com.huawei.ohos.settings.MainAbility'
  static URI = "application_info_entry"
  static ASSISTANT = 'assistant'
  static PROCESSING = 'Processing...'
  static DONE = 'Done'
  static FAILED = 'Failed'
  static GPT_4O_TRANSCRIBE = 'gpt-4o-transcribe'
}