package com.scc.scc_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.Log

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AlarmReceiver", "Alarm received! Launching MainActivity force-fullscreen...")
        
        val payload = intent.getStringExtra("payload")
        
        val newIntent = Intent(context, MainActivity::class.java)
        newIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        if (payload != null) {
            newIntent.putExtra("payload", payload)
            newIntent.putExtra("is_alarm_launch", true)
        }
        
        context.startActivity(newIntent)
    }
}
