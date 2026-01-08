package com.scanworks.obsi

import android.app.Activity
import android.app.AlertDialog
import android.content.DialogInterface
import android.os.Bundle
import android.util.Log
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Toast
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Lightweight dialog Activity for entering a new memo.
 * Designed to appear as a floating dialog without switching to the full app.
 */
class MemoInputActivity : Activity() {
    private val TAG = "MemoInputActivity"

    companion object {
        const val EXTRA_VAULT_DIR = "vault_dir"
        const val EXTRA_NOTE_FILE = "note_file"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Don't set any content view - we only show a dialog

        val vaultDir = intent.getStringExtra(EXTRA_VAULT_DIR)
        val noteFile = intent.getStringExtra(EXTRA_NOTE_FILE)

        if (vaultDir.isNullOrEmpty() || noteFile.isNullOrEmpty()) {
            Log.e(TAG, "Missing vault or note file parameters")
            Toast.makeText(this, "Configuration error", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        showMemoInputDialog(vaultDir, noteFile)
    }

    private fun showMemoInputDialog(vaultDir: String, noteFile: String) {
        val editText = EditText(this).apply {
            hint = "What's on your mind?"
            isSingleLine = false
            minLines = 2
            maxLines = 5
            requestFocus()
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 32, 48, 16)
            addView(editText)
        }

        AlertDialog.Builder(this)
            .setTitle("✏️ New Memo")
            .setView(container)
            .setPositiveButton("Save", DialogInterface.OnClickListener { _, _ ->
                val content = editText.text.toString().trim()
                if (content.isNotEmpty()) {
                    saveMemo(vaultDir, noteFile, content)
                } else {
                    finish()
                }
            })
            .setNegativeButton("Cancel", DialogInterface.OnClickListener { _, _ ->
                finish()
            })
            .setOnCancelListener {
                finish()
            }
            .setOnDismissListener {
                // Ensure we finish when dialog is dismissed
                if (!isFinishing) {
                    finish()
                }
            }
            .show()
    }

    private fun saveMemo(vaultDir: String, noteFile: String, content: String) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Construct full path
                val fullPath = if (noteFile.startsWith("/")) {
                    noteFile
                } else if (noteFile.endsWith(".md")) {
                    "$vaultDir/$noteFile"
                } else {
                    "$vaultDir/$noteFile.md"
                }

                val file = File(fullPath)

                // Create parent directories if needed
                file.parentFile?.mkdirs()

                // Generate timestamp (default HH:mm)
                val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
                val timestamp = timeFormat.format(Date())

                // Format memo line
                val memoLine = "- $timestamp $content\n"

                // Append to file
                if (file.exists()) {
                    // Check if file ends with newline, add one if not
                    val existingContent = file.readText()
                    if (existingContent.isNotEmpty() && !existingContent.endsWith("\n")) {
                        file.appendText("\n")
                    }
                    file.appendText(memoLine)
                } else {
                    file.writeText(memoLine)
                }

                Log.d(TAG, "Memo saved to: $fullPath")

                // Refresh the widget and show success on main thread
                CoroutineScope(Dispatchers.Main).launch {
                    try {
                        // Update all NotesWidget instances
                        NotesWidget().updateAll(this@MemoInputActivity)
                        Log.d(TAG, "Widget refreshed")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to refresh widget", e)
                    }
                    Toast.makeText(this@MemoInputActivity, "Memo saved ✓", Toast.LENGTH_SHORT).show()
                    finish()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save memo", e)
                CoroutineScope(Dispatchers.Main).launch {
                    Toast.makeText(this@MemoInputActivity, "Failed to save memo", Toast.LENGTH_SHORT).show()
                    finish()
                }
            }
        }
    }
}
