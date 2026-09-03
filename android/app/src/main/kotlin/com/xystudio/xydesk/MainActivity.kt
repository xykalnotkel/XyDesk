package com.xystudio.xydesk

import android.app.DownloadManager
import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Rational
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.zip.ZipFile

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.xystudio.xydesk/update"
        private const val DISPLAY_CHANNEL = "com.xystudio.xydesk/display"
        private const val PIP_CHANNEL = "com.xystudio.xydesk/pip"
        private const val PREFS = "xydesk_update"
        private const val KEY_DOWNLOAD_ID = "download_id"
        private const val KEY_SHA256 = "sha256"
        private const val KEY_BYTES = "bytes"
        private const val KEY_VERSION = "version"
        private const val KEY_BUILD = "build"
        private const val KEY_VERIFIED = "verified"
        private const val KEY_FAILURE = "failure"
        private const val REPOSITORY_PATH = "/xykalnotkel/XyDesk/releases/download/"
        private const val APK_PACKAGE = "com.xystudio.xydesk"
    }

    private val updateExecutor = Executors.newSingleThreadExecutor()
    private var isInPipMode = false
    private var pipChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::handleUpdateCall)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISPLAY_CHANNEL)
            .setMethodCallHandler(::handleDisplayCall)
        
        // PiP channel for floating window during active sessions
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipChannel?.setMethodCallHandler(::handlePipCall)
    }

    // ── Tampilan: refresh rate & layar tetap menyala ─────────────────────
    //
    // Sebelumnya sisi Dart memanggil metode `setHighRefreshRate` pada channel
    // `flutter/platform_views`. Metode itu tidak pernah ada di Flutter; hasilnya
    // panggilan gagal diam-diam dan sakelar "Refresh rate tinggi" di Pengaturan
    // tidak melakukan apa pun. Implementasi nyatanya ada di sini.
    private fun handleDisplayCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDisplayInfo" -> result.success(displayInfo())
            "setHighRefreshRate" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                applyRefreshRate(enabled)
                result.success(displayInfo())
            }
            "setKeepScreenOn" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                runOnUiThread {
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                }
                result.success(enabled)
            }
            else -> result.notImplemented()
        }
    }

    // ── Picture-in-Picture: floating window saat sesi aktif ──────────────
    //
    // Saat app di-minimize dan sesi remote desktop masih berjalan, masuk
    // PiP mode agar video stream tetap terlihat di jendela kecil mengambang.
    private fun handlePipCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "enterPipMode" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    enterPipMode()
                    result.success(true)
                } else {
                    result.error("UNAVAILABLE", "PiP not available on this Android version", null)
                }
            }
            "exitPipMode" -> {
                // Android doesn't have explicit exit PiP, user needs to expand/close manually
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun enterPipMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            
            enterPictureInPictureMode(params)
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode)
        isInPipMode = isInPictureInPictureMode
        
        // Notify Flutter about PiP mode change
        pipChannel?.invokeMethod("onPipModeChanged", isInPipMode)
    }

    /// Mode tampilan dengan resolusi sama seperti mode aktif, diurutkan
    /// berdasarkan refresh rate. Resolusi sengaja tidak diubah — mengganti
    /// resolusi panel demi Hz akan membuat UI berubah ukuran mendadak.
    private fun candidateModes(): List<android.view.Display.Mode> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return emptyList()
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        } ?: return emptyList()
        val active = display.mode ?: return emptyList()
        return display.supportedModes
            .filter {
                it.physicalWidth == active.physicalWidth &&
                    it.physicalHeight == active.physicalHeight
            }
            .sortedBy { it.refreshRate }
    }

    private fun applyRefreshRate(highest: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val modes = candidateModes()
        if (modes.isEmpty()) return
        val target = if (highest) modes.last() else modes.first()
        runOnUiThread {
            val attributes = window.attributes
            attributes.preferredDisplayModeId = target.modeId
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                attributes.preferredRefreshRate = target.refreshRate
            }
            window.attributes = attributes
        }
    }

    private fun displayInfo(): Map<String, Any> {
        val modes = candidateModes()
        val current = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val d = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            }
            d?.mode?.refreshRate?.toDouble() ?: 60.0
        } else {
            60.0
        }
        return mapOf(
            "current" to current,
            // Bila perangkat hanya punya satu mode, daftar ini berisi satu
            // angka — dan UI wajib mengatakan "tidak didukung", bukan
            // menampilkan sakelar yang tidak mengubah apa pun.
            "supported" to modes.map { it.refreshRate.toDouble() }.distinct(),
        )
    }

    override fun onDestroy() {
        updateExecutor.shutdown()
        super.onDestroy()
    }

    private fun handleUpdateCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPrimaryAbi" -> result.success(Build.SUPPORTED_ABIS.firstOrNull().orEmpty())
            "getStatus" -> runUpdateTask(result) { resolveStatus() }
            "startDownload" -> runUpdateTask(result) { startDownload(call) }
            "installDownloadedUpdate" -> prepareInstallation(result)
            "openInstallPermissionSettings" -> openInstallPermissionSettings(result)
            else -> result.notImplemented()
        }
    }

    private fun runUpdateTask(
        result: MethodChannel.Result,
        task: () -> Map<String, Any>,
    ) {
        updateExecutor.execute {
            try {
                val value = task()
                runOnUiThread { result.success(value) }
            } catch (failure: UpdateFailure) {
                runOnUiThread { result.error(failure.code, failure.message, null) }
            } catch (_: Exception) {
                runOnUiThread {
                    result.error(
                        "UPDATE_FAILED",
                        "Proses update Android tidak dapat diselesaikan.",
                        null,
                    )
                }
            }
        }
    }

    private fun startDownload(call: MethodCall): Map<String, Any> {
        val url = call.argument<String>("url")
            ?: throw UpdateFailure("INVALID_METADATA", "Alamat APK tidak tersedia.")
        val sha256 = call.argument<String>("sha256")?.lowercase()
            ?: throw UpdateFailure("INVALID_METADATA", "Checksum APK tidak tersedia.")
        val bytes = call.argument<Number>("bytes")?.toLong() ?: 0L
        val version = call.argument<String>("version").orEmpty()
        val build = call.argument<Number>("build")?.toLong() ?: 0L

        validateDownloadMetadata(url, sha256, bytes, version, build)
        if (build <= installedVersionCode()) {
            throw UpdateFailure(
                "NO_NEWER_BUILD",
                "Build yang terpasang sudah sama atau lebih baru.",
            )
        }

        clearPreviousDownload()
        val destination = downloadFile(build)
        destination.parentFile?.mkdirs()
        destination.delete()
        verifiedFile(build).delete()

        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle("Pembaruan XyDesk $version")
            .setDescription("Mengunduh APK resmi terverifikasi")
            .setMimeType("application/octet-stream")
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)
            .setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
            )
            .setDestinationInExternalFilesDir(
                this,
                Environment.DIRECTORY_DOWNLOADS,
                "updates/${destination.name}",
            )

        val downloadId = downloadManager().enqueue(request)
        preferences().edit()
            .putLong(KEY_DOWNLOAD_ID, downloadId)
            .putString(KEY_SHA256, sha256)
            .putLong(KEY_BYTES, bytes)
            .putString(KEY_VERSION, version)
            .putLong(KEY_BUILD, build)
            .putBoolean(KEY_VERIFIED, false)
            .remove(KEY_FAILURE)
            .apply()
        return statusMap("queued", 0L, bytes, "Download dimasukkan ke antrean Android.")
    }

    private fun resolveStatus(forceVerification: Boolean = false): Map<String, Any> {
        val prefs = preferences()
        val downloadId = prefs.getLong(KEY_DOWNLOAD_ID, -1L)
        val expectedBytes = prefs.getLong(KEY_BYTES, 0L)
        val build = prefs.getLong(KEY_BUILD, 0L)
        val expectedSha = prefs.getString(KEY_SHA256, null)
        val verified = prefs.getBoolean(KEY_VERIFIED, false)
        val savedFailure = prefs.getString(KEY_FAILURE, null)

        if (downloadId < 0L || build <= 0L || expectedSha == null) {
            return if (savedFailure == null) {
                statusMap("idle", 0L, 0L, "Belum ada download update.")
            } else {
                statusMap("failed", 0L, expectedBytes, savedFailure)
            }
        }

        if (build <= installedVersionCode()) {
            clearPreviousDownload()
            return statusMap(
                "idle",
                expectedBytes,
                expectedBytes,
                "Anda sudah memakai versi terbaru.",
            )
        }

        val readyFile = verifiedFile(build)
        if (readyFile.isFile) {
            if (readyFile.length() != expectedBytes) {
                return failDownload(
                    "Ukuran APK berubah setelah download. File dibuang demi keamanan.",
                    build,
                )
            }
            if (!verified || forceVerification) {
                try {
                    verifyApk(readyFile, expectedSha, expectedBytes, build)
                    prefs.edit().putBoolean(KEY_VERIFIED, true).apply()
                } catch (failure: UpdateFailure) {
                    return failDownload(failure.message, build)
                }
            }
            return statusMap(
                "ready",
                readyFile.length(),
                expectedBytes,
                "APK resmi telah diverifikasi dan siap dipasang.",
            )
        }

        val query = DownloadManager.Query().setFilterById(downloadId)
        downloadManager().query(query).use { cursor ->
            if (!cursor.moveToFirst()) {
                return failDownload("Data download Android tidak ditemukan.", build)
            }
            val status = cursor.getInt(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS),
            )
            val downloaded = cursor.getLong(
                cursor.getColumnIndexOrThrow(
                    DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR,
                ),
            )
            val total = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
            ).takeIf { it > 0L } ?: expectedBytes

            return when (status) {
                DownloadManager.STATUS_PENDING -> statusMap(
                    "queued",
                    downloaded,
                    total,
                    "Menunggu antrean download Android.",
                )

                DownloadManager.STATUS_RUNNING -> statusMap(
                    "running",
                    downloaded,
                    total,
                    "Download berjalan di latar belakang.",
                )

                DownloadManager.STATUS_PAUSED -> statusMap(
                    "paused",
                    downloaded,
                    total,
                    pausedMessage(
                        cursor.getInt(
                            cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON),
                        ),
                    ),
                )

                DownloadManager.STATUS_SUCCESSFUL -> {
                    val temporaryFile = downloadFile(build)
                    val target = verifiedFile(build)
                    try {
                        // File DownloadManager tetap berekstensi .download dan
                        // bertipe octet-stream. Karena itu notifikasi selesai
                        // tidak dapat melewati gerbang verifikasi aplikasi.
                        target.delete()
                        if (!temporaryFile.renameTo(target)) {
                            throw UpdateFailure(
                                "VERIFY_MOVE_FAILED",
                                "APK tidak dapat disiapkan untuk verifikasi.",
                            )
                        }
                        verifyApk(target, expectedSha, expectedBytes, build)
                        preferences().edit()
                            .putBoolean(KEY_VERIFIED, true)
                            .remove(KEY_FAILURE)
                            .apply()
                        statusMap(
                            "ready",
                            target.length(),
                            expectedBytes,
                            "APK resmi telah diverifikasi dan siap dipasang.",
                        )
                    } catch (failure: UpdateFailure) {
                        failDownload(failure.message, build)
                    }
                }

                DownloadManager.STATUS_FAILED -> failDownload(
                    failedMessage(
                        cursor.getInt(
                            cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON),
                        ),
                    ),
                    build,
                )

                else -> failDownload("Status download Android tidak dikenal.", build)
            }
        }
    }

    private fun prepareInstallation(result: MethodChannel.Result) {
        updateExecutor.execute {
            try {
                val status = resolveStatus(forceVerification = true)
                if (status["phase"] != "ready") {
                    throw UpdateFailure(
                        "APK_NOT_READY",
                        status["message"] as? String
                            ?: "APK belum siap untuk dipasang.",
                    )
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    !packageManager.canRequestPackageInstalls()
                ) {
                    throw UpdateFailure(
                        "INSTALL_PERMISSION_REQUIRED",
                        "Izinkan XyDesk memasang aplikasi dari sumber ini terlebih dahulu.",
                    )
                }
                val file = verifiedFile(preferences().getLong(KEY_BUILD, 0L))
                runOnUiThread {
                    try {
                        openPackageInstaller(file)
                        result.success(status)
                    } catch (_: Exception) {
                        result.error(
                            "INSTALLER_UNAVAILABLE",
                            "Installer Android tidak dapat dibuka.",
                            null,
                        )
                    }
                }
            } catch (failure: UpdateFailure) {
                runOnUiThread { result.error(failure.code, failure.message, null) }
            } catch (_: Exception) {
                runOnUiThread {
                    result.error(
                        "UPDATE_FAILED",
                        "APK tidak dapat disiapkan untuk pemasangan.",
                        null,
                    )
                }
            }
        }
    }

    private fun openPackageInstaller(file: File) {
        if (!file.isFile) {
            throw UpdateFailure("APK_NOT_READY", "APK terverifikasi tidak ditemukan.")
        }
        val contentUri = FileProvider.getUriForFile(
            this,
            "$packageName.updateprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(contentUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun openInstallPermissionSettings(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(null)
            return
        }
        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
            result.success(null)
        } catch (_: Exception) {
            result.error(
                "SETTINGS_UNAVAILABLE",
                "Pengaturan izin pemasangan tidak dapat dibuka.",
                null,
            )
        }
    }

    private fun validateDownloadMetadata(
        url: String,
        sha256: String,
        bytes: Long,
        version: String,
        build: Long,
    ) {
        val uri = Uri.parse(url)
        val abi = Build.SUPPORTED_ABIS.firstOrNull().orEmpty()
        if (abi != "arm64-v8a" && abi != "armeabi-v7a") {
            throw UpdateFailure(
                "UNSUPPORTED_ABI",
                "Arsitektur Android tidak didukung paket update resmi.",
            )
        }
        val expectedPath = "${REPOSITORY_PATH}v$version/XyDesk-Android-$abi.apk"
        val validUrl = uri.scheme == "https" &&
            uri.host == "github.com" &&
            uri.path == expectedPath &&
            uri.query == null &&
            uri.fragment == null
        if (!validUrl || !Regex("^[a-f0-9]{64}$").matches(sha256)) {
            throw UpdateFailure(
                "UNTRUSTED_METADATA",
                "Metadata download bukan berasal dari Release resmi XyDesk.",
            )
        }
        if (!Regex("^\\d+\\.\\d+\\.\\d+$").matches(version) ||
            bytes <= 0L ||
            build <= 0L
        ) {
            throw UpdateFailure("INVALID_METADATA", "Metadata APK tidak valid.")
        }
    }

    private fun verifyApk(
        file: File,
        expectedSha: String,
        expectedBytes: Long,
        expectedBuild: Long,
    ) {
        if (!file.isFile || file.length() != expectedBytes) {
            throw UpdateFailure(
                "SIZE_MISMATCH",
                "Ukuran APK tidak cocok dengan metadata Release resmi.",
            )
        }
        if (sha256(file) != expectedSha) {
            throw UpdateFailure(
                "CHECKSUM_MISMATCH",
                "Checksum APK tidak cocok. File dibuang demi keamanan.",
            )
        }
        verifyApkAbi(file)

        val archive = archivePackageInfo(file)
            ?: throw UpdateFailure("INVALID_APK", "Android tidak mengenali file sebagai APK.")
        if (archive.packageName != APK_PACKAGE || archive.packageName != packageName) {
            throw UpdateFailure(
                "PACKAGE_MISMATCH",
                "Identitas package APK tidak cocok dengan XyDesk.",
            )
        }
        if (versionCode(archive) != expectedBuild) {
            throw UpdateFailure(
                "VERSION_MISMATCH",
                "Nomor build di dalam APK tidak cocok dengan metadata Release.",
            )
        }

        val installed = installedPackageInfo()
        val installedSigners = signerDigests(installed)
        val archiveSigners = signerDigests(archive)
        if (installedSigners.isEmpty() || archiveSigners != installedSigners) {
            throw UpdateFailure(
                "SIGNATURE_MISMATCH",
                "Sertifikat signing APK tidak cocok dengan instalasi XyDesk.",
            )
        }
    }

    private fun verifyApkAbi(file: File) {
        val expectedAbi = Build.SUPPORTED_ABIS.firstOrNull().orEmpty()
        val packagedAbis = ZipFile(file).use { archive ->
            archive.entries().asSequence()
                .mapNotNull { entry ->
                    Regex("^lib/([^/]+)/[^/]+\\.so$").matchEntire(entry.name)
                        ?.groupValues
                        ?.get(1)
                }
                .toSet()
        }
        if (packagedAbis != setOf(expectedAbi)) {
            throw UpdateFailure(
                "ABI_MISMATCH",
                "Arsitektur native APK tidak cocok dengan perangkat ini.",
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun archivePackageInfo(file: File): PackageInfo? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageArchiveInfo(
                file.absolutePath,
                PackageManager.PackageInfoFlags.of(
                    PackageManager.GET_SIGNING_CERTIFICATES.toLong(),
                ),
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageArchiveInfo(
                file.absolutePath,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
        } else {
            packageManager.getPackageArchiveInfo(
                file.absolutePath,
                PackageManager.GET_SIGNATURES,
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun installedPackageInfo(): PackageInfo {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(
                    PackageManager.GET_SIGNING_CERTIFICATES.toLong(),
                ),
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
        } else {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
        }
    }

    @Suppress("DEPRECATION")
    private fun signerDigests(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo ?: return emptySet()
            signingInfo.apkContentsSigners
        } else {
            info.signatures ?: return emptySet()
        }
        return signatures.map { signature ->
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(signature.toByteArray())
            digest.joinToString("") { byte -> "%02x".format(byte) }
        }.toSet()
    }

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
    }

    private fun installedVersionCode(): Long = versionCode(installedPackageInfo())

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count <= 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { byte -> "%02x".format(byte) }
    }

    private fun failDownload(message: String, build: Long): Map<String, Any> {
        val prefs = preferences()
        val downloadId = prefs.getLong(KEY_DOWNLOAD_ID, -1L)
        if (downloadId >= 0L) downloadManager().remove(downloadId)
        downloadFile(build).delete()
        verifiedFile(build).delete()
        prefs.edit()
            .remove(KEY_DOWNLOAD_ID)
            .putString(KEY_FAILURE, message)
            .apply()
        return statusMap("failed", 0L, prefs.getLong(KEY_BYTES, 0L), message)
    }

    private fun clearPreviousDownload() {
        val prefs = preferences()
        val oldId = prefs.getLong(KEY_DOWNLOAD_ID, -1L)
        val oldBuild = prefs.getLong(KEY_BUILD, 0L)
        if (oldId >= 0L) downloadManager().remove(oldId)
        if (oldBuild > 0L) {
            downloadFile(oldBuild).delete()
            verifiedFile(oldBuild).delete()
        }
        prefs.edit().clear().apply()
    }

    private fun downloadFile(build: Long): File = File(
        getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
        "updates/XyDesk-$build.download",
    )

    private fun verifiedFile(build: Long): File = File(
        getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
        "updates/XyDesk-$build.apk",
    )

    private fun downloadManager(): DownloadManager =
        getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    private fun preferences() = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun statusMap(
        phase: String,
        downloadedBytes: Long,
        totalBytes: Long,
        message: String,
    ): Map<String, Any> = mapOf(
        "phase" to phase,
        "downloadedBytes" to downloadedBytes,
        "totalBytes" to totalBytes,
        "message" to message,
    )

    private fun pausedMessage(reason: Int): String = when (reason) {
        DownloadManager.PAUSED_WAITING_FOR_NETWORK ->
            "Download dijeda sambil menunggu jaringan."
        DownloadManager.PAUSED_QUEUED_FOR_WIFI ->
            "Download menunggu koneksi Wi-Fi."
        else -> "Download sedang dijeda oleh Android."
    }

    private fun failedMessage(reason: Int): String = when (reason) {
        DownloadManager.ERROR_INSUFFICIENT_SPACE ->
            "Ruang penyimpanan tidak cukup untuk APK update."
        DownloadManager.ERROR_DEVICE_NOT_FOUND ->
            "Penyimpanan Android tidak tersedia."
        DownloadManager.ERROR_CANNOT_RESUME ->
            "Download tidak dapat dilanjutkan. Silakan coba lagi."
        else -> "Download Android gagal (kode $reason). Silakan coba lagi."
    }

    private class UpdateFailure(
        val code: String,
        override val message: String,
    ) : Exception(message)
}
