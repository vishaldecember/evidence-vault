package com.example.evidence_vault

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors

/**
 * Small SAF durability bridge. Does not replace file_picker.
 *
 * Correlation: RESULT_OK + content/file URI + pending DurableAttachIntent.
 * Does not use file_picker request codes.
 */
class SafDurabilityBridge(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
        EvLog.i(SafStagingStore.TAG, "CHANNEL_REGISTERED name=$CHANNEL")
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getArtifact" -> {
                val operationId = call.argument<String>("operationId")
                executor.execute {
                    val payload = getArtifactSync(context, operationId)
                    mainHandler.post { result.success(payload) }
                }
            }
            "discard" -> {
                val operationId = call.argument<String>("operationId")
                executor.execute {
                    val id = SafStagingStore.sanitizeOperationId(operationId)
                    if (id != null) {
                        SafStagingStore.discard(context, id)
                    }
                    mainHandler.post { result.success(true) }
                }
            }
            "discardAll" -> {
                executor.execute {
                    SafStagingStore.discardAll(context)
                    mainHandler.post { result.success(true) }
                }
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "evidence_vault/saf_staging"

        private val executor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "ev-saf-staging").apply { isDaemon = true }
        }
        private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

        /**
         * Intercept SAF results before Flutter plugins. Always safe to call
         * before `super.onActivityResult` so file_picker still receives the result.
         */
        fun onHostActivityResult(activity: Activity, resultCode: Int, data: Intent?) {
            SafStagingStore.sweepStale(activity)
            if (resultCode != Activity.RESULT_OK) {
                EvLog.i(SafStagingStore.TAG, "RESULT_IGNORE resultCode=$resultCode")
                return
            }
            val uri = data?.data
            if (uri == null) {
                EvLog.i(SafStagingStore.TAG, "RESULT_IGNORE reason=no_uri")
                return
            }
            if (!isAcceptedUri(activity, uri)) {
                EvLog.w(SafStagingStore.TAG, "RESULT_REJECT scheme=${uri.scheme} uri=$uri")
                return
            }
            val pending = readPendingIntent(activity)
            if (pending == null) {
                EvLog.i(SafStagingStore.TAG, "RESULT_SKIP no_pending_intent uri=$uri")
                return
            }
            val operationId = SafStagingStore.sanitizeOperationId(pending.optString("operationId"))
            if (operationId == null) {
                EvLog.w(SafStagingStore.TAG, "RESULT_SKIP invalid_operationId")
                return
            }
            val persistable = takeReadPermissionBestEffort(activity, data, uri)
            val fileName = SafStagingStore.sanitizeDisplayName(queryDisplayName(activity, uri))
            val mimeType = activity.contentResolver.getType(uri)
            EvLog.i(
                SafStagingStore.TAG,
                "RESULT_OK operationId=$operationId persistable=$persistable " +
                    "fileName=$fileName mime=$mimeType uri=$uri",
            )
            executor.execute {
                SafStagingStore.streamCopy(
                    context = activity.applicationContext,
                    operationId = operationId,
                    uri = uri,
                    fileName = fileName,
                    mimeType = mimeType,
                    persistable = persistable,
                )
            }
        }

        private fun getArtifactSync(context: Context, operationId: String?): Map<String, Any?>? {
            SafStagingStore.sweepStale(context)
            val id = SafStagingStore.sanitizeOperationId(operationId) ?: return null
            if (SafStagingStore.isComplete(context, id)) {
                return artifactMap(SafStagingStore.readComplete(context, id))
            }
            val retried = SafStagingStore.retryIncompleteIfPossible(context, id)
            if (retried && SafStagingStore.isComplete(context, id)) {
                return artifactMap(SafStagingStore.readComplete(context, id))
            }
            val meta = SafStagingStore.readMeta(context, id)
            val status = meta?.optString("status") ?: "none"
            EvLog.i(SafStagingStore.TAG, "GET_ARTIFACT operationId=$id status=$status complete=false")
            return null
        }

        private fun artifactMap(meta: JSONObject?): Map<String, Any?>? {
            if (meta == null) return null
            EvLog.i(
                SafStagingStore.TAG,
                "GET_ARTIFACT operationId=${meta.optString("operationId")} status=complete " +
                    "size=${meta.optLong("size")} path=${meta.optString("path")}",
            )
            return mapOf(
                "operationId" to meta.optString("operationId"),
                "path" to meta.optString("path"),
                "fileName" to meta.optString("fileName"),
                "mimeType" to meta.optString("mimeType").takeIf { it.isNotBlank() && it != "null" },
                "size" to meta.optLong("size"),
                "sha256" to meta.optString("sha256").takeIf { it.isNotBlank() && it != "null" },
                "status" to "complete",
                "createdAtMs" to meta.optLong("createdAtMs"),
            )
        }

        private fun isAcceptedUri(context: Context, uri: Uri): Boolean {
            return when (uri.scheme) {
                "content" -> true
                "file" -> SafStagingStore.isSafeFileUri(context, uri)
                else -> false
            }
        }

        private fun takeReadPermissionBestEffort(activity: Activity, data: Intent, uri: Uri): Boolean {
            if (uri.scheme != "content") return false
            return try {
                val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                val offered = (data.flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION) != 0
                if (offered) {
                    activity.contentResolver.takePersistableUriPermission(uri, flags)
                    EvLog.i(SafStagingStore.TAG, "PERSISTABLE_URI_TAKEN uri=$uri")
                    true
                } else {
                    try {
                        activity.contentResolver.takePersistableUriPermission(uri, flags)
                        EvLog.i(SafStagingStore.TAG, "PERSISTABLE_URI_TAKEN_UNFLAGGED uri=$uri")
                        true
                    } catch (_: SecurityException) {
                        EvLog.i(SafStagingStore.TAG, "PERSISTABLE_URI_UNAVAILABLE uri=$uri")
                        false
                    }
                }
            } catch (error: SecurityException) {
                EvLog.i(SafStagingStore.TAG, "PERSISTABLE_URI_DENIED uri=$uri ${error.message}")
                false
            } catch (error: Exception) {
                EvLog.w(SafStagingStore.TAG, "PERSISTABLE_URI_ERROR uri=$uri", error)
                false
            }
        }

        private fun queryDisplayName(context: Context, uri: Uri): String {
            if (uri.scheme == "content") {
                try {
                    context.contentResolver.query(
                        uri,
                        arrayOf(OpenableColumns.DISPLAY_NAME),
                        null,
                        null,
                        null,
                    )?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                            if (index >= 0) {
                                val value = cursor.getString(index)
                                if (!value.isNullOrBlank()) return value
                            }
                        }
                    }
                } catch (error: Exception) {
                    EvLog.w(SafStagingStore.TAG, "DISPLAY_NAME_QUERY_FAILED", error)
                }
            }
            return uri.lastPathSegment ?: "document"
        }

        private fun readPendingIntent(context: Context): JSONObject? {
            val pointer = SafStagingStore.readPendingPointer(context)
            if (pointer != null) {
                val op = pointer.optString("operationId")
                EvLog.i(SafStagingStore.TAG, "PENDING_POINTER operationId=$op")
                return pointer
            }
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val prefix = "flutter.ev_durable_attach_intent_v1_"
            var newest: JSONObject? = null
            var newestCreated = Long.MIN_VALUE
            for ((key, value) in prefs.all) {
                if (!key.startsWith(prefix) || value !is String) continue
                try {
                    val parsed = JSONObject(value)
                    val created = parsed.optLong("createdAtMs", 0)
                    if (created >= newestCreated) {
                        newestCreated = created
                        newest = parsed
                    }
                } catch (error: Exception) {
                    EvLog.w(SafStagingStore.TAG, "PREFS_INTENT_PARSE_FAILED key=$key", error)
                }
            }
            if (newest != null) {
                EvLog.i(
                    SafStagingStore.TAG,
                    "PENDING_PREFS operationId=${newest.optString("operationId")}",
                )
            }
            return newest
        }
    }
}
