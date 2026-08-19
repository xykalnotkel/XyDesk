export interface DeviceRecommendation {
  file: string | null;
  label: string;
  platform: 'android' | 'windows' | 'web';
  architecture: 'arm64' | 'armv7' | 'x64' | 'web';
  confidence: 'high' | 'fallback';
}

interface NavigatorUAData {
  platform?: string;
  architecture?: string;
  bitness?: string;
  getHighEntropyValues?: (
    hints: string[],
  ) => Promise<{
    platform?: string;
    architecture?: string;
    bitness?: string;
    model?: string;
  }>;
}

const ANDROID_ARM64 = 'XyDesk-Android-arm64-v8a.apk';
const ANDROID_ARMV7 = 'XyDesk-Android-armeabi-v7a.apk';
const WINDOWS_X64 = 'XyDesk-Windows-x64-Setup.exe';
const WINDOWS_ARM64 = 'XyDesk-Windows-arm64-Setup.exe';

function fallback(): DeviceRecommendation {
  const override = localStorage.getItem('xydesk.download.arch');
  if (override === 'android-armv7') {
    return {
      file: ANDROID_ARMV7,
      label: 'Android 32-bit',
      platform: 'android',
      architecture: 'armv7',
      confidence: 'high',
    };
  }
  if (override === 'android-arm64') {
    return {
      file: ANDROID_ARM64,
      label: 'Android ARM64',
      platform: 'android',
      architecture: 'arm64',
      confidence: 'high',
    };
  }
  const ua = navigator.userAgent.toLowerCase();
  if (/iphone|ipad|ipod/.test(ua)) {
    return {
      file: null,
      label: 'iPhone atau iPad',
      platform: 'web',
      architecture: 'web',
      confidence: 'high',
    };
  }
  if (ua.includes('android')) {
    const explicit32 = /armv7|armeabi|; 32-bit/.test(ua);
    // Penanda 64-bit eksplisit di UA = kepastian, bukan tebakan.
    const explicit64 = /aarch64|arm64|arm_64|armv8/.test(ua);
    return {
      file: explicit32 ? ANDROID_ARMV7 : ANDROID_ARM64,
      label: explicit32 ? 'Android 32-bit' : 'Android ARM64',
      platform: 'android',
      architecture: explicit32 ? 'armv7' : 'arm64',
      confidence: explicit32 || explicit64 ? 'high' : 'fallback',
    };
  }
  if (ua.includes('windows')) {
    const arm = /windows.*arm|arm64|aarch64/.test(ua);
    return {
      file: arm ? WINDOWS_ARM64 : WINDOWS_X64,
      label: arm ? 'Windows Arm64' : 'Windows x64',
      platform: 'windows',
      architecture: arm ? 'arm64' : 'x64',
      confidence: arm ? 'high' : 'fallback',
    };
  }
  return {
    file: null,
    label: 'browser',
    platform: 'web',
    architecture: 'web',
    confidence: 'fallback',
  };
}

export async function detectDevicePackage(): Promise<DeviceRecommendation> {
  const basic = fallback();
  if (localStorage.getItem('xydesk.download.arch')) return basic;
  const nav = navigator as Navigator & { userAgentData?: NavigatorUAData };
  const uaData = nav.userAgentData;
  if (!uaData?.getHighEntropyValues) {
    // Tanpa Client Hints (Firefox/Safari): coba validasi silang ringan.
    // RAM <= 2 GB pada Android tua sering berarti perangkat 32-bit; kalau
    // sinyal ini muncul sementara UA tidak menyebut arsitektur, turunkan
    // kepercayaan agar UI menawarkan pilihan manual dengan jelas.
    const mem = (navigator as Navigator & { deviceMemory?: number }).deviceMemory;
    if (
      basic.platform === 'android' &&
      basic.confidence === 'fallback' &&
      typeof mem === 'number' &&
      mem <= 2
    ) {
      return { ...basic, label: `${basic.label} (perkiraan)`, confidence: 'fallback' };
    }
    return basic;
  }

  try {
    const high = await uaData.getHighEntropyValues([
      'architecture',
      'bitness',
      'model',
      'platform',
    ]);
    const platform = (high.platform || uaData.platform || '').toLowerCase();
    const architecture = (high.architecture || '').toLowerCase();
    const bitness = high.bitness || '';

    if (platform.includes('android')) {
      const is32 = bitness === '32' || architecture === 'arm';
      return {
        file: is32 ? ANDROID_ARMV7 : ANDROID_ARM64,
        label: is32 ? 'Android 32-bit' : 'Android ARM64',
        platform: 'android',
        architecture: is32 ? 'armv7' : 'arm64',
        confidence: bitness || architecture ? 'high' : 'fallback',
      };
    }
    if (platform.includes('windows')) {
      const arm = architecture.includes('arm');
      return {
        file: arm ? WINDOWS_ARM64 : WINDOWS_X64,
        label: arm ? 'Windows Arm64' : 'Windows x64',
        platform: 'windows',
        architecture: arm ? 'arm64' : 'x64',
        confidence: architecture ? 'high' : 'fallback',
      };
    }
  } catch {
    // Privacy mode dapat menolak high-entropy hints; fallback tetap aman.
  }
  return basic;
}

export function initialDevicePackage(): DeviceRecommendation {
  return fallback();
}
