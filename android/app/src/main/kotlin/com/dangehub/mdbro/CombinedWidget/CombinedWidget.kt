package com.dangehub.mdbro

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.CheckBox
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import org.json.JSONArray
import java.io.File

/**
 * Combined Widget that displays both Tasks and Memos in a split view.
 * Top section: Tasks (from ObsiWidget data)
 * Bottom section: Memos (from NotesWidget data)
 */
class CombinedWidget : GlanceAppWidget() {
    private val TAG = "CombinedWidget"

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
        // Auto-refresh memos data before displaying
        refreshMemosIfNeeded(context, id)
        
        provideContent {
            GlanceContent(context, currentState())
        }
    }

    /**
     * Automatically refreshes memos data from the vault when the widget is updated.
     */
    private suspend fun refreshMemosIfNeeded(context: Context, glanceId: GlanceId) {
        try {
            updateAppWidgetState(context, HomeWidgetGlanceStateDefinition(), glanceId) { state: HomeWidgetGlanceState ->
                val prefs = state.preferences
                val vaultDir = prefs.getString(NotesWidget.NOTES_VAULT_DIR_KEY, null)
                
                if (vaultDir.isNullOrEmpty()) {
                    Log.d(TAG, "No vault directory configured, skipping memo refresh")
                    return@updateAppWidgetState state
                }

                val bookmarksFile = BookmarksRefreshHelper.findBookmarksFile(vaultDir)
                if (bookmarksFile == null) {
                    Log.d(TAG, "Bookmarks file not found, skipping refresh")
                    return@updateAppWidgetState state
                }

                Log.d(TAG, "Auto-refreshing memos from: ${bookmarksFile.absolutePath}")
                val existingJson = prefs.getString(NotesWidget.NOTES_JSON_KEY, null)
                val updatedJson = BookmarksRefreshHelper.refreshBookmarks(bookmarksFile, existingJson)
                
                prefs.edit()
                    .putString(NotesWidget.NOTES_JSON_KEY, updatedJson)
                    .apply()

                state
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to auto-refresh memos", e)
        }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        val prefs = currentState.preferences
        
        // Load Tasks data
        val tasksString = prefs.getString(ObsiWidget.TASKS_JSON_KEY, null)
        val tasks = if (!tasksString.isNullOrEmpty()) {
            try {
                ObsiWidget.parseTasksFromState(tasksString)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to parse tasks", e)
                emptyList()
            }
        } else {
            emptyList()
        }
        
        // Load Memos data
        val notesJson = prefs.getString(NotesWidget.NOTES_JSON_KEY, null)
        val vaultDir = prefs.getString(NotesWidget.NOTES_VAULT_DIR_KEY, null)
        
        val memos = if (!notesJson.isNullOrEmpty() && !vaultDir.isNullOrEmpty()) {
            try {
                val notes = parseNotes(notesJson, vaultDir)
                if (notes.isNotEmpty()) {
                    val content = readNoteContent(vaultDir, notes.first().fileName)
                    if (content != null) parseMemos(content) else emptyList()
                } else {
                    emptyList()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to parse memos", e)
                emptyList()
            }
        } else {
            emptyList()
        }
        
        val noteFileName = if (!notesJson.isNullOrEmpty() && !vaultDir.isNullOrEmpty()) {
            try {
                val notes = parseNotes(notesJson, vaultDir)
                notes.firstOrNull()?.fileName
            } catch (e: Exception) {
                null
            }
        } else {
            null
        }
        
        WidgetContent(context, tasks, memos, vaultDir, noteFileName)
    }

    @Composable
    private fun WidgetContent(
        context: Context,
        tasks: List<TaskWrapper>,
        memos: List<MemoItem>,
        vaultDir: String?,
        noteFileName: String?
    ) {
        val backgroundColor = getWidgetBackgroundColor()
        val fontColor = getFontColor()
        val secondaryColor = GlanceTheme.colors.secondary

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(backgroundColor)
                .padding(horizontal = 12.dp, vertical = 10.dp)
        ) {
            // Header
            buildCaption(fontColor, vaultDir, noteFileName)
            
            // Tasks Section (upper half)
            Column(
                modifier = GlanceModifier
                    .defaultWeight()
                    .fillMaxWidth()
            ) {
                Text(
                    text = "☑ Tasks",
                    style = TextStyle(
                        color = secondaryColor,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    ),
                    modifier = GlanceModifier.padding(bottom = 2.dp)
                )
                
                LazyColumn(
                    modifier = GlanceModifier.fillMaxWidth()
                ) {
                    if (tasks.isEmpty()) {
                        item {
                            Text(
                                text = "No tasks",
                                style = TextStyle(color = fontColor, fontSize = 14.sp),
                                modifier = GlanceModifier.padding(vertical = 4.dp)
                            )
                        }
                    } else {
                        items(tasks.size) { index ->
                            RowWithCheckbox(tasks[index], fontColor)
                        }
                    }
                }
            }
            
            // Divider
            Spacer(modifier = GlanceModifier.height(4.dp))
            
            // Memos Section (lower half)
            Column(
                modifier = GlanceModifier
                    .defaultWeight()
                    .fillMaxWidth()
            ) {
                Text(
                    text = "✏ Memos",
                    style = TextStyle(
                        color = secondaryColor,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    ),
                    modifier = GlanceModifier.padding(bottom = 2.dp)
                )
                
                LazyColumn(
                    modifier = GlanceModifier.fillMaxWidth()
                ) {
                    if (memos.isEmpty()) {
                        item {
                            Text(
                                text = "No memos today",
                                style = TextStyle(color = fontColor, fontSize = 14.sp),
                                modifier = GlanceModifier.padding(vertical = 4.dp)
                            )
                        }
                    } else {
                        items(memos.size) { index ->
                            val memo = memos[index]
                            Row(
                                modifier = GlanceModifier
                                    .fillMaxWidth()
                                    .padding(vertical = 2.dp)
                            ) {
                                Text(
                                    text = memo.time,
                                    style = TextStyle(
                                        color = secondaryColor,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Medium
                                    ),
                                    modifier = GlanceModifier.padding(end = 8.dp)
                                )
                                Text(
                                    text = memo.content,
                                    style = TextStyle(color = fontColor, fontSize = 14.sp),
                                    maxLines = 1
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun buildCaption(fontColor: ColorProvider, vaultDir: String?, noteFileName: String?) {
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val launchAppAction = actionStartActivity(MainActivity::class.java)
            Image(
                provider = ImageProvider(resId = R.mipmap.ic_launcher),
                contentDescription = "App icon",
                modifier = GlanceModifier
                    .height(24.dp)
                    .width(24.dp)
                    .clickable(launchAppAction)
            )
            Text(
                text = "MD Bro",
                modifier = GlanceModifier
                    .padding(start = 6.dp, end = 8.dp)
                    .clickable(launchAppAction),
                style = TextStyle(
                    color = fontColor,
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp
                )
            )
            Spacer(modifier = GlanceModifier.defaultWeight())
            
            // Add Task button (checkbox icon)
            Image(
                provider = ImageProvider(resId = R.drawable.ic_todo),
                contentDescription = "Add task",
                modifier = GlanceModifier
                    .height(28.dp)
                    .width(28.dp)
                    .padding(end = 4.dp)
                    .clickable(actionRunCallback<AddTaskActionCallback>())
            )
            
            // Add Memo button
            val plusAction = if (!vaultDir.isNullOrEmpty() && !noteFileName.isNullOrEmpty()) {
                val params = actionParametersOf(
                    ActionParameters.Key<String>(AddMemoActionCallback.VAULT_DIR_KEY) to vaultDir,
                    ActionParameters.Key<String>(AddMemoActionCallback.NOTE_FILE_KEY) to noteFileName
                )
                actionRunCallback<AddMemoActionCallback>(params)
            } else {
                actionRunCallback<OpenNotesConfigActionCallback>()
            }
            // Add Memo button (pencil icon)
            Image(
                provider = ImageProvider(resId = R.drawable.ic_pencil),
                contentDescription = "Add memo",
                modifier = GlanceModifier
                    .height(28.dp)
                    .width(28.dp)
                    .clickable(plusAction)
            )
        }
    }

    @Composable
    private fun RowWithCheckbox(task: TaskWrapper, fontColor: ColorProvider) {
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(vertical = 2.dp)
        ) {
            val checkboxParams = actionParametersOf(
                ActionParameters.Key<String>(TaskCheckActionCallback.TASK_JSON_KEY) to task.toJsonObject().toString(),
                ActionParameters.Key<Boolean>(TaskCheckActionCallback.NEW_STATUS_KEY) to (task.status != "done")
            )

            CheckBox(
                checked = task.status == "done",
                onCheckedChange = actionRunCallback<TaskCheckActionCallback>(checkboxParams)
            )
            Text(
                text = task.description,
                modifier = GlanceModifier.padding(start = 4.dp),
                style = TextStyle(color = fontColor, fontSize = 14.sp),
                maxLines = 1
            )
        }
    }

    // === Memo parsing helpers (copied from NotesWidget) ===
    
    data class NoteWrapper(
        val fileName: String,
        val displayTitle: String
    )
    
    data class MemoItem(
        val time: String,
        val content: String
    )
    
    private fun parseNotes(notesJson: String?, vaultDir: String?): List<NoteWrapper> {
        val result = mutableListOf<NoteWrapper>()
        if (!notesJson.isNullOrEmpty()) {
            val array = JSONArray(notesJson)
            for (i in 0 until array.length()) {
                val element = array.get(i)
                val rawFile = when (element) {
                    is String -> element
                    is org.json.JSONObject -> element.optString("file", null)
                    else -> null
                } ?: continue
                
                val resolvedFile = if (VariableResolver.hasVariables(rawFile)) {
                    VariableResolver.resolve(rawFile)
                } else {
                    rawFile
                }
                
                val display = resolvedFile.substringAfterLast('/').removeSuffix(".md")
                result.add(NoteWrapper(fileName = resolvedFile, displayTitle = display))
            }
        }
        return result
    }
    
    private fun readNoteContent(vaultDir: String?, fileName: String): String? {
        if (vaultDir.isNullOrEmpty()) return null
        val fullPath = when {
            fileName.startsWith("/") -> fileName
            fileName.endsWith(".md") -> "$vaultDir/$fileName"
            else -> "$vaultDir/$fileName.md"
        }
        val file = File(fullPath)
        return try {
            if (file.exists() && file.canRead()) file.readText() else null
        } catch (e: Exception) {
            Log.e(TAG, "Error reading file: $fullPath", e)
            null
        }
    }
    
    private fun parseMemos(content: String): List<MemoItem> {
        val memoPattern = Regex("""^-\s+(\d{1,2}:\d{2}(?::\d{2})?)\s+(.+)$""", RegexOption.MULTILINE)
        return memoPattern.findAll(content).map { match ->
            MemoItem(time = match.groupValues[1], content = match.groupValues[2])
        }.toList()
    }
}
