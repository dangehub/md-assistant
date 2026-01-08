package com.scanworks.obsi

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProviders
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.appwidget.state.updateAppWidgetState
import org.json.JSONArray
import java.io.File

class NotesWidget : GlanceAppWidget() {
    private val TAG = "NotesWidget"

    override val sizeMode = SizeMode.Single
    override val stateDefinition: GlanceStateDefinition<*>
        get() = HomeWidgetGlanceStateDefinition()

    @Composable
    private fun getWidgetBackgroundColor(): ColorProvider {
        return GlanceTheme.colors.background
    }

    @Composable
    private fun getFontColor(): ColorProvider {
        return GlanceTheme.colors.onBackground
    }

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // Automatically refresh bookmarks before displaying widget
        refreshBookmarksIfNeeded(context, id)
        
        provideContent {
            GlanceContent(context, currentState())
        }
    }

    /**
     * Automatically refreshes bookmarks from the vault when the widget is updated.
     */
    private suspend fun refreshBookmarksIfNeeded(context: Context, glanceId: GlanceId) {
        try {
            updateAppWidgetState(context, HomeWidgetGlanceStateDefinition(), glanceId) { state: HomeWidgetGlanceState ->
                val prefs = state.preferences
                val vaultDir = prefs.getString(NOTES_VAULT_DIR_KEY, null)
                
                if (vaultDir.isNullOrEmpty()) {
                    Log.d(TAG, "No vault directory configured, skipping bookmark refresh")
                    return@updateAppWidgetState state
                }

                val bookmarksFile = BookmarksRefreshHelper.findBookmarksFile(vaultDir)
                if (bookmarksFile == null) {
                    Log.d(TAG, "Bookmarks file not found, skipping refresh")
                    return@updateAppWidgetState state
                }

                Log.d(TAG, "Auto-refreshing bookmarks from: ${bookmarksFile.absolutePath}")
                val existingJson = prefs.getString(NOTES_JSON_KEY, null)
                val updatedJson = BookmarksRefreshHelper.refreshBookmarks(bookmarksFile, existingJson)
                
                Log.d(TAG, "Auto-refresh complete")
                prefs.edit()
                    .putString(NOTES_JSON_KEY, updatedJson)
                    .apply()

                state
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to auto-refresh bookmarks", e)
        }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        val prefs = currentState.preferences
        val notesJson = prefs.getString(NOTES_JSON_KEY, null)
        val vaultName = prefs.getString(NOTES_VAULT_KEY, null)

        Log.d(TAG, "GlanceContent notesJson=$notesJson vaultName=$vaultName")

        val vaultDir = prefs.getString(NOTES_VAULT_DIR_KEY, null)

        val notes = try {
            parseNotes(notesJson, vaultDir)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse notes JSON", e)
            emptyList()
        }
        Log.w(TAG, "Notes: $notes")
        
        // For memos widget, we focus on the first note and parse its memos
        val memos = if (notes.isNotEmpty() && !vaultDir.isNullOrEmpty()) {
            val firstNote = notes.first()
            Log.d(TAG, "Reading content for: ${firstNote.fileName}")
            val content = readNoteContent(vaultDir, firstNote.fileName)
            Log.d(TAG, "Content length: ${content?.length ?: 0}")
            if (content != null) {
                val parsed = parseMemos(content)
                Log.d(TAG, "Parsed ${parsed.size} memos")
                parsed
            } else {
                Log.w(TAG, "Content is null")
                emptyList()
            }
        } else {
            emptyList()
        }
        
        Log.d(TAG, "Total memos to display: ${memos.size}")
        val noteTitle = if (notes.isNotEmpty()) notes.first().displayTitle else null
        
        WidgetContent(context, memos, noteTitle, vaultName, vaultDir, notes.firstOrNull()?.fileName)
    }

    @Composable
    private fun WidgetContent(
        context: Context, 
        memos: List<MemoItem>, 
        noteTitle: String?,
        vaultName: String?,
        vaultDir: String?,
        noteFileName: String?
    ) {
        val backgroundColor = getWidgetBackgroundColor()
        val fontColor = getFontColor()
        val secondaryColor = GlanceTheme.colors.secondary

        Column(
            modifier = GlanceModifier
                .background(backgroundColor)
                .padding(horizontal = 12.dp, vertical = 10.dp)
        ) {
            buildCaption(fontColor, vaultName, vaultDir, noteFileName)

            if (vaultDir.isNullOrEmpty() || noteFileName.isNullOrEmpty()) {
                // Not configured state
                Column(
                    modifier = GlanceModifier
                        .padding(top = 8.dp)
                        .clickable(actionRunCallback<OpenNotesConfigActionCallback>())
                ) {
                    Text(
                        text = "Tap to configure memos widget",
                        style = TextStyle(
                            color = fontColor,
                            fontSize = 16.sp
                        )
                    )
                }
            } else if (memos.isEmpty()) {
                // No memos found
                Column(
                    modifier = GlanceModifier
                        .padding(top = 8.dp)
                ) {
                    Text(
                        text = "No memos today",
                        style = TextStyle(
                            color = fontColor,
                            fontSize = 14.sp
                        )
                    )
                    Text(
                        text = "Tap + to add one",
                        style = TextStyle(
                            color = secondaryColor,
                            fontSize = 12.sp
                        )
                    )
                }
            } else {
                // Display memos list
                LazyColumn(
                    modifier = GlanceModifier
                        .padding(top = 4.dp)
                ) {
                    items(memos.size) { index ->
                        val memo = memos[index]
                        Row(
                            modifier = GlanceModifier
                                .fillMaxWidth()
                                .padding(vertical = 3.dp)
                        ) {
                            // Time badge
                            Text(
                                text = memo.time,
                                style = TextStyle(
                                    color = secondaryColor,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Medium
                                ),
                                modifier = GlanceModifier.padding(end = 8.dp)
                            )
                            // Memo content
                            Text(
                                text = memo.content,
                                style = TextStyle(
                                    color = fontColor,
                                    fontSize = 14.sp
                                ),
                                maxLines = 2
                            )
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun buildCaption(fontColor: ColorProvider, vaultName: String?, vaultDir: String?, noteFileName: String?) {
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val configureAction = actionRunCallback<OpenNotesConfigActionCallback>()
            Image(
                provider = ImageProvider(resId = R.drawable.ic_launcher),
                contentDescription = "Obsi icon",
                modifier = GlanceModifier
                    .height(24.dp)
                    .width(24.dp)
                    .clickable(configureAction)
            )
            Text(
                text = "Memos",
                modifier = GlanceModifier
                    .padding(start = 6.dp, end = 8.dp)
                    .clickable(configureAction),
                style = TextStyle(
                    color = fontColor,
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp
                )
            )
            Spacer(modifier = GlanceModifier.defaultWeight())
            // Refresh button
            val refreshAction = actionRunCallback<RefreshBookmarksActionCallback>()
            Image(
                provider = ImageProvider(resId = R.drawable.circular_refresh_button),
                contentDescription = "Refresh",
                modifier = GlanceModifier
                    .height(32.dp)
                    .width(32.dp)
                    .padding(end = 4.dp)
                    .clickable(refreshAction)
            )
            // Plus button to add a new memo
            val plusAction = if (!vaultDir.isNullOrEmpty() && !noteFileName.isNullOrEmpty()) {
                val params = actionParametersOf(
                    ActionParameters.Key<String>(AddMemoActionCallback.VAULT_DIR_KEY) to vaultDir,
                    ActionParameters.Key<String>(AddMemoActionCallback.NOTE_FILE_KEY) to noteFileName
                )
                actionRunCallback<AddMemoActionCallback>(params)
            } else {
                actionRunCallback<OpenNotesConfigActionCallback>()
            }
            Image(
                provider = ImageProvider(resId = R.drawable.circular_add_button),
                contentDescription = "Add memo",
                modifier = GlanceModifier
                    .height(32.dp)
                    .width(32.dp)
                    .clickable(plusAction)
            )
        }
    }

    private fun parseNotes(notesJson: String?, vaultDir: String?): List<NoteWrapper> {
        val result = mutableListOf<NoteWrapper>()

        if (!notesJson.isNullOrEmpty()) {
            val array = JSONArray(notesJson)
            for (i in 0 until array.length()) {
                val element = array.get(i)
                val rawFile: String?
                val isBookmark: Boolean
                
                if (element is String) {
                    rawFile = element
                    isBookmark = false
                } else if (element is org.json.JSONObject) {
                    rawFile = element.optString("file", null)
                    isBookmark = element.optBoolean("bookmark", false)
                } else {
                    continue
                }
                
                if (rawFile.isNullOrEmpty()) continue
                
                // Resolve variables like {{YYYY-MM-DD}}
                val resolvedFile = if (VariableResolver.hasVariables(rawFile)) {
                    VariableResolver.resolve(rawFile)
                } else {
                    rawFile
                }
                
                val display = extractDisplayTitle(resolvedFile)
                
                // Check if file is accessible
                val accessStatus = checkFileAccess(vaultDir, resolvedFile)
                
                result.add(NoteWrapper(
                    fileName = resolvedFile, 
                    displayTitle = if (accessStatus == FileAccessStatus.OK) display else "$display ⚠️",
                    bookmark = isBookmark,
                    accessStatus = accessStatus,
                    originalPath = rawFile
                ))
            }
        }

        return result
    }
    
    enum class FileAccessStatus {
        OK,
        NOT_FOUND,
        NO_PERMISSION,
        VAULT_NOT_SET
    }
    
    private fun checkFileAccess(vaultDir: String?, fileName: String): FileAccessStatus {
        if (vaultDir.isNullOrEmpty()) {
            return FileAccessStatus.VAULT_NOT_SET
        }
        
        val fullPath = if (fileName.startsWith("/")) {
            fileName
        } else {
            "$vaultDir/$fileName.md"
        }
        
        val file = File(fullPath)
        
        return try {
            if (file.exists()) {
                if (file.canRead()) {
                    FileAccessStatus.OK
                } else {
                    Log.w(TAG, "No read permission for: $fullPath")
                    FileAccessStatus.NO_PERMISSION
                }
            } else {
                // Also try without .md extension for already-extensioned paths
                val altFile = File(fullPath.removeSuffix(".md"))
                if (altFile.exists() && altFile.canRead()) {
                    FileAccessStatus.OK
                } else {
                    Log.d(TAG, "File not found: $fullPath")
                    FileAccessStatus.NOT_FOUND
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception accessing: $fullPath", e)
            FileAccessStatus.NO_PERMISSION
        }
    }

    private fun extractDisplayTitle(filePath: String): String {
        val nameWithExt = filePath.substringAfterLast('/')
        return nameWithExt.removeSuffix(".md")
    }

    data class NoteWrapper(
        val fileName: String, 
        val displayTitle: String, 
        val bookmark: Boolean,
        val accessStatus: FileAccessStatus = FileAccessStatus.OK,
        val originalPath: String = fileName
    )
    
    /**
     * Represents a single memo entry parsed from the note.
     * Format: - HH:mm(:ss)? content
     */
    data class MemoItem(
        val time: String,
        val content: String,
        val rawLine: String
    )
    
    /**
     * Parses memo entries from note content.
     * Memos are lines matching: - HH:mm content or - HH:mm:ss content
     */
    private fun parseMemos(content: String): List<MemoItem> {
        val memoPattern = Regex("""^-\s+(\d{1,2}:\d{2}(?::\d{2})?)\s+(.+)$""", RegexOption.MULTILINE)
        val memos = mutableListOf<MemoItem>()
        
        memoPattern.findAll(content).forEach { match ->
            val time = match.groupValues[1]
            val text = match.groupValues[2]
            memos.add(MemoItem(time = time, content = text, rawLine = match.value))
        }
        
        return memos
    }
    
    /**
     * Reads the content of a note file.
     */
    private fun readNoteContent(vaultDir: String?, fileName: String): String? {
        if (vaultDir.isNullOrEmpty()) return null
        
        val fullPath = if (fileName.startsWith("/")) {
            fileName
        } else if (fileName.endsWith(".md")) {
            "$vaultDir/$fileName"
        } else {
            "$vaultDir/$fileName.md"
        }
        
        val file = File(fullPath)
        return try {
            if (file.exists() && file.canRead()) {
                file.readText()
            } else {
                Log.w(TAG, "Cannot read file: $fullPath")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading file: $fullPath", e)
            null
        }
    }

    companion object {
        const val NOTES_JSON_KEY = "notes_widget_notes"
        const val NOTES_VAULT_KEY = "notes_widget_vault_name"
        const val NOTES_VAULT_DIR_KEY = "notes_widget_vault_directory"
    }
}
