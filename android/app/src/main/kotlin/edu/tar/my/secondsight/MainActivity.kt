package edu.tar.my.secondsight

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity()  {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val poseDetectionPlugin = PoseDetectionPlugin(context = this, flutterEngine = flutterEngine)
        poseDetectionPlugin.registerWith(flutterEngine)
    }
}