package com.chronosense.chronosense

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

/**
 * Platform channel handler for on-device AI inference.
 *
 * Architecture:
 * - Uses Google MediaPipe LLM Inference API to run Gemma 2B on-device.
 * - All data stays on the device — nothing is sent to any server.
 * - If the model is not available, returns appropriate status so the
 *   Flutter side can fall back to the template-based report engine.
 *
 * To enable the full LLM experience later:
 * 1. Add the MediaPipe LLM dependency to app/build.gradle.kts
 * 2. Download the Gemma 2B model to the app's assets or files dir
 * 3. Uncomment the inference code below
 */
class OnDeviceAiHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Will hold the MediaPipe LlmInference instance once model is loaded
    private var isModelReady = false

    companion object {
        private const val CHANNEL_NAME = "com.chronosense/on_device_ai"

        fun register(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL_NAME
            )
            channel.setMethodCallHandler(OnDeviceAiHandler(context))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> handleIsAvailable(result)
            "generateInsight" -> handleGenerateInsight(call, result)
            "prepareModel" -> handlePrepareModel(result)
            "getStatus" -> handleGetStatus(result)
            else -> result.notImplemented()
        }
    }

    private fun handleIsAvailable(result: MethodChannel.Result) {
        // Check if on-device LLM is available
        // For now, returns false until the MediaPipe model is set up.
        // When the model is downloaded and ready, this will return true.
        result.success(isModelReady)
    }

    private fun handleGenerateInsight(call: MethodCall, result: MethodChannel.Result) {
        val prompt = call.argument<String>("prompt")
        if (prompt == null) {
            result.error("INVALID_ARGS", "Missing 'prompt' argument", null)
            return
        }

        if (!isModelReady) {
            result.error(
                "MODEL_NOT_READY",
                "On-device model is not ready. Use the template-based report.",
                null
            )
            return
        }

        // When MediaPipe LLM Inference is integrated:
        // scope.launch {
        //     try {
        //         val response = llmInference.generateResponse(prompt)
        //         withContext(Dispatchers.Main) {
        //             result.success(response)
        //         }
        //     } catch (e: Exception) {
        //         withContext(Dispatchers.Main) {
        //             result.error("INFERENCE_ERROR", e.message, null)
        //         }
        //     }
        // }

        result.error(
            "MODEL_NOT_READY",
            "On-device model is not configured yet.",
            null
        )
    }

    private fun handlePrepareModel(result: MethodChannel.Result) {
        // When MediaPipe is integrated, this will:
        // 1. Check if model file exists in app's files directory
        // 2. If not, start downloading it
        // 3. Initialize the LlmInference task
        //
        // Example (to be uncommented when MediaPipe dep is added):
        //
        // scope.launch {
        //     try {
        //         val modelPath = File(context.filesDir, "gemma-2b-it-gpu-int4.bin")
        //         if (!modelPath.exists()) {
        //             // Download model (or prompt user to download)
        //             withContext(Dispatchers.Main) {
        //                 result.success(false) // not yet downloaded
        //             }
        //             return@launch
        //         }
        //         val options = LlmInference.LlmInferenceOptions.builder()
        //             .setModelPath(modelPath.absolutePath)
        //             .setMaxTokens(2048)
        //             .setTopK(40)
        //             .setTemperature(0.7f)
        //             .build()
        //         llmInference = LlmInference.createFromOptions(context, options)
        //         isModelReady = true
        //         withContext(Dispatchers.Main) {
        //             result.success(true)
        //         }
        //     } catch (e: Exception) {
        //         withContext(Dispatchers.Main) {
        //             result.error("PREPARE_ERROR", e.message, null)
        //         }
        //     }
        // }

        result.success(false)
    }

    private fun handleGetStatus(result: MethodChannel.Result) {
        val status = when {
            isModelReady -> "ready"
            // When MediaPipe is integrated, check model file existence:
            // File(context.filesDir, "gemma-2b-it-gpu-int4.bin").exists() -> "not_downloaded"
            else -> "not_downloaded"
        }
        result.success(status)
    }

    fun dispose() {
        scope.cancel()
    }
}
