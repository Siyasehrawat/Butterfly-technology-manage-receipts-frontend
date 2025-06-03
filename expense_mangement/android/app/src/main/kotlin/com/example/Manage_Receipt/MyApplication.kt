package com.ButterflyTchnology.managereceipt

import io.flutter.app.FlutterApplication
import androidx.multidex.MultiDex
import android.content.Context

class MyApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        // Any initialization code can go here
    }

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        MultiDex.install(this)
    }
}