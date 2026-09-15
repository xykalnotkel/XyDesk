package net.xyspace.xydesk.nativeclient

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import java.security.MessageDigest

/** Download dan handoff APK resmi ke package installer Android. */
class NativeUpdateInstaller(private val context: Context) {
    private val downloadManager = context.getSystemService(DownloadManager::class.java)

    fun enqueue(result: NativeUpdateResult): Long {
        val request = DownloadManager.Request(Uri.parse(result.apkUrl))
            .setTitle("XyDesk ${result.version}")
            .setDescription("Mengunduh update resmi XyDesk")
            .setMimeType(APK_MIME)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)
            .setDestinationInExternalFilesDir(
                context,
                Environment.DIRECTORY_DOWNLOADS,
                "XyDesk-Android-${BuildConfig.VERSION_NAME}-${result.build}.apk",
            )
        return downloadManager.enqueue(request)
    }

    fun status(downloadId: Long): DownloadStatus {
        val query = DownloadManager.Query().setFilterById(downloadId)
        downloadManager.query(query).use { cursor ->
            if (!cursor.moveToFirst()) return DownloadStatus.Missing
            return when (cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))) {
                DownloadManager.STATUS_SUCCESSFUL -> DownloadStatus.Ready
                DownloadManager.STATUS_FAILED -> DownloadStatus.Failed
                DownloadManager.STATUS_PAUSED,
                DownloadManager.STATUS_PENDING,
                DownloadManager.STATUS_RUNNING -> DownloadStatus.InProgress
                else -> DownloadStatus.InProgress
            }
        }
    }

    fun verify(downloadId: Long, expectedSha256: String): Boolean {
        val uri = downloadManager.getUriForDownloadedFile(downloadId) ?: return false
        val digest = MessageDigest.getInstance("SHA-256")
        context.contentResolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count <= 0) break
                digest.update(buffer, 0, count)
            }
        } ?: return false
        return digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) } == expectedSha256.lowercase()
    }

    fun install(downloadId: Long) {
        val uri = downloadManager.getUriForDownloadedFile(downloadId)
            ?: throw IllegalStateException("File update belum tersedia.")
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, APK_MIME)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(intent)
    }

    enum class DownloadStatus { InProgress, Ready, Failed, Missing }

    companion object {
        const val APK_MIME = "application/vnd.android.package-archive"
    }
}
