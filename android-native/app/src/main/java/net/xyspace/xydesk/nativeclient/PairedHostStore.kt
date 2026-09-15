package net.xyspace.xydesk.nativeclient

import org.json.JSONArray
import org.json.JSONObject

/** Riwayat host lokal; ID dan password tersimpan terenkripsi lewat SecureStore. */
data class PairedHost(
    val id: String,
    val name: String,
    val password: String,
    val lastConnectedAt: Long,
)

class PairedHostStore(
    private val secureStore: SecureStore,
    private val accountScope: String,
) {
    private val storageKey = "$KEY_PREFIX:${accountScope.ifBlank { "anonymous" }}"

    fun list(): List<PairedHost> = runCatching {
        val raw = secureStore.getString(storageKey) ?: return emptyList()
        val array = JSONArray(raw)
        buildList {
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                val id = item.optString("id")
                val password = item.optString("password")
                if (id.isNotBlank() && password.isNotBlank()) {
                    add(
                        PairedHost(
                            id = id,
                            name = item.optString("name").ifBlank { "PC-${id.takeLast(4)}" },
                            password = password,
                            lastConnectedAt = item.optLong("lastConnectedAt", 0L),
                        ),
                    )
                }
            }
        }
    }.getOrDefault(emptyList())

    fun save(id: String, password: String, name: String = "PC-${id.takeLast(4)}") {
        val normalized = NativeRtcSession.normalizeHostId(id)
        val updated = list()
            .filterNot { it.id == normalized }
            .toMutableList()
            .apply {
                add(0, PairedHost(normalized, name, password, System.currentTimeMillis()))
            }
            .take(MAX_HOSTS)
        val array = JSONArray()
        updated.forEach { host ->
            array.put(
                JSONObject().apply {
                    put("id", host.id)
                    put("name", host.name)
                    put("password", host.password)
                    put("lastConnectedAt", host.lastConnectedAt)
                },
            )
        }
        secureStore.putString(storageKey, array.toString())
    }

    fun rename(id: String, name: String) {
        val cleanName = name.trim().take(48)
        if (cleanName.isBlank()) return
        val array = JSONArray()
        list().forEach { host ->
            array.put(
                JSONObject().apply {
                    put("id", host.id)
                    put("name", if (host.id == id) cleanName else host.name)
                    put("password", host.password)
                    put("lastConnectedAt", host.lastConnectedAt)
                },
            )
        }
        secureStore.putString(storageKey, array.toString())
    }

    fun remove(id: String) {
        val array = JSONArray()
        list().filterNot { it.id == id }.forEach { host ->
            array.put(
                JSONObject().apply {
                    put("id", host.id)
                    put("name", host.name)
                    put("password", host.password)
                    put("lastConnectedAt", host.lastConnectedAt)
                },
            )
        }
        secureStore.putString(storageKey, array.toString())
    }

    companion object {
        private const val KEY_PREFIX = "paired.hosts"
        private const val MAX_HOSTS = 5
    }
}
