"""
SettingsView - Extended settings panel for NeonLink Desktop.

Features:
- General settings
- Appearance settings
- Script settings
- Security settings
- Notification settings
- Backup settings
- Network settings
- About section
"""

from typing import Optional, Dict, Any, Callable

from pathlib import Path

from pathlib import Path

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QTabWidget, QLabel,
    QPushButton, QLineEdit, QCheckBox, QComboBox, QSpinBox,
    QGroupBox, QFormLayout, QScrollArea, QDoubleSpinBox,
    QFileDialog, QMessageBox, QListWidget, QListWidgetItem,
    QTextEdit, QSlider, QProgressBar
)
from PyQt6.QtCore import Qt, pyqtSignal, QSettings
from PyQt6.QtGui import QFont


class SettingsView(QWidget):
    """
    Extended settings panel with multiple tabs.
    
    Signals:
        settings_changed: Emitted when settings are changed
        settings_saved: Emitted when settings are saved
    """
    
    settings_changed = pyqtSignal(dict)
    settings_saved = pyqtSignal()
    
    def __init__(self, parent: Optional[QWidget] = None):
        super().__init__(parent)
        
        self._settings: Dict[str, Any] = {}
        self._init_ui()
        self._load_settings()
    
    def _init_ui(self):
        """Initialize user interface."""
        layout = QVBoxLayout(self)
        
        # Create tab widget
        self.tab_widget = QTabWidget()
        
        # Add tabs
        self.tab_widget.addTab(self._create_general_tab(), "📌 General")
        self.tab_widget.addTab(self._create_appearance_tab(), "🎨 Appearance")
        self.tab_widget.addTab(self._create_scripts_tab(), "📜 Scripts")
        self.tab_widget.addTab(self._create_security_tab(), "🔒 Security")
        self.tab_widget.addTab(self._create_notifications_tab(), "🔔 Notifications")
        self.tab_widget.addTab(self._create_backup_tab(), "💾 Backup")
        self.tab_widget.addTab(self._create_network_tab(), "🌐 Network")
        self.tab_widget.addTab(self._create_about_tab(), "ℹ️ About")
        
        layout.addWidget(self.tab_widget)
        
        # Buttons
        button_layout = QHBoxLayout()
        
        button_layout.addStretch()
        
        self.btn_reset = QPushButton("Reset to Defaults")
        self.btn_reset.clicked.connect(self._reset_settings)
        button_layout.addWidget(self.btn_reset)
        
        self.btn_save = QPushButton("Save Settings")
        self.btn_save.clicked.connect(self._save_settings)
        self.btn_save.setDefault(True)
        button_layout.addWidget(self.btn_save)
        
        layout.addLayout(button_layout)
    
    def _create_general_tab(self) -> QWidget:
        """Create general settings tab."""
        widget = QWidget()
        layout = QFormLayout(widget)
        
        # Auto-start
        self.chk_auto_start = QCheckBox("Start application on system login")
        layout.addRow("Auto-start:", self.chk_auto_start)
        
        # Minimize to tray
        self.chk_minimize_to_tray = QCheckBox("Minimize to system tray instead of closing")
        layout.addRow("System tray:", self.chk_minimize_to_tray)
        
        # Check updates
        self.chk_check_updates = QCheckBox("Check for updates on startup")
        self.chk_check_updates.setChecked(True)
        layout.addRow("Updates:", self.chk_check_updates)
        
        # Update channel
        self.combo_update_channel = QComboBox()
        self.combo_update_channel.addItems(["Stable", "Beta"])
        layout.addRow("Update channel:", self.combo_update_channel)
        
        # Language
        self.combo_language = QComboBox()
        self.combo_language.addItems(["English", "Русский", "Deutsch", "Français", "Español"])
        layout.addRow("Language:", self.combo_language)
        
        layout.addRow("", QLabel(""))  # Spacer
        
        return widget
    
    def _create_appearance_tab(self) -> QWidget:
        """Create appearance settings tab."""
        widget = QWidget()
        layout = QFormLayout(widget)
        
        # Theme
        self.combo_theme = QComboBox()
        self.combo_theme.addItems(["Dark", "Light", "System"])
        layout.addRow("Theme:", self.combo_theme)
        
        # Font size
        self.spin_font_size = QSpinBox()
        self.spin_font_size.setRange(8, 20)
        self.spin_font_size.setValue(10)
        self.spin_font_size.setSuffix(" pt")
        layout.addRow("Font size:", self.spin_font_size)
        
        # Show line numbers
        self.chk_line_numbers = QCheckBox("Show line numbers in editor")
        layout.addRow("Editor:", self.chk_line_numbers)
        
        # Word wrap
        self.chk_word_wrap = QCheckBox("Enable word wrap")
        layout.addRow("", self.chk_word_wrap)
        
        layout.addRow("", QLabel(""))  # Spacer
        
        return widget
    
    def _create_scripts_tab(self) -> QWidget:
        """Create script settings tab."""
        widget = QWidget()
        layout = QFormLayout(widget)
        
        # Scripts directory
        scripts_layout = QHBoxLayout()
        self.edit_scripts_dir = QLineEdit()
        self.edit_scripts_dir.setReadOnly(True)
        scripts_layout.addWidget(self.edit_scripts_dir)
        
        btn_browse = QPushButton("Browse...")
        btn_browse.clicked.connect(lambda: self._browse_directory(self.edit_scripts_dir))
        scripts_layout.addWidget(btn_browse)
        
        layout.addRow("Scripts directory:", scripts_layout)
        
        # Default interpreter
        self.edit_default_interpreter = QLineEdit()
        self.edit_default_interpreter.setPlaceholderText("python, powershell, bash...")
        layout.addRow("Default interpreter:", self.edit_default_interpreter)
        
        # Auto-save
        self.chk_auto_save = QCheckBox("Auto-save script changes")
        layout.addRow("Auto-save:", self.chk_auto_save)
        
        # Save interval
        self.spin_save_interval = QSpinBox()
        self.spin_save_interval.setRange(10, 300)
        self.spin_save_interval.setValue(60)
        self.spin_save_interval.setSuffix(" sec")
        layout.addRow("Save interval:", self.spin_save_interval)
        
        # Max log entries
        self.spin_max_logs = QSpinBox()
        self.spin_max_logs.setRange(100, 10000)
        self.spin_max_logs.setValue(1000)
        self.spin_max_logs.setSingleStep(100)
        layout.addRow("Max log entries:", self.spin_max_logs)
        
        layout.addRow("", QLabel(""))  # Spacer
        
        return widget
    
    def _create_security_tab(self) -> QWidget:
        """Create security settings tab."""
        widget = QWidget()
        layout = QFormLayout(widget)
        
        # Encryption
        self.chk_encryption = QCheckBox("Enable AES-256-GCM encryption")
        self.chk_encryption.setChecked(True)
        layout.addRow("Encryption:", self.chk_encryption)
        
        # Validate scripts
        self.chk_validate_scripts = QCheckBox("Validate scripts before execution")
        self.chk_validate_scripts.setChecked(True)
        layout.addRow("Validation:", self.chk_validate_scripts)
        
        # Sandbox mode
        self.chk_sandbox = QCheckBox("Enable sandbox mode for script execution")
        layout.addRow("Sandbox:", self.chk_sandbox)
        
        # Timeout
        self.spin_timeout = QSpinBox()
        self.spin_timeout.setRange(10, 3600)
        self.spin_timeout.setValue(300)
        self.spin_timeout.setSuffix(" sec")
        layout.addRow("Execution timeout:", self.spin_timeout)
        
        # Allowed commands
        layout.addRow("Allowed commands:", QLabel(""))
        
        self.list_allowed_commands = QListWidget()
        self.list_allowed_commands.addItems([
            "ping", "traceroute", "nslookup", "curl", "wget",
            "git", "docker", "kubectl", "npm", "pip"
        ])
        layout.addRow("", self.list_allowed_commands)
        
        return widget
    
    def _create_notifications_tab(self) -> QWidget:
        """Create notification settings tab."""
        widget = QWidget()
        layout = QFormLayout(widget)
        
        # Enable notifications
        self.chk_notifications = QCheckBox("Enable system notifications")
        self.chk_notifications.setChecked(True)
        layout.addRow("Notifications:", self.chk_notifications)
        
        # Notification sounds
        self.chk_notification_sounds = QCheckBox("Play notification sounds")
        self.chk_notification_sounds.setChecked(True)
        layout.addRow("Sounds:", self.chk_notification_sounds)
        
        # Script started
        self.chk_notify_script_start = QCheckBox("Script started")
        self.chk_notify_script_start.setChecked(True)
        layout.addRow("Notify on:", self.chk_notify_script_start)
        
        # Script completed
        self.chk_notify_script_complete = QCheckBox("Script completed")
        self.chk_notify_script_complete.setChecked(True)
        layout.addRow("", self.chk_notify_script_complete)
        
        # Script error
        self.chk_notify_script_error = QCheckBox("Script error")
        self.chk_notify_script_error.setChecked(True)
        layout.addRow("", self.chk_notify_script_error)
        
        # Backup created
        self.chk_notify_backup = QCheckBox("Backup created")
        layout.addRow("", self.chk_notify_backup)
        
        # Update available
        self.chk_notify_update = QCheckBox("Update available")
        layout.addRow("", self.chk_notify_update)
        
        layout.addRow("", QLabel(""))  # Spacer
        
        return widget
    
    def _create_backup_tab(self) -> QWidget:
        """Create backup settings tab."""
        widget = QWidget()
        layout = QFormLayout(widget)
        
        # Auto backup
        self.chk_auto_backup = QCheckBox("Enable automatic backups")
        layout.addRow("Auto backup:", self.chk_auto_backup)
        
        # Backup schedule
        self.combo_backup_schedule = QComboBox()
        self.combo_backup_schedule.addItems(["Daily", "Weekly", "Monthly", "Manual"])
        layout.addRow("Schedule:", self.combo_backup_schedule)
        
        # Backup directory
        backup_layout = QHBoxLayout()
        self.edit_backup_dir = QLineEdit()
        self.edit_backup_dir.setReadOnly(True)
        backup_layout.addWidget(self.edit_backup_dir)
        
        btn_browse_backup = QPushButton("Browse...")
        btn_browse_backup.clicked.connect(lambda: self._browse_directory(self.edit_backup_dir))
        backup_layout.addWidget(btn_browse_backup)
        
        layout.addRow("Backup directory:", backup_layout)
        
        # Max backups
        self.spin_max_backups = QSpinBox()
        self.spin_max_backups.setRange(1, 100)
        self.spin_max_backups.setValue(10)
        layout.addRow("Max backups:", self.spin_max_backups)
        
        # Backup now button
        btn_backup_now = QPushButton("Backup Now")
        btn_backup_now.clicked.connect(self._backup_now)
        layout.addRow("", btn_backup_now)
        
        # Restore button
        btn_restore = QPushButton("Restore from Backup...")
        btn_restore.clicked.connect(self._restore_backup)
        layout.addRow("", btn_restore)
        
        layout.addRow("", QLabel(""))  # Spacer
        
        return widget
    
    def _create_network_tab(self) -> QWidget:
        """Create network settings tab."""
        widget = QWidget()
        layout = QFormLayout(widget)
        
        # Use proxy
        self.chk_use_proxy = QCheckBox("Use proxy server")
        layout.addRow("Proxy:", self.chk_use_proxy)
        
        # Proxy host
        self.edit_proxy_host = QLineEdit()
        self.edit_proxy_host.setPlaceholderText("proxy.example.com")
        layout.addRow("Proxy host:", self.edit_proxy_host)
        
        # Proxy port
        self.spin_proxy_port = QSpinBox()
        self.spin_proxy_port.setRange(1, 65535)
        self.spin_proxy_port.setValue(8080)
        layout.addRow("Proxy port:", self.spin_proxy_port)
        
        # Proxy auth
        self.chk_proxy_auth = QCheckBox("Proxy requires authentication")
        layout.addRow("Authentication:", self.chk_proxy_auth)
        
        # Connection timeout
        self.spin_connection_timeout = QSpinBox()
        self.spin_connection_timeout.setRange(5, 120)
        self.spin_connection_timeout.setValue(30)
        self.spin_connection_timeout.setSuffix(" sec")
        layout.addRow("Connection timeout:", self.spin_connection_timeout)
        
        # Request timeout
        self.spin_request_timeout = QSpinBox()
        self.spin_request_timeout.setRange(10, 300)
        self.spin_request_timeout.setValue(60)
        self.spin_request_timeout.setSuffix(" sec")
        layout.addRow("Request timeout:", self.spin_request_timeout)
        
        layout.addRow("", QLabel(""))  # Spacer
        
        return widget
    
    def _create_about_tab(self) -> QWidget:
        """Create about tab."""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # App info
        info_group = QGroupBox("NeonLink Desktop")
        info_layout = QFormLayout(info_group)
        
        info_layout.addRow("Version:", QLabel("1.0.0"))
        info_layout.addRow("Build:", QLabel("2024.01.01"))
        info_layout.addRow("Python:", QLabel("3.10+"))
        info_layout.addRow("Qt:", QLabel("PyQt6"))
        
        layout.addWidget(info_group)
        
        # Description
        desc = QLabel(
            "NeonLink Desktop - Control Center for managing scripts and connections.\n\n"
            "© 2024 NeonLink. All rights reserved."
        )
        desc.setWordWrap(True)
        layout.addWidget(desc)
        
        layout.addStretch()
        
        return widget
    
    def _browse_directory(self, line_edit: QLineEdit):
        """Open directory browser."""
        directory = QFileDialog.getExistingDirectory(
            self,
            "Select Directory",
            line_edit.text() or str.home()
        )
        
        if directory:
            line_edit.setText(directory)
    
    def _load_settings(self):
        """Load settings from storage."""
        # TODO: Load from ConfigManager
        pass
    
    def _save_settings(self):
        """Save settings to storage."""
        # Collect all settings
        settings = {
            # General
            "auto_start": self.chk_auto_start.isChecked(),
            "minimize_to_tray": self.chk_minimize_to_tray.isChecked(),
            "check_updates": self.chk_check_updates.isChecked(),
            "update_channel": self.combo_update_channel.currentText().lower(),
            "language": self.combo_language.currentText(),
            
            # Appearance
            "theme": self.combo_theme.currentText().lower(),
            "font_size": self.spin_font_size.value(),
            "line_numbers": self.chk_line_numbers.isChecked(),
            "word_wrap": self.chk_word_wrap.isChecked(),
            
            # Scripts
            "scripts_dir": self.edit_scripts_dir.text(),
            "default_interpreter": self.edit_default_interpreter.text(),
            "auto_save": self.chk_auto_save.isChecked(),
            "save_interval": self.spin_save_interval.value(),
            "max_logs": self.spin_max_logs.value(),
            
            # Security
            "encryption": self.chk_encryption.isChecked(),
            "validate_scripts": self.chk_validate_scripts.isChecked(),
            "sandbox": self.chk_sandbox.isChecked(),
            "timeout": self.spin_timeout.value(),
            
            # Notifications
            "notifications_enabled": self.chk_notifications.isChecked(),
            "notification_sounds": self.chk_notification_sounds.isChecked(),
            "notify_script_start": self.chk_notify_script_start.isChecked(),
            "notify_script_complete": self.chk_notify_script_complete.isChecked(),
            "notify_script_error": self.chk_notify_script_error.isChecked(),
            "notify_backup": self.chk_notify_backup.isChecked(),
            "notify_update": self.chk_notify_update.isChecked(),
            
            # Backup
            "auto_backup": self.chk_auto_backup.isChecked(),
            "backup_schedule": self.combo_backup_schedule.currentText().lower(),
            "backup_dir": self.edit_backup_dir.text(),
            "max_backups": self.spin_max_backups.value(),
            
            # Network
            "use_proxy": self.chk_use_proxy.isChecked(),
            "proxy_host": self.edit_proxy_host.text(),
            "proxy_port": self.spin_proxy_port.value(),
            "proxy_auth": self.chk_proxy_auth.isChecked(),
            "connection_timeout": self.spin_connection_timeout.value(),
            "request_timeout": self.spin_request_timeout.value(),
        }
        
        self._settings = settings
        self.settings_changed.emit(settings)
        self.settings_saved.emit()
        
        QMessageBox.information(self, "Settings", "Settings saved successfully!")
    
    def _reset_settings(self):
        """Reset settings to defaults."""
        reply = QMessageBox.question(
            self,
            "Reset Settings",
            "Are you sure you want to reset all settings to defaults?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply == QMessageBox.StandardButton.Yes:
            # Reset UI values
            self.chk_auto_start.setChecked(False)
            self.chk_minimize_to_tray.setChecked(True)
            self.chk_check_updates.setChecked(True)
            self.combo_update_channel.setCurrentIndex(0)
            self.combo_language.setCurrentIndex(0)
            self.combo_theme.setCurrentIndex(0)
            self.spin_font_size.setValue(10)
            self.chk_line_numbers.setChecked(False)
            self.chk_word_wrap.setChecked(True)
            self.chk_auto_save.setChecked(True)
            self.spin_save_interval.setValue(60)
            self.spin_max_logs.setValue(1000)
            self.chk_encryption.setChecked(True)
            self.chk_validate_scripts.setChecked(True)
            self.chk_sandbox.setChecked(False)
            self.spin_timeout.setValue(300)
            self.chk_notifications.setChecked(True)
            self.chk_notification_sounds.setChecked(True)
            self.chk_notify_script_start.setChecked(True)
            self.chk_notify_script_complete.setChecked(True)
            self.chk_notify_script_error.setChecked(True)
            self.chk_notify_backup.setChecked(False)
            self.chk_notify_update.setChecked(False)
            self.chk_auto_backup.setChecked(False)
            self.combo_backup_schedule.setCurrentIndex(3)
            self.spin_max_backups.setValue(10)
            self.chk_use_proxy.setChecked(False)
            self.spin_connection_timeout.setValue(30)
            self.spin_request_timeout.setValue(60)
    
    def _backup_now(self):
        """Trigger immediate backup."""
        # TODO: Implement backup
        QMessageBox.information(
            self,
            "Backup",
            "Creating backup..."
        )
    
    def _restore_backup(self):
        """Restore from backup."""
        file_path, _ = QFileDialog.getOpenFileName(
            self,
            "Select Backup File",
            "",
            "Backup Files (*.zip);;All Files (*)"
        )
        
        if file_path:
            # TODO: Implement restore
            QMessageBox.information(
                self,
                "Restore",
                f"Restoring from: {file_path}"
            )
    
    def get_settings(self) -> Dict[str, Any]:
        """Get current settings."""
        return self._settings.copy()
    
    def set_settings(self, settings: Dict[str, Any]):
        """Set settings."""
        self._settings = settings
        # TODO: Apply to UI
