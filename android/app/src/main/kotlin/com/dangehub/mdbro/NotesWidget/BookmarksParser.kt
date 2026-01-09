package com.dangehub.mdbro

import org.json.JSONArray
import org.json.JSONObject

data class BookmarkedNote(
    val path: String,
    val title: String,
    val ctime: Long
)

class BookmarksParser {

    /**
     * Parse JSON string and return list of bookmarked notes.
     * A "bookmarked note" is any object with:
     *   - "type": "file"
     *   - non-empty "title"
     *   - "path" and "ctime" fields
     */
    fun parse(json: String): List<BookmarkedNote> {
        val root = JSONObject(json)
        val result = mutableListOf<BookmarkedNote>()

        if (root.has("items")) {
            val items = root.getJSONArray("items")
            collectFromArray(items, result)
        }

        return result
    }

    private fun collectFromArray(array: JSONArray, result: MutableList<BookmarkedNote>) {
        for (i in 0 until array.length()) {
            val item = array.getJSONObject(i)
            collectFromItem(item, result)
        }
    }

    private fun collectFromItem(obj: JSONObject, result: MutableList<BookmarkedNote>) {
        val type = obj.optString("type", "")

        when (type) {
            "file" -> {
                val path = obj.optString("path", "")
                val title = obj.optString("title", "")
                if (path.isNotBlank() && obj.has("ctime")) {
                    val ctime = obj.getLong("ctime")
                    result.add(
                        BookmarkedNote(
                            path = path,
                            title = title,
                            ctime = ctime
                        )
                    )
                }
            }
            "group" -> {
                // Recurse into nested "items" inside the group
                if (obj.has("items")) {
                    val nested = obj.getJSONArray("items")
                    collectFromArray(nested, result)
                }
            }
            else -> {
                // ignore other types
            }
        }
    }
}