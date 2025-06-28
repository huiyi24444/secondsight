package edu.tar.my.secondsight

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.*
import android.os.Handler
import android.os.Looper

class PoseDetectionPlugin(
    private val context: Context,
    private val flutterEngine: FlutterEngine
) : EventChannel.StreamHandler {

    companion object {
        private const val TAG = "PoseDetectionPlugin"
        private const val POSE_CHANNEL = "edu.tar.my.secondsight/pose_detection"
        private const val METHOD_CHANNEL = "edu.tar.my.secondsight/pose_methods"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var poseLandmarker: PoseLandmarker? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Main + Job())
    private var isProcessing = false

    fun registerWith(flutterEngine: FlutterEngine) {
        Log.d(TAG, "Registering PoseDetectionPlugin")

        // Event channel for streaming pose data
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, POSE_CHANNEL)
            .setStreamHandler(this)

        // Method channel for control commands
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "processFrame" -> {
                        val imageBytes = call.argument<ByteArray>("imageBytes")
                        val width = call.argument<Int>("width") ?: 0
                        val height = call.argument<Int>("height") ?: 0

                        Log.d(TAG, "processFrame called - width: $width, height: $height, bytes: ${imageBytes?.size}")

                        if (imageBytes != null && eventSink != null) {
                            processFrame(imageBytes, width, height)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGS", "Image bytes are null or event sink not ready", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "onListen called")
        eventSink = events
        initializePoseLandmarker()
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "onCancel called")
        eventSink = null
        poseLandmarker?.close()
        poseLandmarker = null
    }

    private fun initializePoseLandmarker() {
        try {
            Log.d(TAG, "Initializing PoseLandmarker")

            // Close existing pose landmarker if any
            poseLandmarker?.close()

            val baseOptions = BaseOptions.builder()
                .setModelAssetPath("pose_landmarker_lite.task")
                .setDelegate(Delegate.CPU)
                .build()

            val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { result: PoseLandmarkerResult, inputImage: MPImage ->
                    Log.d(TAG, "Pose result received with ${result.landmarks().size} poses")
                    processPoseResult(result)
                }
                .build()

            poseLandmarker = PoseLandmarker.createFromOptions(context, options)
            Log.d(TAG, "PoseLandmarker initialized successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize PoseLandmarker", e)
        }
    }

    private fun processFrame(imageBytes: ByteArray, width: Int, height: Int) {
        if (isProcessing || poseLandmarker == null) {
            return
        }

        isProcessing = true

        coroutineScope.launch(Dispatchers.Default) {
            try {
                // Convert YUV to JPEG first, then to Bitmap
                val yuvImage = YuvImage(imageBytes, ImageFormat.NV21, width, height, null)
                val out = ByteArrayOutputStream()
                yuvImage.compressToJpeg(Rect(0, 0, width, height), 100, out)
                val jpegBytes = out.toByteArray()

                val bitmap = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)

                if (bitmap != null) {
                    Log.d(TAG, "Bitmap created successfully: ${bitmap.width}x${bitmap.height}")
                    val mpImage = BitmapImageBuilder(bitmap).build()

                    withContext(Dispatchers.Main) {
                        poseLandmarker?.detectAsync(mpImage, System.currentTimeMillis())
                    }
                } else {
                    Log.e(TAG, "Failed to create bitmap from image data")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing frame", e)
            } finally {
                isProcessing = false
            }
        }
    }

    private fun processPoseResult(result: PoseLandmarkerResult) {
        if (eventSink == null) {
            Log.w(TAG, "EventSink is null, cannot send results")
            return
        }

        if (result.landmarks().isEmpty()) {
            Log.d(TAG, "No landmarks detected")
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(emptyMap<String, Any>())
            }
            return
        }

        val landmarks = result.landmarks()[0]
        val poseData = mutableMapOf<String, Map<String, Float>>()

        landmarks.forEachIndexed { index, landmark ->
            val landmarkName = getLandmarkName(index)
            poseData[landmarkName] = mapOf(
                "x" to landmark.x(),
                "y" to landmark.y(),
                "z" to landmark.z(),
                "visibility" to (landmark.visibility().orElse(0f)),
                "presence" to (landmark.presence().orElse(0f))
            )
        }

        Log.d(TAG, "Sending pose data with ${poseData.size} landmarks")
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(poseData)
        }
    }

    private fun getLandmarkName(index: Int): String {
        return when (index) {
            11 -> "left_shoulder"
            12 -> "right_shoulder"
            13 -> "left_elbow"
            14 -> "right_elbow"
            15 -> "left_wrist"
            16 -> "right_wrist"
            23 -> "left_hip"
            24 -> "right_hip"
            25 -> "left_knee"
            26 -> "right_knee"
            else -> "landmark_$index"
        }
    }
}