package com.scanworks.obsi
import org.json.JSONObject

data class TaskWrapper(
      val description: String = "",
    val status: String = "todo",
    val priority: String = "normal",
    val created: String? = null,
    val done: String? = null,
    val cancelled: String? = null,
    val due: String? = null,
    val start: String? = null,
    val scheduled: String? = null,
    val recurrenceRule: String? = null,
    val filePath: String? = null,
    val fileOffset: String? = null
) {
    fun toJsonObject(): JSONObject {
        return JSONObject().apply {
            put("description", description)
            put("status", status)
            put("priority", priority)
            put("created", created)
            put("done", done)
            put("cancelled", cancelled)
            put("due", due)
            put("start", start)
            put("scheduled", scheduled)
            put("recurrenceRule", recurrenceRule)
            put("filePath", filePath)
            put("fileOffset", fileOffset)
        }
    }

      /**
     * Finds the task in the file at [filePath] using [fileOffset] and changes its status to done ([x]) or in progress ([ ]).
     * @param done true for done ([x]), false for in progress ([ ])
     * Returns true if the update was successful, false otherwise.
     */
    fun updateTaskStatusInFile(done: Boolean): Boolean {
        val TAG = "TaskWrapper"
        if (filePath.isNullOrEmpty() || fileOffset.isNullOrEmpty()) {
            android.util.Log.w(TAG, "filePath or fileOffset is null or empty: filePath=$filePath, fileOffset=$fileOffset")
            return false
        }
        try {
            val file = java.io.File(filePath)
            if (!file.exists()) {
                android.util.Log.w(TAG, "File does not exist: $filePath")
                return false
            }
            val content = file.readText()
            val offset = fileOffset.toIntOrNull() ?: run {
                android.util.Log.w(TAG, "fileOffset is not a valid integer: $fileOffset")
                return false
            }
            if (offset < 0 || offset >= content.length) {
                android.util.Log.w(TAG, "Offset out of bounds: $offset (content length: ${content.length})")
                return false
            }

            // Search for the markdown task substring starting from the offset
            val statusRegex = Regex("- \\[([ xX])\\]")
            val startIdx = content.indexOf('-', offset)
            if (startIdx == -1) {
                android.util.Log.w(TAG, "No '-' found after offset $offset in file $filePath")
                return false
            }
            val matcher = statusRegex.find(content, startIdx)
            if (matcher == null) {
                android.util.Log.w(TAG, "No markdown task status found after offset $offset in file $filePath")
                return false
            }

            // Find the line containing the match
            val before = content.substring(0, matcher.range.first)
            val lineStart = before.lastIndexOf('\n') + 1
            val lineEnd = content.indexOf('\n', matcher.range.first)
            val lineEndFinal = if (lineEnd == -1) content.length else lineEnd
            val line = content.substring(lineStart, lineEndFinal)

            android.util.Log.d(TAG, "Original line: '$line'")

            // Update the status in the found line
            val newLine = updateLineWithStatus(line, done, statusRegex)

            android.util.Log.d(TAG, "Updated line: '$newLine'")

            // Replace the line in the content
            val newContent = buildString {
                append(content.substring(0, lineStart))
                append(newLine)
                append(content.substring(lineEndFinal))
            }
            file.writeText(newContent)
            android.util.Log.i(TAG, "Task status updated in file: $filePath at offset $offset")
            return true
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Exception in updateTaskStatusInFile", e)
            return false
        }
    }
  
    companion object {
    private fun updateLineWithStatus(line: String, done: Boolean, statusRegex: Regex): String {
        return if (done) {
            // Add done date in yyyy-MM-dd format with prefix ✅ at the end
            val date = java.time.LocalDate.now().toString()
            // Remove any previous done mark and date (if present)
            val lineNoDate = line.replace(Regex("\\s*✅ \\d{4}-\\d{2}-\\d{2}$"), "")
            lineNoDate.replace(statusRegex, "- [x]") + " ✅ $date"
        } else {
            // Remove any done mark and date if unchecking
            line.replace(statusRegex, "- [ ]").replace(Regex("\\s*✅ \\d{4}-\\d{2}-\\d{2}$"), "")
        }
    }
        fun fromJson(obj: JSONObject): TaskWrapper {
            return TaskWrapper(
                description = obj.optString("description", ""),
                status = obj.optString("status", "todo"),
                priority = obj.optString("priority", "normal"),
                created = obj.optString("created", null),
                done = obj.optString("done", null),
                cancelled = obj.optString("cancelled", null),
                due = obj.optString("due", null),
                start = obj.optString("start", null),
                scheduled = obj.optString("scheduled", null),
                recurrenceRule = obj.optString("recurrenceRule", null),
                filePath = obj.optString("filePath", null),
                fileOffset = obj.optString("fileOffset", null)
            )
        }
    }
}