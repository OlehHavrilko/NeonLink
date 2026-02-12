"""
MainWindow - Main application window for NeonLink Desktop.

Provides the main GUI interface with:
- Tabbed interface (Scripts, Connections, Settings)
- Menu bar and toolbar
- Status bar
- System tray icon
"""

import sys
from pathlib import Path
from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QTabWidget, QToolBar, QStatusBar, QMenuBar, QMenu,
    QMessageBox, QListWidget, QListWidgetItem,
    QPushButton, QLabel, QFrame, QSplitter,
    QTextEdit, QFileDialog, QInputDialog
)
from PyQt6.QtCore import Qt, QSize, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QAction, QIcon, QDragEnterEvent, QDropEvent

from .base_viewmodel import BaseViewModel
from ..models.script_model import ScriptModel


class DroppableListWidget(QListWidget):
    """
    ListWidget with drag-and-drop support for loading scripts.
    
    Signals:
        files_dropped: Emitted when files are dropped
    """
    
    files_dropped = pyqtSignal(list)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptDrops(True)
        self.setDragDropMode(QListWidget.DragDropMode.DropOnly)
        self.setSelectionMode(QListWidget.SelectionMode.ExtendedSelection)
    
    def dragEnterEvent(self, event: QDragEnterEvent):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
        else:
            event.ignore()
    
    def dragMoveEvent(self, event: QDragMoveEvent):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
        else:
            event.ignore()
    
    def dropEvent(self, event: QDropEvent):
        if event.mimeData().hasUrls():
            files = []
            for url in event.mimeData().urls():
                if url.isLocalFile():
                    path = Path(url.toLocalFile())
                    if path.is_file() and self._is_script_file(path):
                        files.append(path)
            
            if files:
                self.files_dropped.emit(files)
                event.acceptProposedAction()
                return
        
        event.ignore()
    
    def _is_script_file(self, path: Path) -> bool:
        """Check if file has supported script extension."""
        suffixes = {'.py', '.sh', '.ps1', '.psm1'}
        return path.suffix.lower() in suffixes


class MainWindow(QMainWindow):
    """
    Main application window.
    
    Structure:
    - MenuBar: File, Edit, View, Tools, Help
    - ToolBar: Quick actions
    - Central Widget: TabWidget with Script Manager, Connections, Settings
    - StatusBar: Application status
    - System Tray: Minimized state icon
    """
    
    def __init__(
        self,
        script_vm: BaseViewModel = None,
        parent=None
    ):
        super().__init__(parent)
        
        self.script_vm = script_vm
        
        self._setup_ui()
        self._setup_menus()
        self._setup_toolbar()
        self._setup_tray_icon()
        self._connect_signals()
    
    def _setup_ui(self):
        """Setup UI components."""
        self.setWindowTitle("NeonLink Control Center")
        self.setMinimumSize(1200, 800)
        self.resize(1400, 900)
        
        # Central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        
        # Tab widget
        self.tab_widget = QTabWidget()
        self.tab_widget.setDocumentMode(True)
        self.tab_widget.setTabsClosable(False)
        
        # Create tabs
        self.script_manager_view = self._create_script_manager_view()
        self.tab_widget.addTab(self.script_manager_view, "📜 Скрипты")
        
        self.connection_manager_view = self._create_connection_manager_view()
        self.tab_widget.addTab(self.connection_manager_view, "🔌 Подключения")
        
        self.settings_view = self._create_settings_view()
        self.tab_widget.addTab(self.settings_view, "⚙️ Настройки")
        
        main_layout.addWidget(self.tab_widget)
        
        # Status bar
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage("Готов")
    
    def _create_script_manager_view(self) -> QWidget:
        """Create script management view."""
        widget = QWidget()
        layout = QHBoxLayout(widget)
        
        # Splitter for resizable panels
        splitter = QSplitter(Qt.Orientation.Horizontal)
        
        # Left panel: Script list with drag-drop
        left_panel = QFrame()
        left_layout = QVBoxLayout(left_panel)
        left_layout.setContentsMargins(10, 10, 10, 10)
        
        # Drop zone
        drop_label = QLabel("📁 Перетащите скрипты сюда\n(.py, .sh, .ps1)")
        drop_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        drop_label.setObjectName("dropLabel")
        left_layout.addWidget(drop_label)
        
        # Script list
        self.script_list = DroppableListWidget()
        self.script_list.setObjectName("scriptList")
        left_layout.addWidget(self.script_list)
        
        # Script actions
        script_actions_layout = QHBoxLayout()
        
        self.btn_add_script = QPushButton("➕ Добавить")
        self.btn_add_script.setObjectName("btnAddScript")
        script_actions_layout.addWidget(self.btn_add_script)
        
        self.btn_remove_script = QPushButton("🗑️ Удалить")
        self.btn_remove_script.setObjectName("btnRemoveScript")
        script_actions_layout.addWidget(self.btn_remove_script)
        
        script_actions_layout.addStretch()
        left_layout.addLayout(script_actions_layout)
        
        # Right panel: Running scripts and logs
        right_panel = QWidget()
        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(10, 10, 10, 10)
        
        # Running scripts section
        running_label = QLabel("▶️ Запущенные Скрипты")
        running_label.setObjectName("runningLabel")
        right_layout.addWidget(running_label)
        
        self.running_scripts_list = QListWidget()
        self.running_scripts_list.setObjectName("runningScriptsList")
        self.running_scripts_list.setMaximumHeight(200)
        right_layout.addWidget(self.running_scripts_list)
        
        # Running script actions
        running_actions_layout = QHBoxLayout()
        self.btn_stop_script = QPushButton("⏹️ Остановить")
        self.btn_stop_script.setObjectName("btnStopScript")
        running_actions_layout.addWidget(self.btn_stop_script)
        
        self.btn_view_logs = QPushButton("📋 Логи")
        self.btn_view_logs.setObjectName("btnViewLogs")
        running_actions_layout.addWidget(self.btn_view_logs)
        right_layout.addLayout(running_actions_layout)
        
        # Logs section
        logs_label = QLabel("📋 Логи (Real-time)")
        logs_label.setObjectName("logsLabel")
        right_layout.addWidget(logs_label)
        
        self.logs_text = QTextEdit()
        self.logs_text.setObjectName("logsText")
        self.logs_text.setReadOnly(True)
        right_layout.addWidget(self.logs_text)
        
        # Add panels to splitter
        splitter.addWidget(left_panel)
        splitter.addWidget(right_panel)
        splitter.setSizes([400, 600])
        
        layout.addWidget(splitter)
        
        return widget
    
    def _create_connection_manager_view(self) -> QWidget:
        """Create connection management view."""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(10, 10, 10, 10)
        
        # Toolbar
        toolbar_layout = QHBoxLayout()
        
        self.btn_add_connection = QPushButton("➕ Добавить")
        self.btn_add_connection.setObjectName("btnAddConnection")
        toolbar_layout.addWidget(self.btn_add_connection)
        
        self.btn_edit_connection = QPushButton("✏️ Редактировать")
        self.btn_edit_connection.setObjectName("btnEditConnection")
        toolbar_layout.addWidget(self.btn_edit_connection)
        
        self.btn_delete_connection = QPushButton("🗑️ Удалить")
        self.btn_delete_connection.setObjectName("btnDeleteConnection")
        toolbar_layout.addWidget(self.btn_delete_connection)
        
        self.btn_test_connection = QPushButton("🔗 Тест")
        self.btn_test_connection.setObjectName("btnTestConnection")
        toolbar_layout.addWidget(self.btn_test_connection)
        
        toolbar_layout.addStretch()
        layout.addLayout(toolbar_layout)
        
        # Connections list
        self.connections_list = QListWidget()
        self.connections_list.setObjectName("connectionsList")
        layout.addWidget(self.connections_list)
        
        # Connection details
        details_label = QLabel("📋 Детали Подключения")
        details_label.setObjectName("detailsLabel")
        layout.addWidget(details_label)
        
        self.connection_details = QTextEdit()
        self.connection_details.setObjectName("connectionDetails")
        self.connection_details.setReadOnly(True)
        self.connection_details.setMaximumHeight(150)
        layout.addWidget(self.connection_details)
        
        return widget
    
    def _create_settings_view(self) -> QWidget:
        """Create settings view."""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(10, 10, 10, 10)
        
        # Theme settings
        theme_label = QLabel("🎨 Тема")
        theme_label.setObjectName("themeLabel")
        layout.addWidget(theme_label)
        
        theme_layout = QHBoxLayout()
        
        self.btn_dark_theme = QPushButton("🌙 Тёмная")
        self.btn_dark_theme.setObjectName("btnDarkTheme")
        theme_layout.addWidget(self.btn_dark_theme)
        
        self.btn_light_theme = QPushButton("☀️ Светлая")
        self.btn_light_theme.setObjectName("btnLightTheme")
        theme_layout.addWidget(self.btn_light_theme)
        
        layout.addLayout(theme_layout)
        
        layout.addStretch()
        
        return widget
    
    def _setup_menus(self):
        """Setup menu bar."""
        menubar = self.menuBar()
        
        # File menu
        file_menu = menubar.addMenu("Файл")
        
        add_script_action = QAction("📜 Добавить скрипт...", self)
        add_script_action.setShortcut("Ctrl+N")
        file_menu.addAction(add_script_action)
        
        add_connection_action = QAction("🔌 Добавить подключение...", self)
        add_connection_action.setShortcut("Ctrl+Shift+N")
        file_menu.addAction(add_connection_action)
        
        file_menu.addSeparator()
        
        settings_action = QAction("⚙️ Настройки...", self)
        settings_action.setShortcut("Ctrl+,")
        file_menu.addAction(settings_action)
        
        file_menu.addSeparator()
        
        exit_action = QAction("🚪 Выход", self)
        exit_action.setShortcut("Ctrl+Q")
        file_menu.addAction(exit_action)
        
        # View menu
        view_menu = menubar.addMenu("Вид")
        
        dark_theme_action = QAction("🌙 Тёмная тема", self)
        view_menu.addAction(dark_theme_action)
        
        light_theme_action = QAction("☀️ Светлая тема", self)
        view_menu.addAction(light_theme_action)
        
        view_menu.addSeparator()
        
        scripts_tab_action = QAction("📜 Скрипты", self)
        view_menu.addAction(scripts_tab_action)
        
        connections_tab_action = QAction("🔌 Подключения", self)
        view_menu.addAction(connections_tab_action)
        
        # Help menu
        help_menu = menubar.addMenu("Помощь")
        
        about_action = QAction("ℹ️ О приложении", self)
        help_menu.addAction(about_action)
    
    def _setup_toolbar(self):
        """Setup toolbar."""
        toolbar = QToolBar()
        toolbar.setMovable(False)
        toolbar.setIconSize(QSize(24, 24))
        self.addToolBar(toolbar)
        
        # Add toolbar actions
        add_script_tb = QAction("📜", self)
        add_script_tb.setToolTip("Добавить скрипт")
        toolbar.addAction(add_script_tb)
        
        add_connection_tb = QAction("🔌", self)
        add_connection_tb.setToolTip("Добавить подключение")
        toolbar.addAction(add_connection_tb)
        
        toolbar.addSeparator()
        
        settings_tb = QAction("⚙️", self)
        settings_tb.setToolTip("Настройки")
        toolbar.addAction(settings_tb)
    
    def _setup_tray_icon(self):
        """Setup system tray icon."""
        from PyQt6.QtWidgets import QSystemTrayIcon, QMenu
        
        if QSystemTrayIcon.isSystemTrayAvailable():
            self.tray_icon = QSystemTrayIcon(self)
            self.tray_icon.setToolTip("NeonLink Control Center")
            # TODO: Set icon
            # self.tray_icon.setIcon(QIcon(":/icons/tray_icon.png"))
            
            # Context menu for tray
            tray_menu = QMenu()
            
            show_action = QAction("📖 Показать", self)
            tray_menu.addAction(show_action)
            
            tray_menu.addSeparator()
            
            quit_action = QAction("🚪 Выход", self)
            tray_menu.addAction(quit_action)
            
            self.tray_icon.setContextMenu(tray_menu)
            self.tray_icon.show()
    
    def _connect_signals(self):
        """Connect UI signals to handlers."""
        # Script list drag-drop
        self.script_list.files_dropped.connect(self._on_scripts_dropped)
        
        # Script actions
        self.btn_add_script.clicked.connect(self._on_add_script)
        self.btn_remove_script.clicked.connect(self._on_remove_script)
        
        # Running script actions
        self.btn_stop_script.clicked.connect(self._on_stop_script)
        self.btn_view_logs.clicked.connect(self._on_view_logs)
        
        # Connection actions
        self.btn_add_connection.clicked.connect(self._on_add_connection)
        self.btn_edit_connection.clicked.connect(self._on_edit_connection)
        self.btn_delete_connection.clicked.connect(self._on_delete_connection)
        self.btn_test_connection.clicked.connect(self._on_test_connection)
        
        # Connection selection
        self.connections_list.itemSelectionChanged.connect(
            self._on_connection_selected
        )
        
        # Theme buttons
        self.btn_dark_theme.clicked.connect(self._on_dark_theme)
        self.btn_light_theme.clicked.connect(self._on_light_theme)
    
    @pyqtSlot(list)
    def _on_scripts_dropped(self, files: list):
        """Handle dropped script files."""
        self.status_bar.showMessage(f"Загружено {len(files)} скриптов...")
        
        # Load each script
        for file_path in files:
            if self.script_vm:
                try:
                    self.script_vm.load_script(str(file_path))
                    self.status_bar.showMessage(f"Скрипт загружен: {file_path.name}")
                except Exception as e:
                    self.status_bar.showMessage(f"Ошибка загрузки: {e}")
        
        self.status_bar.showMessage("Готов")
    
    def _on_add_script(self):
        """Handle add script button click."""
        file_path, _ = QFileDialog.getOpenFileName(
            self,
            "Выберите скрипт",
            ".",
            "Scripts (*.py *.sh *.ps1);;All Files (*)"
        )
        if file_path:
            self.status_bar.showMessage(f"Добавлен скрипт: {file_path}")
    
    def _on_remove_script(self):
        """Handle remove script button click."""
        selected = self.script_list.currentItem()
        if selected:
            self.script_list.takeItem(self.script_list.row(selected))
            self.status_bar.showMessage(f"Скрипт удалён")
        else:
            QMessageBox.warning(self, "Предупреждение", "Выберите скрипт для удаления")
    
    def _on_stop_script(self):
        """Handle stop script button click."""
        selected = self.running_scripts_list.currentItem()
        if selected:
            self.status_bar.showMessage(f"Остановка скрипта...")
        else:
            QMessageBox.warning(self, "Предупреждение", "Выберите скрипт для остановки")
    
    def _on_view_logs(self):
        """Handle view logs button click."""
        # Show logs in a dialog or scroll to bottom
        self.logs_text.verticalScrollBar().setValue(
            self.logs_text.verticalScrollBar().maximum()
        )
    
    def _on_add_connection(self):
        """Handle add connection button click."""
        ip, ok = QInputDialog.getText(
            self, "Добавить подключение", "IP адрес:",
            text="192.168.1.1"
        )
        if ok and ip:
            port, ok2 = QInputDialog.getInt(self, "Добавить подключение", "Порт:", 8080, 1, 65535)
            if ok2:
                self.status_bar.showMessage(f"Добавлено подключение: {ip}:{port}")
    
    def _on_edit_connection(self):
        """Handle edit connection button click."""
        selected = self.connections_list.currentItem()
        if selected:
            self.status_bar.showMessage(f"Редактирование подключения: {selected.text()}")
        else:
            QMessageBox.warning(self, "Предупреждение", "Выберите подключение для редактирования")
    
    def _on_delete_connection(self):
        """Handle delete connection button click."""
        selected = self.connections_list.currentItem()
        if selected:
            reply = QMessageBox.question(
                self, "Подтверждение", 
                f"Удалить подключение: {selected.text()}?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )
            if reply == QMessageBox.StandardButton.Yes:
                self.connections_list.takeItem(self.connections_list.row(selected))
                self.status_bar.showMessage("Подключение удалено")
        else:
            QMessageBox.warning(self, "Предупреждение", "Выберите подключение для удаления")
    
    def _on_test_connection(self):
        """Handle test connection button click."""
        selected = self.connections_list.currentItem()
        if selected:
            self.status_bar.showMessage(f"Тестирование подключения: {selected.text()}...")
        else:
            QMessageBox.warning(self, "Предупреждение", "Выберите подключение для тестирования")
    
    def _on_connection_selected(self):
        """Handle connection selection changed."""
        selected = self.connections_list.currentItem()
        if selected:
            self.connection_details.setText(f"Выбрано: {selected.text()}")
        else:
            self.connection_details.clear()
    
    def _on_dark_theme(self):
        """Switch to dark theme."""
        self.setStyleSheet("""
            QWidget { background-color: #2b2b2b; color: #ffffff; }
            QPushButton { background-color: #3a3a3a; border: 1px solid #555; }
            QLabel { color: #ffffff; }
        """)
        self.status_bar.showMessage("Тёмная тема применена")
    
    def _on_light_theme(self):
        """Switch to light theme."""
        self.setStyleSheet("""
            QWidget { background-color: #f0f0f0; color: #000000; }
            QPushButton { background-color: #e0e0e0; border: 1px solid #ccc; }
            QLabel { color: #000000; }
        """)
        self.status_bar.showMessage("Светлая тема применена")
    
    def closeEvent(self, event):
        """Handle window close event."""
        reply = QMessageBox.question(
            self,
            "Выход",
            "Вы уверены, что хотите выйти?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        
        if reply == QMessageBox.StandardButton.Yes:
            # Stop all running scripts before exit
            if self.script_vm:
                try:
                    self.script_vm.stop_all_scripts()
                except Exception as e:
                    print(f"Error stopping scripts: {e}")
            event.accept()
        else:
            event.ignore()
    
    def showEvent(self, event):
        """Handle window show event."""
        super().showEvent(event)
        self.setWindowState(self.windowState() & ~Qt.WindowState.WindowMinimized)
