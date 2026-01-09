package com.dangehub.mdbro

import android.util.Log
import org.json.JSONArray
import java.io.File

/**
 * Helper class for refreshing bookmarks from Obsidian vault.
 * Provides shared functionality for both widget auto-refresh and manual refresh actions.
 */
object BookmarksRefreshHelper {
    private const val TAG = "BookmarksRefreshHelper"

    /**
     * Finds the bookmarks.json file by traversing up the directory tree from the given vault directory.
     * Checks if vaultDir contains .obsidian/bookmarks.json, and if not, goes one level up and checks again
     * until it finds the file or reaches the root directory.
     *
     * @param vaultDir The starting vault directory path
     * @return The File object pointing to bookmarks.json if found, null otherwise
     */
    fun findBookmarksFile(vaultDir: String): File? {
        var currentDir = File(vaultDir)
        
        // Traverse up the directory tree until we find bookmarks.json or reach the root
        while (currentDir.parent != null) {
            val bookmarksFile = File(currentDir, ".obsidian/bookmarks.json")
            Log.d(TAG, "Checking for bookmarks at: ${bookmarksFile.absolutePath}")
            
            if (bookmarksFile.exists()) {
                Log.d(TAG, "Found bookmarks file at: ${bookmarksFile.absolutePath}")
                return bookmarksFile
            }
            
            // Move one level up
            currentDir = currentDir.parentFile ?: break
        }
        
        Log.w(TAG, "Bookmarks file not found in directory tree starting from: $vaultDir")
        return null
    }

    /**
     * Refreshes bookmarks by reading from the bookmarks.json file and merging with existing notes.
     * 
     * @param bookmarksFile The bookmarks.json file to read from
     * @param existingNotesJson The existing notes JSON string (can be null)
     * @return The updated combined JSON array as a string
     */
    fun refreshBookmarks(bookmarksFile: File, existingNotesJson: String?): String {
        val json = bookmarksFile.readText()
        Log.d(TAG, "Bookmarks file content: $json")
        
        val parser = BookmarksParser()
        val bookmarks = parser.parse(json)
        Log.d(TAG, "Parsed bookmarks: $bookmarks")

        // We store notes as a JSON array of objects with fields:
        // { "file": string, "bookmark": bool }
        val combinedArray = JSONArray()
        
        // Parse existing notes
        if (!existingNotesJson.isNullOrEmpty()) {
            try {
                val existingArray = JSONArray(existingNotesJson)
                for (i in 0 until existingArray.length()) {
                    val element = existingArray.get(i)
                    when (element) {
                        is String -> {
                            // Legacy string entry -> convert to object with bookmark=false
                            val obj = org.json.JSONObject()
                            obj.put("file", element)
                            obj.put("bookmark", false)
                            combinedArray.put(obj)
                        }
                        is org.json.JSONObject -> {
                            val file = element.optString("file", null)
                            if (!file.isNullOrEmpty()) {
                                if (!element.has("bookmark")) {
                                    element.put("bookmark", false)
                                }
                                combinedArray.put(element)
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to parse existing notes JSON, ignoring existing entries", e)
            }
        }

        // Helper to check if a file path is already present in combinedArray
        fun alreadyContainsFile(filePath: String): Boolean {
            for (i in 0 until combinedArray.length()) {
                val element = combinedArray.get(i)
                if (element is org.json.JSONObject) {
                    val file = element.optString("file", null)
                    if (file == filePath) return true
                }
            }
            return false
        }

        // Append bookmarks as objects with bookmark=true, avoiding duplicates by file path
        for (bookmark in bookmarks) {
            val filePath = bookmark.path.removeSuffix(".md")
            if (alreadyContainsFile(filePath)) continue
            Log.d(TAG, "Adding bookmark path: $filePath")
            val obj = org.json.JSONObject()
            obj.put("file", filePath)
            obj.put("bookmark", true)
            combinedArray.put(obj)
        }

        Log.d(TAG, "Combined array: $combinedArray")
        return combinedArray.toString()
    }
}
