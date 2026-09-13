package com.example.evidence_vault

import android.content.Context
import android.net.Uri
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap

/**
 * App-private File attach staging. Not Evidence.
 *
 * `{operationId}.part` → `{operationId}.bin` + `{operationId}.meta` + `{operationId}.complete`
 */
internal object SafStagingStore {
    const val TAG = "EVSAF"
    private const val DIR_NAME = "attach_staging"
    const val PENDING_FILE = "pending_intent.json"
    private const val MAX_AGE_MS = 24L * 60L * 60L * 1000L
    private val OPERATION_ID = Regex("^[A-Za-z0-9._-]{1,80}$")

    private val cancelled = Collections.newSetFromMap(ConcurrentHashMap<String, Boolean>())

    fun stagingDir(context: Context): File = File(context.filesDir, DIR_NAME).apply { mkdirs() }

    fun sanitizeOperationId(raw: String?): String? {
        val id = raw?.trim().orEmpty()
        return if (OPERATION_ID.matches(id)) id else null
    }

    fun isCancelled(operationId: String): Boolean = cancelled.contains(operationId)

    fun markCancelled(operationId: String) {
        cancelled.add(operationId)
    }

    fun pendingPointerFile(context: Context): File = File(stagingDir(context), PENDING_FILE)

    fun partFile(dir: File, id: String) = File(dir, "$id.part")
    fun binFile(dir: File, id: String) = File(dir, "$id.bin")
    fun metaFile(dir: File, id: String) = File(dir, "$id.meta")
    fun completeFile(dir: File, id: String) = File(dir, "$id.complete")

    fun isComplete(context: Context, operationId: String): Boolean {
        val id = sanitizeOperationId(operationId) ?: return false
        val dir = stagingDir(context)
        if (partFile(dir, id).exists()) return false
        if (!completeFile(dir, id).exists()) return false
        if (!binFile(dir, id).exists()) return false
        val meta = readMeta(context, id) ?: return false
        if (meta.optString("status") != "complete") return false
        val size = meta.optLong("size", -1)
        val actual = binFile(dir, id).length()
        return size == actual && actual >= 0
    }

    fun readComplete(context: Context, operationId: String): JSONObject? {
        val id = sanitizeOperationId(operationId) ?: return null
        if (!isComplete(context, id)) return null
        val meta = readMeta(context, id) ?: return null
        meta.put("path", binFile(stagingDir(context), id).absolutePath)
        return meta
    }

    fun readMeta(context: Context, operationId: String): JSONObject? {
        val id = sanitizeOperationId(operationId) ?: return null
        val file = metaFile(stagingDir(context), id)
        if (!file.exists()) return null
        return try {
            JSONObject(file.readText())
        } catch (error: Exception) {
            EvLog.w(TAG, "meta parse failed operationId=$id", error)
            null
        }
    }

    fun writeCopyingMeta(
        context: Context,
        operationId: String,
        sourceUri: String,
        fileName: String,
        mimeType: String?,
        persistable: Boolean,
    ) {
        val meta = JSONObject()
            .put("operationId", operationId)
            .put("sourceUri", sourceUri)
            .put("fileName", fileName)
            .put("mimeType", mimeType ?: JSONObject.NULL)
            .put("size", 0)
            .put("sha256", JSONObject.NULL)
            .put("createdAtMs", System.currentTimeMillis())
            .put("status", "copying")
            .put("persistable", persistable)
        writeAtomic(metaFile(stagingDir(context), operationId), meta.toString())
    }

    fun streamCopy(
        context: Context,
        operationId: String,
        uri: Uri,
        fileName: String,
        mimeType: String?,
        persistable: Boolean,
    ): Boolean {
        val id = sanitizeOperationId(operationId) ?: return false
        if (isCancelled(id)) {
            deleteOperation(context, id)
            return false
        }
        val dir = stagingDir(context)
        val part = partFile(dir, id)
        val bin = binFile(dir, id)
        completeFile(dir, id).delete()
        if (part.exists()) part.delete()
        if (bin.exists()) bin.delete()

        writeCopyingMeta(context, id, uri.toString(), fileName, mimeType, persistable)
        EvLog.i(TAG, "COPY_START operationId=$id uri=$uri")

        val digest = MessageDigest.getInstance("SHA-256")
        var size = 0L
        try {
            context.contentResolver.openInputStream(uri).use { input ->
                if (input == null) {
                    EvLog.e(TAG, "COPY_FAILED operationId=$id reason=null_stream")
                    writeFailedMeta(context, id, uri.toString(), fileName, mimeType, persistable)
                    return false
                }
                FileOutputStream(part).use { output ->
                    val buffer = ByteArray(8192)
                    while (true) {
                        if (isCancelled(id)) {
                            EvLog.i(TAG, "COPY_CANCELLED operationId=$id")
                            output.fd.sync()
                            deleteOperation(context, id)
                            return false
                        }
                        val read = input.read(buffer)
                        if (read < 0) break
                        if (read == 0) continue
                        output.write(buffer, 0, read)
                        digest.update(buffer, 0, read)
                        size += read
                    }
                    output.flush()
                    output.fd.sync()
                }
            }
        } catch (error: Exception) {
            EvLog.e(TAG, "COPY_FAILED operationId=$id", error)
            part.delete()
            writeFailedMeta(context, id, uri.toString(), fileName, mimeType, persistable)
            return false
        }

        if (isCancelled(id)) {
            deleteOperation(context, id)
            return false
        }

        if (!part.renameTo(bin)) {
            try {
                part.copyTo(bin, overwrite = true)
                part.delete()
            } catch (error: Exception) {
                EvLog.e(TAG, "COPY_RENAME_FAILED operationId=$id", error)
                writeFailedMeta(context, id, uri.toString(), fileName, mimeType, persistable)
                return false
            }
        }

        val sha = digest.digest().joinToString("") { "%02x".format(it) }
        val completeMeta = JSONObject()
            .put("operationId", id)
            .put("sourceUri", uri.toString())
            .put("fileName", fileName)
            .put("mimeType", mimeType ?: JSONObject.NULL)
            .put("size", size)
            .put("sha256", sha)
            .put("createdAtMs", System.currentTimeMillis())
            .put("status", "complete")
            .put("persistable", persistable)
        writeAtomic(metaFile(dir, id), completeMeta.toString())
        writeAtomic(completeFile(dir, id), "complete")

        if (isCancelled(id) || !isComplete(context, id)) {
            EvLog.w(TAG, "COPY_INCOMPLETE_AFTER_PROMOTE operationId=$id")
            if (isCancelled(id)) deleteOperation(context, id)
            return false
        }
        EvLog.i(TAG, "COPY_COMPLETE operationId=$id size=$size sha256=$sha fileName=$fileName")
        return true
    }

    fun retryIncompleteIfPossible(context: Context, operationId: String): Boolean {
        val id = sanitizeOperationId(operationId) ?: return false
        if (isComplete(context, id)) return true
        val meta = readMeta(context, id) ?: return false
        if (meta.optString("status") == "complete") return isComplete(context, id)
        if (!meta.optBoolean("persistable", false)) return false
        val uriRaw = meta.optString("sourceUri")
        if (uriRaw.isNullOrBlank()) return false
        val uri = try {
            Uri.parse(uriRaw)
        } catch (_: Exception) {
            return false
        }
        if (uri.scheme != "content") return false
        val fileName = sanitizeDisplayName(meta.optString("fileName"))
        val mime = meta.optString("mimeType").takeIf { it.isNotBlank() && it != "null" }
        EvLog.i(TAG, "COPY_RETRY operationId=$id uri=$uri")
        return streamCopy(context, id, uri, fileName, mime, persistable = true)
    }

    fun discard(context: Context, operationId: String) {
        val id = sanitizeOperationId(operationId) ?: return
        markCancelled(id)
        deleteOperation(context, id)
        val pending = pendingPointerFile(context)
        val pendingJson = readPendingPointer(context)
        if (pendingJson?.optString("operationId") == id && pending.exists()) {
            pending.delete()
            EvLog.i(TAG, "PENDING_POINTER_CLEARED operationId=$id")
        }
        EvLog.i(TAG, "DISCARD operationId=$id")
    }

    fun discardAll(context: Context) {
        val dir = stagingDir(context)
        dir.listFiles()?.forEach { file ->
            val name = file.name
            if (name.endsWith(".part") ||
                name.endsWith(".bin") ||
                name.endsWith(".meta") ||
                name.endsWith(".complete")
            ) {
                val op = name.substringBeforeLast('.')
                markCancelled(op)
            }
            file.delete()
        }
        EvLog.i(TAG, "DISCARD_ALL")
    }

    fun sweepStale(context: Context) {
        val dir = stagingDir(context)
        val now = System.currentTimeMillis()
        dir.listFiles()?.forEach { file ->
            if (file.name == PENDING_FILE) return@forEach
            val op = file.name.substringBeforeLast('.')
            val meta = readMeta(context, op)
            val created = meta?.optLong("createdAtMs", file.lastModified()) ?: file.lastModified()
            if (now - created > MAX_AGE_MS) {
                EvLog.i(TAG, "STALE_SWEEP operationId=$op ageMs=${now - created}")
                deleteOperation(context, op)
            }
        }
    }

    fun readPendingPointer(context: Context): JSONObject? {
        val file = pendingPointerFile(context)
        if (!file.exists()) return null
        return try {
            JSONObject(file.readText())
        } catch (error: Exception) {
            EvLog.w(TAG, "pending pointer parse failed", error)
            null
        }
    }

    fun sanitizeDisplayName(raw: String?): String {
        var name = raw?.trim().orEmpty().ifEmpty { "document" }
        name = name.replace('\\', '_').replace('/', '_')
        name = name.replace("..", "_")
        if (name.length > 255) {
            name = name.take(255)
        }
        return name
    }

    fun isSafeFileUri(context: Context, uri: Uri): Boolean {
        if (uri.scheme != "file") return false
        val path = uri.path ?: return false
        val target = try {
            File(path).canonicalFile
        } catch (_: Exception) {
            return false
        }
        val allowed = listOf(context.filesDir, context.cacheDir).map { it.canonicalFile }
        return allowed.any { root ->
            target.path == root.path || target.path.startsWith(root.path + File.separator)
        }
    }

    private fun deleteOperation(context: Context, operationId: String) {
        val dir = stagingDir(context)
        partFile(dir, operationId).delete()
        binFile(dir, operationId).delete()
        metaFile(dir, operationId).delete()
        completeFile(dir, operationId).delete()
    }

    private fun writeFailedMeta(
        context: Context,
        operationId: String,
        sourceUri: String,
        fileName: String,
        mimeType: String?,
        persistable: Boolean,
    ) {
        val meta = JSONObject()
            .put("operationId", operationId)
            .put("sourceUri", sourceUri)
            .put("fileName", fileName)
            .put("mimeType", mimeType ?: JSONObject.NULL)
            .put("size", 0)
            .put("sha256", JSONObject.NULL)
            .put("createdAtMs", System.currentTimeMillis())
            .put("status", "failed")
            .put("persistable", persistable)
        writeAtomic(metaFile(stagingDir(context), operationId), meta.toString())
    }

    private fun writeAtomic(file: File, contents: String) {
        val tmp = File(file.parentFile, "${file.name}.tmp")
        FileOutputStream(tmp).use { output ->
            output.write(contents.toByteArray(Charsets.UTF_8))
            output.flush()
            output.fd.sync()
        }
        if (!tmp.renameTo(file)) {
            tmp.copyTo(file, overwrite = true)
            tmp.delete()
            FileOutputStream(file, true).use { it.fd.sync() }
        }
    }
}
