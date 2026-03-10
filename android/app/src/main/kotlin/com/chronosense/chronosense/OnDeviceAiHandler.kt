package com.chronosense.chronosense

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File

/**
 * Platform channel handler for fully on-device AI inference.
 *
 * Privacy guarantee: all journal data stays on the device.
 * The only network call is a one-time model download from Google's
 * public model storage (no user data is involved in that request).
 *
 * How model delivery works:
 * ─────────────────────────
 * 1. User taps "Enable AI" in the Insights tab.
 * 2. [handlePrepareModel] checks whether the model file already exists
 *    in the app's private files directory.
 * 3. If not present, Android DownloadManager downloads it in the
 *    background (~1.4 GB, Wi-Fi recommended). DownloadManager handles
 *    pause/resume and shows a system notification automatically.
 * 4. [handleDownloadProgress] is polled by Flutter every second via
 *    the EventChannel to stream progress (0.0–1.0) to the UI.
 * 5. Once the file is on disk, [initModel] loads it into MediaPipe's
 *    LlmInference runtime which uses the GPU/NPU when available.
 * 6. Subsequent [handleGenerateInsight] calls run the Gemma model
 *    entirely on-device — no network involved.
 *
 * Channels:
 *   MethodChannel  com.chronosense/on_device_ai         (commands)
 *   EventChannel   com.chronosense/on_device_ai_progress (download %)
 */
class OnDeviceAiHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // MediaPipe inference instance — null until model is loaded
    private var llmInference: LlmInference? = null
    private var isModelReady = false

    // Active DownloadManager request ID (-1 = none)
    private var downloadId: Long = -1L
    private var progressSink: EventChannel.EventSink? = null
    private var progressJob: Job? = null

    companion object {
        private const val METHOD_CHANNEL  = "com.chronosense/on_device_ai"
        private const val EVENT_CHANNEL   = "com.chronosense/on_device_ai_progress"
        private const val MODEL_FILENAME  = "gemma-2b-it-gpu-int4.bin"

        // Publicly hosted, no auth required.
        // Source: https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android
        private const val MODEL_URL =
            "https://storage.googleapis.com/mediapipe-models/" +
            "llm_inference/gemma-2b-it-gpu-int4/float16/1/gemma-2b-it-gpu-int4.bin"

        fun register(flutterEngine: FlutterEngine, context: Context) {
            val handler = OnDeviceAiHandler(context)

            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                METHOD_CHANNEL,
            ).setMethodCallHandler(handler)

            EventChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                EVENT_CHANNEL,
            ).setStreamHandler(handler)
        }
    }

    // ── MethodChannel ────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable"     -> result.success(isModelReady)
            "getStatus"       -> handleGetStatus(result)
            "prepareModel"    -> handlePrepareModel(result)
            "cancelDownload"  -> handleCancelDownload(result)
            "generateInsight" -> handleGenerateInsight(call, result)
            else              -> result.notImplemented()
        }
    }

    private fun handleGetStatus(result: MethodChannel.Result) {
        val status = when {
            isModelReady           -> "ready"
            downloadId != -1L      -> "downloading"
            modelFile().exists()   -> "downloaded" // on disk, not yet loaded
            else                   -> "not_downloaded"
        }
        result.success(status)
    }

    /**
     * Prepares the model:
     * - If already loaded → returns true immediately.
     * - If file is on disk → loads it into LlmInference and returns true.
     * - Otherwise → starts DownloadManager download and returns false
     *   (Flutter checks progress via EventChannel until status == "ready").
     */
    private fun handlePrepareModel(result: MethodChannel.Result) {
        if (isModelReady) { result.success(true); return }

        val file = modelFile()

        if (file.exists()) {
            scope.launch {
                val ok = initModel(file)
                withContext(Dispatchers.Main) {
                    if (ok) result.success(true)
                    else result.error("INIT_ERROR", "Failed to load model from disk", null)
                }
            }
            return
        }

        // Start download
        file.parentFile?.mkdirs()

        val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val request = DownloadManager.Request(Uri.parse(MODEL_URL))
            .setTitle("Minovi AI model")
            .setDescription("Downloading on-device AI model (~1.4 GB)")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            .setDestinationUri(Uri.fromFile(file))
            .setAllowedOverMetered(false)   // Wi-Fi only by default
            .setAllowedOverRoaming(false)

        downloadId = dm.enqueue(request)
        startProgressPolling(dm, file, result)

        // Return false immediately; Flutter listens to EventChannel for progress
        // and re-calls prepareModel once the EventChannel signals completion.
        // We do NOT call result here — it will be called from the polling coroutine.
    }

    private fun startProgressPolling(
        dm: DownloadManager,
        file: File,
        result: MethodChannel.Result,
    ) {
        progressJob = scope.launch {
            var resultSent = false
            while (isActive) {
                delay(1_000)
                val query = DownloadManager.Query().setFilterById(downloadId)
                val cursor = dm.query(query)

                if (!cursor.moveToFirst()) {
                    cursor.close()
                    if (!resultSent) {
                        resultSent = true
                        withContext(Dispatchers.Main) {
                            result.error("DOWNLOAD_CANCELLED", "Download was cancelled", null)
                        }
                    }
                    break
                }

                val statusCol  = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
                val bytesCol   = cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                val totalCol   = cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                val status     = cursor.getInt(statusCol)
                val downloaded = cursor.getLong(bytesCol)
                val total      = cursor.getLong(totalCol)
                cursor.close()

                // Emit progress to EventChannel
                if (total > 0) {
                    val progress = downloaded.toDouble() / total.toDouble()
                    withContext(Dispatchers.Main) {
                        progressSink?.success(progress)
                    }
                }

                when (status) {
                    DownloadManager.STATUS_SUCCESSFUL -> {
                        downloadId = -1L
                        withContext(Dispatchers.Main) { progressSink?.success(1.0) }
                        val ok = initModel(file)
                        if (!resultSent) {
                            resultSent = true
                            withContext(Dispatchers.Main) {
                                if (ok) result.success(true)
                                else result.error("INIT_ERROR", "Model downloaded but failed to load", null)
                            }
                        }
                        break
                    }
                    DownloadManager.STATUS_FAILED -> {
                        downloadId = -1L
                        file.delete()
                        if (!resultSent) {
                            resultSent = true
                            withContext(Dispatchers.Main) {
                                result.error("DOWNLOAD_FAILED", "Download failed", null)
                            }
                        }
                        break
                    }
                }
            }
        }
    }

    private fun handleCancelDownload(result: MethodChannel.Result) {
        if (downloadId != -1L) {
            val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            dm.remove(downloadId)
            downloadId = -1L
        }
        progressJob?.cancel()
        result.success(null)
    }

    /**
     * Loads the model file into MediaPipe LlmInference.
     * Runs on IO dispatcher; returns true on success.
     */
    private suspend fun initModel(file: File): Boolean = withContext(Dispatchers.IO) {
        return@withContext try {
            val options = LlmInference.LlmInferenceOptions.builder()
                .setModelPath(file.absolutePath)
                .setMaxTokens(2048)
                .setTopK(40)
                .setTemperature(0.7f)
                .setRandomSeed(42)
                .build()
            llmInference = LlmInference.createFromOptions(context, options)
            isModelReady = true
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun handleGenerateInsight(call: MethodCall, result: MethodChannel.Result) {
        val prompt = call.argument<String>("prompt") ?: run {
            result.error("INVALID_ARGS", "Missing 'prompt'", null)
            return
        }
        val inference = llmInference
        if (!isModelReady || inference == null) {
            result.error("MODEL_NOT_READY", "Model is not loaded yet", null)
            return
        }
        scope.launch {
            try {
                val response = inference.generateResponse(prompt)
                withContext(Dispatchers.Main) { result.success(response) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("INFERENCE_ERROR", e.message, null)
                }
            }
        }
    }

    // ── EventChannel (download progress 0.0–1.0) ─────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        progressSink = events
    }

    override fun onCancel(arguments: Any?) {
        progressSink = null
    }

    // ── Helpers ───────────────────────────────────────────────────────

    private fun modelFile(): File =
        File(context.filesDir, "models/$MODEL_FILENAME")

    fun dispose() {
        scope.cancel()
        llmInference?.close()
    }
}
