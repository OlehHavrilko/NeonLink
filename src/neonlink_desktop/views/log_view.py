"""
LogViewer - Widget for viewing and managing application logs.

Features:
- Real-time log display with color coding
- Filtering by level, source, and time range
- Full-text search
- Export to TXT, JSON, CSV
- Auto-scroll and manual navigation
"""

import asyncio
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, List

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QTableWidget, QTableWidgetItem,
    QPushButton, QLineEdit, QComboBox, QLabel, QHeaderView,
    QFileDialog, QMessageBox, QProgressDialog, QCheckBox,
    QGroupBox, QDateTimeEdit, QSpinBox, QSplitter, QTextEdit,
    QMenu, QApplication
)
from PyQt6.QtCore import Qt, QTimer, pyqtSignal, QDateTime, QThread
from PyQt6.QtGui import QColor, QAction, QFont, QTextCursor, QKeySequence

from models.log_entry import LogEntry, LogLevel
from services.database_service import DatabaseService, get_database_service


class LogLoaderThread(QThread):
    """Background thread for loading logs from database."""
    
    logs_loaded = pyqtSignal(list)
    error_occurred = pyqtSignal(str)
    progress_updated = pyqtSignal(int, int)  # current, total
    
    def __init__(
        self,
        db_service: DatabaseService,
        level: Optional[LogLevel] = None,
        source: Optional[str] = None,
        search_text: Optional[str] = None,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        limit: int = 1000,
    ):
        super().__init__()
        self.db_service = db_service
        self.level = level
        self.source = source
        self.search_text = search_text
        self.start_time = start_time
        self.end_time = end_time
        self.limit = limit
    
    def run(self):
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            logs = loop.run_until_complete(
                self.db_service.get_logs(
                    level=self.level,
                    source=self.source,
                    search_text=self.search_text,
                    start_time=self.start_time,
                    end_time=self.end_time,
                    limit=self.limit,
                )
            )
            
            self.logs_loaded.emit(logs)
            loop.close()
        except Exception as e:
            self.error_occurred.emit(str(e))


class LogViewer(QWidget):
    """
    Widget for viewing and managing application logs.
    
    Signals:
        log_selected: Emitted when a log entry is selected
    """
    
    log_selected = pyqtSignal(LogEntry)
    
    # Color scheme for log levels
    LEVEL_COLORS = {
        LogLevel.DEBUG: QColor("#808080"),    # Gray
        LogLevel.INFO: QColor("#00AA00"),      # Green
        LogLevel.WARNING: QColor("#FFAA00"),   # Orange/Yellow
        LogLevel.ERROR: QColor("#FF4444"),     # Red
        LogLevel.CRITICAL: QColor("#FF00FF"),  # Magenta
    }
    
    def __init__(self, parent: Optional[QWidget] = None):
        super().__init__(parent)
        
        self.db_service: Optional[DatabaseService] = None
        self.current_logs: List[LogEntry] = []
        self.auto_scroll = True
        self.loader_thread: Optional[LogLoaderThread] = None
        
        # Filter state
        self._filter_level: Optional[LogLevel] = None
        self._filter_source: Optional[str] = None
        self._filter_search: str = ""
        self._filter_start_time: Optional[datetime] = None
        self._filter_end_time: Optional[datetime] = None
        
        self._init_ui()
        self._init_timer()
    
    def _init_ui(self):
        """Initialize user interface."""
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        
        # Toolbar
        toolbar = self._create_toolbar()
        layout.addWidget(toolbar)
        
        # Filter panel
        filter_panel = self._create_filter_panel()
        layout.addWidget(filter_panel)
        
        # Main content - splitter between table and details
        splitter = QSplitter(Qt.Orientation.Vertical)
        
        # Log table
        self.log_table = QTableWidget()
        self.log_table.setColumnCount(5)
        self.log_table.setHorizontalHeaderLabels([
            "Timestamp", "Level", "Source", "Message", "Script ID"
        ])
        self.log_table.setAlternatingRowColors(True)
        self.log_table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.log_table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self.log_table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.log_table.customContextMenuRequested.connect(self._show_context_menu)
        self.log_table.itemSelectionChanged.connect(self._on_selection_changed)
        
        # Column sizing
        header = self.log_table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Fixed)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(3, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(4, QHeaderView.ResizeMode.ResizeToContents)
        
        self.log_table.setColumnWidth(1, 80)
        
        splitter.addWidget(self.log_table)
        
        # Details panel
        self.details_panel = QTextEdit()
        self.details_panel.setReadOnly(True)
        self.details_panel.setMaximumHeight(150)
        self.details_panel.setPlaceholderText("Select a log entry to view details")
        splitter.addWidget(self.details_panel)
        
        splitter.setSizes([400, 150])
        layout.addWidget(splitter)
        
        # Status bar
        status_layout = QHBoxLayout()
        
        self.status_label = QLabel("Ready")
        status_layout.addWidget(self.status_label)
        
        status_layout.addStretch()
        
        self.entry_count_label = QLabel("0 entries")
        status_layout.addWidget(self.entry_count_label)
        
        layout.addLayout(status_layout)
    
    def _create_toolbar(self) -> QWidget:
        """Create toolbar with action buttons."""
        toolbar = QWidget()
        toolbar_layout = QHBoxLayout(toolbar)
        toolbar_layout.setContentsMargins(5, 5, 5, 5)
        
        # Refresh button
        self.btn_refresh = QPushButton("🔄 Refresh")
        self.btn_refresh.clicked.connect(self.refresh_logs)
        toolbar_layout.addWidget(self.btn_refresh)
        
        # Auto-scroll checkbox
        self.chk_auto_scroll = QCheckBox("Auto-scroll")
        self.chk_auto_scroll.setChecked(True)
        self.chk_auto_scroll.toggled.connect(lambda v: setattr(self, 'auto_scroll', v))
        toolbar_layout.addWidget(self.chk_auto_scroll)
        
        toolbar_layout.addStretch()
        
        # Export buttons
        self.btn_export_txt = QPushButton("📄 TXT")
        self.btn_export_txt.setToolTip("Export to plain text")
        self.btn_export_txt.clicked.connect(lambda: self._export_logs('txt'))
        toolbar_layout.addWidget(self.btn_export_txt)
        
        self.btn_export_json = QPushButton("📋 JSON")
        self.btn_export_json.setToolTip("Export to JSON")
        self.btn_export_json.clicked.connect(lambda: self._export_logs('json'))
        toolbar_layout.addWidget(self.btn_export_json)
        
        self.btn_export_csv = QPushButton("📊 CSV")
        self.btn_export_csv.setToolTip("Export to CSV")
        self.btn_export_csv.clicked.connect(lambda: self._export_logs('csv'))
        toolbar_layout.addWidget(self.btn_export_csv)
        
        toolbar_layout.addSpacing(10)
        
        # Clear logs button
        self.btn_clear = QPushButton("🗑️ Clear")
        self.btn_clear.setToolTip("Clear all logs")
        self.btn_clear.clicked.connect(self._clear_logs)
        toolbar_layout.addWidget(self.btn_clear)
        
        return toolbar
    
    def _create_filter_panel(self) -> QWidget:
        """Create filter panel."""
        filter_group = QGroupBox("Filters")
        filter_layout = QHBoxLayout(filter_group)
        
        # Search field
        filter_layout.addWidget(QLabel("Search:"))
        
        self.search_input = QLineEdit()
        self.search_input.setPlaceholderText("Search in messages...")
        self.search_input.setMinimumWidth(200)
        self.search_input.returnPressed.connect(self._apply_filters)
        filter_layout.addWidget(self.search_input)
        
        # Level filter
        filter_layout.addWidget(QLabel("Level:"))
        
        self.level_combo = QComboBox()
        self.level_combo.addItem("All Levels", None)
        for level in LogLevel:
            self.level_combo.addItem(f"{level.value}", level)
        self.level_combo.currentIndexChanged.connect(self._apply_filters)
        filter_layout.addWidget(self.level_combo)
        
        # Source filter
        filter_layout.addWidget(QLabel("Source:"))
        
        self.source_combo = QComboBox()
        self.source_combo.addItem("All Sources", None)
        self.source_combo.currentIndexChanged.connect(self._apply_filters)
        filter_layout.addWidget(self.source_combo)
        
        # Time range
        filter_layout.addWidget(QLabel("From:"))
        
        self.start_time_edit = QDateTimeEdit()
        self.start_time_edit.setCalendarPopup(True)
        self.start_time_edit.setDateTime(QDateTime.currentDateTime().addDays(-1))
        self.start_time_edit.dateTimeChanged.connect(self._apply_filters)
        filter_layout.addWidget(self.start_time_edit)
        
        filter_layout.addWidget(QLabel("To:"))
        
        self.end_time_edit = QDateTimeEdit()
        self.end_time_edit.setCalendarPopup(True)
        self.end_time_edit.setDateTime(QDateTime.currentDateTime())
        self.end_time_edit.dateTimeChanged.connect(self._apply_filters)
        filter_layout.addWidget(self.end_time_edit)
        
        # Apply button
        self.btn_apply_filter = QPushButton("Apply")
        self.btn_apply_filter.clicked.connect(self._apply_filters)
        filter_layout.addWidget(self.btn_apply_filter)
        
        # Clear filters button
        self.btn_clear_filters = QPushButton("Clear")
        self.btn_clear_filters.clicked.connect(self._clear_filters)
        filter_layout.addWidget(self.btn_clear_filters)
        
        return filter_group
    
    def _init_timer(self):
        """Initialize auto-refresh timer."""
        self.refresh_timer = QTimer()
        self.refresh_timer.timeout.connect(self.refresh_logs)
        self.refresh_timer.setInterval(5000)  # 5 seconds
    
    async def initialize(self):
        """Initialize database connection and load initial data."""
        self.db_service = await get_database_service()
        await self._update_sources()
        self.refresh_logs()
    
    def refresh_logs(self):
        """Refresh log entries from database."""
        if not self.db_service:
            return
        
        # Get filter values
        level_index = self.level_combo.currentIndex()
        level = self.level_combo.itemData(level_index) if level_index >= 0 else None
        
        source_index = self.source_combo.currentIndex()
        source = self.source_combo.itemData(source_index) if source_index >= 0 else None
        
        search_text = self.search_input.text() or None
        
        start_time = self.start_time_edit.dateTime().toPyDateTime()
        end_time = self.end_time_edit.dateTime().toPyDateTime()
        
        # Start loader thread
        if self.loader_thread and self.loader_thread.isRunning():
            self.loader_thread.terminate()
        
        self.loader_thread = LogLoaderThread(
            self.db_service,
            level=level,
            source=source,
            search_text=search_text,
            start_time=start_time,
            end_time=end_time,
        )
        
        self.loader_thread.logs_loaded.connect(self._on_logs_loaded)
        self.loader_thread.error_occurred.connect(self._on_load_error)
        
        self.status_label.setText("Loading logs...")
        self.loader_thread.start()
    
    def _on_logs_loaded(self, logs: List[LogEntry]):
        """Handle logs loaded from database."""
        self.current_logs = logs
        self._populate_table(logs)
        
        count = len(logs)
        self.entry_count_label.setText(f"{count} entries")
        self.status_label.setText(f"Loaded {count} logs")
        
        # Auto-scroll to bottom if enabled
        if self.auto_scroll and self.log_table.rowCount() > 0:
            self.log_table.scrollToBottom()
    
    def _on_load_error(self, error: str):
        """Handle error loading logs."""
        self.status_label.setText(f"Error: {error}")
        QMessageBox.warning(self, "Error", f"Failed to load logs: {error}")
    
    def _populate_table(self, logs: List[LogEntry]):
        """Populate table with log entries."""
        self.log_table.setRowCount(len(logs))
        
        for row, entry in enumerate(logs):
            # Timestamp
            timestamp_item = QTableWidgetItem(entry.formatted_timestamp)
            timestamp_item.setData(Qt.ItemDataRole.UserRole, entry)
            self.log_table.setItem(row, 0, timestamp_item)
            
            # Level with color
            level_item = QTableWidgetItem(entry.level.value)
            level_item.setForeground(self.LEVEL_COLORS.get(entry.level, QColor()))
            level_item.setData(Qt.ItemDataRole.UserRole, entry)
            self.log_table.setItem(row, 1, level_item)
            
            # Source
            source_item = QTableWidgetItem(entry.source or "-")
            source_item.setData(Qt.ItemDataRole.UserRole, entry)
            self.log_table.setItem(row, 2, source_item)
            
            # Message (truncated)
            message = entry.message
            if len(message) > 100:
                message = message[:97] + "..."
            msg_item = QTableWidgetItem(message)
            msg_item.setData(Qt.ItemDataRole.UserRole, entry)
            self.log_table.setItem(row, 3, msg_item)
            
            # Script ID
            script_item = QTableWidgetItem(entry.script_id or "-")
            script_item.setData(Qt.ItemDataRole.UserRole, entry)
            self.log_table.setItem(row, 4, script_item)
    
    def _apply_filters(self):
        """Apply current filters and refresh logs."""
        self.refresh_logs()
    
    def _clear_filters(self):
        """Clear all filters."""
        self.search_input.clear()
        self.level_combo.setCurrentIndex(0)
        self.source_combo.setCurrentIndex(0)
        self.start_time_edit.setDateTime(QDateTime.currentDateTime().addDays(-1))
        self.end_time_edit.setDateTime(QDateTime.currentDateTime())
        self.refresh_logs()
    
    async def _update_sources(self):
        """Update source dropdown with available sources."""
        if not self.db_service:
            return
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            sources = await self.db_service.get_log_sources()
            
            # Preserve current selection
            current_source = self.source_combo.currentData()
            
            self.source_combo.clear()
            self.source_combo.addItem("All Sources", None)
            
            for source in sources:
                self.source_combo.addItem(source, source)
            
            # Restore selection if still available
            if current_source:
                index = self.source_combo.findData(current_source)
                if index >= 0:
                    self.source_combo.setCurrentIndex(index)
        finally:
            loop.close()
    
    def _on_selection_changed(self):
        """Handle log entry selection."""
        selected = self.log_table.selectedItems()
        
        if not selected:
            self.details_panel.clear()
            return
        
        row = selected[0].row()
        entry = self.log_table.item(row, 0).data(Qt.ItemDataRole.UserRole)
        
        if entry:
            self.log_selected.emit(entry)
            self._show_entry_details(entry)
    
    def _show_entry_details(self, entry: LogEntry):
        """Show detailed information about a log entry."""
        details = []
        details.append(f"<b>Timestamp:</b> {entry.timestamp.isoformat()}")
        details.append(f"<b>Level:</b> <span style='color:{self.LEVEL_COLORS[entry.level].name()}'>{entry.level.value}</span>")
        details.append(f"<b>Source:</b> {entry.source or 'N/A'}")
        
        if entry.script_id:
            details.append(f"<b>Script ID:</b> {entry.script_id}")
        
        if entry.line_number:
            details.append(f"<b>Line:</b> {entry.line_number}")
        
        details.append("")
        details.append(f"<b>Message:</b>")
        details.append(f"<pre>{entry.message}</pre>")
        
        self.details_panel.setHtml("<br>".join(details))
    
    def _show_context_menu(self, position):
        """Show context menu for log entries."""
        menu = QMenu(self)
        
        # Copy message action
        copy_action = QAction("Copy Message", self)
        copy_action.triggered.connect(self._copy_selected_message)
        menu.addAction(copy_action)
        
        # Copy all details action
        copy_details_action = QAction("Copy All Details", self)
        copy_details_action.triggered.connect(self._copy_selected_details)
        menu.addAction(copy_details_action)
        
        menu.exec(self.log_table.viewport().mapToGlobal(position))
    
    def _copy_selected_message(self):
        """Copy selected log message to clipboard."""
        selected = self.log_table.selectedItems()
        
        if selected:
            row = selected[0].row()
            message = self.log_table.item(row, 3).text()
            QApplication.clipboard().setText(message)
    
    def _copy_selected_details(self):
        """Copy all details of selected log to clipboard."""
        selected = self.log_table.selectedItems()
        
        if selected:
            row = selected[0].row()
            entry = self.log_table.item(row, 0).data(Qt.ItemDataRole.UserRole)
            
            if entry:
                details = f"{entry.formatted_timestamp} [{entry.level.value}] [{entry.source}] {entry.message}"
                QApplication.clipboard().setText(details)
    
    def _export_logs(self, format: str):
        """Export logs to file."""
        if not self.current_logs:
            QMessageBox.information(self, "Export", "No logs to export")
            return
        
        # Show save dialog
        file_filter = {
            'txt': "Text Files (*.txt)",
            'json': "JSON Files (*.json)",
            'csv': "CSV Files (*.csv)",
        }
        
        filepath, _ = QFileDialog.getSaveFileName(
            self,
            "Export Logs",
            f"neonlink_logs_{datetime.now().strftime('%Y%m%d_%H%M%S')}.{format}",
            file_filter[format]
        )
        
        if not filepath:
            return
        
        # Show progress
        progress = QProgressDialog("Exporting logs...", "Cancel", 0, 100, self)
        progress.setWindowModality(Qt.WindowModality.WindowModal)
        progress.show()
        
        # Export in background
        def do_export():
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                if format == 'txt':
                    result = loop.run_until_complete(
                        self.db_service.export_to_text(Path(filepath))
                    )
                elif format == 'json':
                    result = loop.run_until_complete(
                        self.db_service.export_to_json(Path(filepath))
                    )
                else:
                    result = loop.run_until_complete(
                        self.db_service.export_to_csv(Path(filepath))
                    )
                
                progress.close()
                
                QMessageBox.information(
                    self,
                    "Export Complete",
                    f"Exported {result} log entries to:\n{filepath}"
                )
            except Exception as e:
                progress.close()
                QMessageBox.critical(self, "Export Error", str(e))
            finally:
                loop.close()
        
        # Run export in thread
        import threading
        thread = threading.Thread(target=do_export)
        thread.start()
    
    def _clear_logs(self):
        """Clear all logs after confirmation."""
        reply = QMessageBox.question(
            self,
            "Clear Logs",
            "Are you sure you want to clear all logs? This action cannot be undone.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply == QMessageBox.StandardButton.Yes:
            def do_clear():
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                
                try:
                    loop.run_until_complete(self.db_service.clear_logs())
                    
                    # Update UI
                    self.current_logs = []
                    self.log_table.setRowCount(0)
                    self.details_panel.clear()
                    self.entry_count_label.setText("0 entries")
                    self.status_label.setText("Logs cleared")
                    
                    # Update sources
                    loop.run_until_complete(self._update_sources())
                except Exception as e:
                    QMessageBox.critical(self, "Error", f"Failed to clear logs: {e}")
                finally:
                    loop.close()
            
            import threading
            thread = threading.Thread(target=do_clear)
            thread.start()
    
    def start_auto_refresh(self):
        """Start auto-refresh timer."""
        self.refresh_timer.start()
    
    def stop_auto_refresh(self):
        """Stop auto-refresh timer."""
        self.refresh_timer.stop()
    
    def closeEvent(self, event):
        """Clean up on close."""
        self.stop_auto_refresh()
        
        if self.loader_thread and self.loader_thread.isRunning():
            self.loader_thread.terminate()
        
        super().closeEvent(event)
