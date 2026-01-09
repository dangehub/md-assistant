package com.dangehub.mdbro

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Resolves {{variable}} placeholders in strings, supporting moment.js-like date tokens.
 */
object VariableResolver {
    private val variablePattern = Regex("""\{\{([^}]+)\}\}""")

    /**
     * Check if the template contains any variables.
     */
    fun hasVariables(template: String): Boolean {
        return variablePattern.containsMatchIn(template)
    }

    /**
     * Resolve all {{...}} variables in the template string.
     * @param template The template string containing variables
     * @param date The date to use for date variables (defaults to current date/time)
     */
    fun resolve(template: String, date: Date = Date()): String {
        if (template.isEmpty()) return template

        return variablePattern.replace(template) { matchResult ->
            val token = matchResult.groupValues[1]
            formatDate(token, date)
        }
    }

    /**
     * Convert moment.js-style tokens to actual date values.
     */
    private fun formatDate(format: String, date: Date): String {
        var result = format

        // Year
        result = result.replace("YYYY", SimpleDateFormat("yyyy", Locale.getDefault()).format(date))
        result = result.replace("YY", SimpleDateFormat("yy", Locale.getDefault()).format(date))

        // Month - order matters: longest first
        result = result.replace("MMMM", SimpleDateFormat("MMMM", Locale.getDefault()).format(date))
        result = result.replace("MMM", SimpleDateFormat("MMM", Locale.getDefault()).format(date))
        result = result.replace("MM", SimpleDateFormat("MM", Locale.getDefault()).format(date))

        // Day of month
        result = result.replace("DD", SimpleDateFormat("dd", Locale.getDefault()).format(date))

        // Day of week
        result = result.replace("dddd", SimpleDateFormat("EEEE", Locale.getDefault()).format(date))
        result = result.replace("ddd", SimpleDateFormat("EEE", Locale.getDefault()).format(date))

        // Hour
        result = result.replace("HH", SimpleDateFormat("HH", Locale.getDefault()).format(date))
        result = result.replace("hh", SimpleDateFormat("hh", Locale.getDefault()).format(date))

        // Minutes
        result = result.replace("mm", SimpleDateFormat("mm", Locale.getDefault()).format(date))

        // Seconds
        result = result.replace("ss", SimpleDateFormat("ss", Locale.getDefault()).format(date))

        // AM/PM
        result = result.replace("A", SimpleDateFormat("a", Locale.getDefault()).format(date).uppercase())
        result = result.replace("a", SimpleDateFormat("a", Locale.getDefault()).format(date))

        // Week of year
        result = result.replace("ww", SimpleDateFormat("ww", Locale.getDefault()).format(date))

        return result
    }
}
