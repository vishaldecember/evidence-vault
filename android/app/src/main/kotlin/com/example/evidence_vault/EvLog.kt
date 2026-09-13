package com.example.evidence_vault

import android.util.Log

/** Debug-build logging. Release builds emit nothing. */
internal object EvLog {
    fun i(tag: String, message: String) {
        if (BuildConfig.DEBUG) {
            Log.i(tag, message)
        }
    }

    fun w(tag: String, message: String, tr: Throwable? = null) {
        if (!BuildConfig.DEBUG) {
            return
        }
        if (tr == null) {
            Log.w(tag, message)
        } else {
            Log.w(tag, message, tr)
        }
    }

    fun e(tag: String, message: String, tr: Throwable? = null) {
        if (!BuildConfig.DEBUG) {
            return
        }
        if (tr == null) {
            Log.e(tag, message)
        } else {
            Log.e(tag, message, tr)
        }
    }
}
