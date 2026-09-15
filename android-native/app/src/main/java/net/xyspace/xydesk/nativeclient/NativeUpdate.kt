package net.xyspace.xydesk.nativeclient

import android.os.Build
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** Pemeriksa manifest update resmi; URL dan checksum divalidasi sebelum ditampilkan. */
data class NativeUpdateResult(
    val installedVersion: String,
    val installedBuild: Int,
    val version: String,
    val build: Int,
    val apkUrl: String,
    val sha256: String,
    val releaseUrl: String,
    val available: Boolean,
)

class NativeUpdateChecker(
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build(),
) {
    suspend fun check(): NativeUpdateResult = withContext(Dispatchers.IO) {
        val installedVersion = BuildConfig.VERSION_NAME.substringBefore('-')
        val installedBuild = BuildConfig.VERSION_CODE
        val abi = Build.SUPPORTED_ABIS.firstOrNull { it == "arm64-v8a" || it == "armeabi-v7a" }
            ?: throw NativeUpdateException("Arsitektur perangkat tidak didukung XyDesk.")
        val request = Request.Builder()
            .url(MANIFEST_URL)
            .header("Accept", "application/json")
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw NativeUpdateException("Server update merespons HTTP ${response.code}.")
            val root = runCatching { JSONObject(response.body?.string().orEmpty()) }
                .getOrElse { throw NativeUpdateException("Metadata update tidak valid.") }
            if (root.optInt("schema", -1) != 2) throw NativeUpdateException("Schema update belum didukung.")
            val version = root.optString("version")
            val build = root.optInt("build", -1)
            val tag = root.optString("tag")
            if (!VERSION_PATTERN.matches(version) || build <= 0 || tag != "v$version") {
                throw NativeUpdateException("Versi update resmi tidak valid.")
            }
            val apk = root.optJSONObject("apks")?.optJSONObject(abi)
                ?: throw NativeUpdateException("APK untuk $abi tidak tersedia.")
            val apkUrl = apk.optString("url")
            val expectedPath = "/xykalnotkel/XyDesk/releases/download/$tag/XyDesk-Android-$abi.apk"
            val parsed = runCatching { java.net.URI(apkUrl) }.getOrNull()
            if (parsed?.scheme != "https" || parsed.host != "github.com" ||
                parsed.path != expectedPath || parsed.query != null || parsed.fragment != null
            ) {
                throw NativeUpdateException("Alamat APK resmi tidak valid.")
            }
            val sha = apk.optString("sha256").lowercase()
            if (!SHA_PATTERN.matches(sha)) throw NativeUpdateException("Checksum APK resmi tidak valid.")
            val available = compareVersions(version, installedVersion) > 0 || build > installedBuild
            NativeUpdateResult(
                installedVersion = installedVersion,
                installedBuild = installedBuild,
                version = version,
                build = build,
                apkUrl = apkUrl,
                sha256 = sha,
                releaseUrl = "https://github.com/xykalnotkel/XyDesk/releases/tag/$tag",
                available = available,
            )
        }
    }

    companion object {
        private const val MANIFEST_URL = "https://github.com/xykalnotkel/XyDesk/releases/latest/download/update.json"
        private val VERSION_PATTERN = Regex("\\d+\\.\\d+\\.\\d+")
        private val SHA_PATTERN = Regex("[a-f0-9]{64}")

        private fun compareVersions(left: String, right: String): Int {
            val a = left.split('.').map { it.toIntOrNull() ?: 0 }
            val b = right.split('.').map { it.toIntOrNull() ?: 0 }
            for (index in 0..2) {
                val compared = (a.getOrElse(index) { 0 }).compareTo(b.getOrElse(index) { 0 })
                if (compared != 0) return compared
            }
            return 0
        }
    }
}

class NativeUpdateException(message: String) : Exception(message)
