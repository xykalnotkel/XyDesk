import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Signing rilis: baca key.properties bila ada (CI menyediakannya) ──
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.xystudio.xydesk"
    // flutter_secure_storage 11 membutuhkan Android API 37 saat compile.
    // Ini tidak mengubah minSdk; perangkat Android 8.0+ tetap didukung.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.xystudio.xydesk"
        // Android 8.0 — sesuai PERMISSIONS.md; di bawah ini MediaCodec
        // low-latency tidak tersedia.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Kunci ABI di level Gradle, BUKAN hanya lewat --target-platform.
        //
        // Alasannya: --target-platform hanya mengontrol library milik Flutter
        // (libflutter.so dan libapp.so). Library native milik PLUGIN diambil
        // apa adanya dari AAR masing-masing, sehingga arsitektur yang tidak
        // diminta tetap ikut terbungkus. Pada build 510d231 hal ini
        // menyelundupkan lib/x86_64/libjingle_peerconnection_so.so sebesar
        // 15.3 MB dari flutter_webrtc, padahal x86_64 tidak pernah diminta.
        // Akibatnya APK jadi 72.8 MB dan 79 MB setelah dipasang.
        //
        // ndk.abiFilters berlaku pada SEMUA sumber .so, termasuk plugin, jadi
        // inilah gerbang yang benar.
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Pakai signing rilis bila key.properties ada; selain itu fallback
            // ke debug agar `flutter run --release` tetap jalan lokal.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Minify wajib untuk rilis. Selain memangkas ukuran, obfuscation
            // menyembunyikan alur verifikasi update di MainActivity
            // (verifyApk, sha256, pemeriksaan sertifikat penanda tangan).
            // Tanpa ini, siapa pun bisa membongkar APK dengan jadx dan
            // membaca persis bagaimana update divalidasi untuk mencari
            // celahnya.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // Buang duplikat metadata dari dependensi Kotlin/Play Services yang tidak
    // dibutuhkan saat runtime.
    packaging {
        // abiFilters ditimpa oleh integrasi Flutter saat varian dirakit. Build
        // run #32034879381 membuktikan x86_64 dari AAR flutter_webrtc masih
        // lolos. Exclude packaging bekerja pada input JNI final, sehingga ini
        // menjadi gerbang deterministik terakhir sebelum APK ditulis.
        jniLibs {
            excludes += setOf(
                "**/x86/**",
                "**/x86_64/**",
                "**/armeabi/**",
                "**/mips/**",
            )
        }
        resources {
            excludes += setOf(
                "META-INF/*.version",
                "META-INF/proguard/**",
                "META-INF/com/android/build/gradle/*",
                "**/*.proto",
                "DebugProbesKt.bin",
                "kotlin-tooling-metadata.json",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
