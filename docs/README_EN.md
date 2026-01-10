<div align="center">

<img src="../assets/images/icon.png" width="80" />

# MD Bro
### An Enhanced Android Companion for Obsidian

[![Platform](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

<p align="center">
  <b>Focused on Memos-style Microblogging & Enhanced Task Management</b><br>
  Local-first · Privacy-focused · Open Source
</p>

</div>

---

## � Introduction

**MD Bro** is an Android companion tool designed specifically for Obsidian users, addressing the gap in mobile quick capture and task management. It is not intended to replace the full Obsidian mobile app but serves as a **lightweight, high-performance companion** to help you capture thoughts and manage to-dos efficiently.

This project is a fork of [VaultMate](https://github.com/vankir/VaultMate), with significant enhancements tailored for power users, especially introducing a **Memos** or **Thino**-like fragmented note-taking experience.

---

## ✨ Key Features

### 1. 📝 Memos (Microblogging)
The core enhancement of MD Bro, delivering a smooth microblogging experience:

*   **⚡ Quick Capture**: 
    *   **Widget Support**: One-tap access from your home screen.
    *   **Lightweight Input**: Tap `+` to open a transparent, fast-loading input dialog without launching the full app.
*   **⏱️ Auto-Timestamp**: 
    *   Automatically appends entries with `- HH:mm` format, perfectly compatible with Obsidian Daily Notes.
    *   Supports custom prefixes and time formats.
*   **🖼️ Image Management**:
    *   **Attachments**: Pick images from your gallery directly.
    *   **Auto-Compression**: Built-in compression to save vault space.
    *   **Thumbnails**: Visual management of attached images during editing.
    *   **One-Click Insert**: Tap a thumbnail to insert its `![[]]` link at the cursor.
    *   **File Deletion**: Delete physical image files from inside the app to keep your vault clean.
*   **✏️ Seamless Editing**:
    *   Double-tap any memo card to enter edit mode.
    *   Modify content, fix links, or manage images instantly.
*   **📅 Dynamic Paths**:
    *   Supports variables like `{{YYYY}}`, `{{MM}}`, `{{DD}}` to automatically file memos into specific folders (e.g., `Daily Notes/2024-01-01.md`).

### 2. ✅ Enhanced Task Management
More powerful than the original VaultMate implementation:

*   **🔍 Advanced Filters**: 
    *   Save custom filter sets (e.g., ` #todo` + `Incomplete`).
*   **📱 Home Screen Widgets**: 
    *   Pin filtered task lists (like "Today's Tasks") to your desktop.
    *   Widget titles update dynamically based on the active filter.

### 3. 🗓️ Calendar & Navigation
*   **Timeline View**: Visualize daily memos in a scrollable timeline.
*   **Calendar Jump**: Built-in calendar picker to quickly jump to past records.

### 4. 🔒 Security & Privacy
*   **Local-First**: Directly reads/writes local Obsidian vault files. No cloud upload.
*   **Open Source**: Fully transparent code for your peace of mind.

---

## 📥 Installation & Setup

### Vault Configuration
1.  **Grant Access**: On first launch, grant "All Files Access" to allow reading/writing your Obsidian vault.
2.  **Select Path**: In Settings, tap "Select Vault Path" and locate your Obsidian Vault root.
3.  **Configure Memos**:
    *   Set **Memos File Pattern** (e.g., `Daily/{{YYYY-MM-DD}}.md`).
    *   Set **Attachment Path**.

### Adding Widgets
1.  Long-press on your Android home screen and select **Widgets**.
2.  Find **MD Bro**.
3.  Drag **Memos Widget** or **Tasks Widget** to your screen.
4.  For Tasks Widget, you can select a preset filter to display.

---

## 📸 Screenshots

<div align="center">
  <img src="screenshots/memos.png" width="30%" alt="Memos Interface" />
  <img src="screenshots/filters.png" width="30%" alt="Filter Settings" />
</div>

---

## 🤝 Contributing

Issues and Pull Requests are welcome!

*   **Source Code**: [GitHub](https://github.com/dangehub/md-bro)
*   **Upstream**: [VaultMate](https://github.com/vankir/VaultMate)

---

## ⚖️ License
Licensed under the **GNU GPLv3**.
