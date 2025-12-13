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

        val notes = try {
            parseNotes(notesJson)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse notes JSON", e)
            emptyList()
        }
        Log.w(TAG, "Notes: $notes")
        WidgetContent(context, notes, vaultName)
    }

    @Composable
    private fun WidgetContent(context: Context, notes: List<NoteWrapper>, vaultName: String?) {
        val backgroundColor = getWidgetBackgroundColor()
        val fontColor = getFontColor()

        Column(
            modifier = GlanceModifier
                .background(backgroundColor)
                .padding(horizontal = 12.dp, vertical = 10.dp)
        ) {
            buildCaption(fontColor, vaultName)

            if (notes.isEmpty() || vaultName.isNullOrEmpty()) {
                // Empty / not configured state: tap anywhere to open config in Obsi
                Column(
                    modifier = GlanceModifier
                        .padding(top = 8.dp)
                        .clickable(actionRunCallback<OpenNotesConfigActionCallback>())
                ) {
                    Text(
                        text = "Tap to configure notes widget",
                        style = TextStyle(
                            color = fontColor,
                            fontSize = 16.sp
                        )
                    )
                }
            } else {
                LazyColumn(
                    modifier = GlanceModifier
                        .padding(top = 4.dp, start = 2.dp, end = 2.dp)
                ) {
                    items(notes.size) { index ->
                        val note = notes[index]
                        val params = actionParametersOf(
                            ActionParameters.Key<String>(OpenNoteActionCallback.NOTE_FILE_NAME_KEY) to note.fileName,
                            ActionParameters.Key<String>(OpenNoteActionCallback.NOTE_VAULT_NAME_KEY) to vaultName!!
                        )
                        Row(
                            modifier = GlanceModifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp)
                                .clickable(actionRunCallback<OpenNoteActionCallback>(params))
                        ) {
                            Text(
                                text = note.displayTitle,
                                style = TextStyle(
                                    color = fontColor,
                                    fontSize = 16.sp
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun buildCaption(fontColor: ColorProvider, vaultName: String?) {
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
                text = "Notes",
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
            // Refresh button to load bookmarks from Obsidian vault
            val refreshAction = actionRunCallback<RefreshBookmarksActionCallback>()
            Image(
                provider = ImageProvider(resId = R.drawable.circular_refresh_button),
                contentDescription = "Refresh bookmarks",
                modifier = GlanceModifier
                    .height(32.dp)
                    .width(32.dp)
                    .padding(end = 4.dp)
                    .clickable(refreshAction)
            )
            // Plus button to create a new note in Obsidian
            val plusAction = if (!vaultName.isNullOrEmpty()) {
                val params = actionParametersOf(
                    ActionParameters.Key<String>(CreateNoteActionCallback.NOTE_VAULT_NAME_KEY) to vaultName
                )
                actionRunCallback<CreateNoteActionCallback>(params)
            } else {
                actionRunCallback<OpenNotesConfigActionCallback>()
            }
            Image(
                provider = ImageProvider(resId = R.drawable.circular_add_button),
                contentDescription = "Add note",
                modifier = GlanceModifier
                    .height(32.dp)
                    .width(32.dp)
                    .clickable(plusAction)
            )
        }
    }

    private fun parseNotes(notesJson: String?): List<NoteWrapper> {
        val result = mutableListOf<NoteWrapper>()

        if (!notesJson.isNullOrEmpty()) {
            val array = JSONArray(notesJson)
            for (i in 0 until array.length()) {
                val element = array.get(i)
                if (element is String) {
                    // Legacy format: simple string path without bookmark flag
                    val file = element
                    val display = extractDisplayTitle(file)
                    result.add(NoteWrapper(fileName = file, displayTitle = display, bookmark = false))
                } else if (element is org.json.JSONObject) {
                    val file = element.optString("file", null)
                    if (!file.isNullOrEmpty()) {
                        val isBookmark = if (element.has("bookmark")) {
                            element.optBoolean("bookmark", false)
                        } else {
                            false
                        }
                        val display = extractDisplayTitle(file)
                        result.add(NoteWrapper(fileName = file, displayTitle = display, bookmark = isBookmark))
                    }
                }
            }
        }

        return result
    }

    private fun extractDisplayTitle(filePath: String): String {
        val nameWithExt = filePath.substringAfterLast('/')
        return nameWithExt.removeSuffix(".md")
    }

    data class NoteWrapper(val fileName: String, val displayTitle: String, val bookmark: Boolean)

    companion object {
        const val NOTES_JSON_KEY = "notes_widget_notes"
        const val NOTES_VAULT_KEY = "notes_widget_vault_name"
        const val NOTES_VAULT_DIR_KEY = "notes_widget_vault_directory"
    }
}
