"""
HelpView - Built-in user documentation for NeonLink Desktop.

Features:
- User manual with sections
- Search functionality
- Table of contents navigation
- Context-sensitive help
"""

from typing import Optional, List, Tuple

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QSplitter,
    QListWidget, QListWidgetItem, QTextBrowser,
    QLineEdit, QPushButton, QLabel, QGroupBox
)
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QFont, QTextCharFormat, QTextCursor


class HelpViewer(QWidget):
    """
    Built-in documentation viewer.
    
    Signals:
        topic_selected: Emitted when a help topic is selected
    """
    
    topic_selected = pyqtSignal(str)
    
    # Help content
    HELP_CONTENT = {
        "welcome": """
            <h1>Welcome to NeonLink Desktop</h1>
            <p>NeonLink Desktop is a powerful control center for managing scripts and connections.</p>
            
            <h2>Getting Started</h2>
            <ul>
                <li><b>Scripts</b> - Manage and run automation scripts</li>
                <li><b>Connections</b> - Configure server connections</li>
                <li><b>Logs</b> - View application and script logs</li>
                <li><b>Settings</b> - Customize application behavior</li>
            </ul>
            
            <h2>Quick Actions</h2>
            <ul>
                <li>Press <b>Ctrl+N</b> to create a new script</li>
                <li>Press <b>Ctrl+R</b> to run selected script</li>
                <li>Press <b>Ctrl+,</b> to open settings</li>
                <li>Press <b>F1</b> to show this help</li>
            </ul>
        """,
        
        "scripts": """
            <h1>Managing Scripts</h1>
            
            <h2>Adding Scripts</h2>
            <p>To add a new script:</p>
            <ol>
                <li>Click the <b>+</b> button in the Scripts panel</li>
                <li>Select script file or create new</li>
                <li>Configure script properties (interpreter, arguments)</li>
            </ol>
            
            <h2>Running Scripts</h2>
            <p>Run a script by:</p>
            <ul>
                <li>Double-clicking the script in the list</li>
                <li>Selecting script and pressing <b>Run</b> button</li>
                <li>Using keyboard shortcut <b>Ctrl+R</b></li>
            </ul>
            
            <h2>Script Configuration</h2>
            <p>Each script can be configured with:</p>
            <ul>
                <li><b>Interpreter</b> - python, powershell, bash, etc.</li>
                <li><b>Arguments</b> - command line arguments</li>
                <li><b>Working directory</b> - execution context</li>
                <li><b>Environment variables</b> - custom environment</li>
            </ul>
        """,
        
        "connections": """
            <h1>Managing Connections</h1>
            
            <h2>Adding Connections</h2>
            <p>To add a new connection:</p>
            <ol>
                <li>Click <b>Add Connection</b> in Connections panel</li>
                <li>Enter connection details (host, port, credentials)</li>
                <li>Test the connection</li>
                <li>Save the configuration</li>
            </ol>
            
            <h2>Connection Types</h2>
            <p>NeonLink supports various connection types:</p>
            <ul>
                <li><b>SSH</b> - Secure shell connections</li>
                <li><b>REST API</b> - HTTP/HTTPS endpoints</li>
                <li><b>WebSocket</b> - Real-time connections</li>
                <li><b>Database</b> - SQL database connections</li>
            </ul>
            
            <h2>Security</h2>
            <p>Credentials are encrypted using AES-256-GCM and stored securely in the system keyring.</p>
        """,
        
        "logs": """
            <h1>Viewing Logs</h1>
            
            <h2>Log Types</h2>
            <ul>
                <li><b>Application Logs</b> - General application events</li>
                <li><b>Script Output</b> - stdout/stderr from scripts</li>
                <li><b>Connection Logs</b> - Connection events</li>
            </ul>
            
            <h2>Filtering Logs</h2>
            <p>Use the filter panel to find specific entries:</p>
            <ul>
                <li><b>Level</b> - DEBUG, INFO, WARNING, ERROR</li>
                <li><b>Source</b> - Filter by component</li>
                <li><b>Time range</b> - Filter by date/time</li>
                <li><b>Search</b> - Full-text search</li>
            </ul>
            
            <h2>Exporting Logs</h2>
            <p>Export logs to file:</p>
            <ul>
                <li><b>TXT</b> - Plain text format</li>
                <li><b>JSON</b> - Structured JSON</li>
                <li><b>CSV</b> - Spreadsheet compatible</li>
            </ul>
        """,
        
        "settings": """
            <h1>Application Settings</h1>
            
            <h2>General</h2>
            <ul>
                <li>Auto-start with system</li>
                <li>Minimize to system tray</li>
                <li>Check for updates</li>
                <li>Language selection</li>
            </ul>
            
            <h2>Appearance</h2>
            <ul>
                <li>Theme (Dark/Light/System)</li>
                <li>Font size</li>
                <li>Editor preferences</li>
            </ul>
            
            <h2>Security</h2>
            <ul>
                <li>Encryption settings</li>
                <li>Script validation</li>
                <li>Sandbox mode</li>
                <li>Execution timeout</li>
            </ul>
            
            <h2>Backup</h2>
            <ul>
                <li>Auto-backup schedule</li>
                <li>Backup directory</li>
                <li>Number of backups to keep</li>
            </ul>
        """,
        
        "troubleshooting": """
            <h1>Troubleshooting</h1>
            
            <h2>Common Issues</h2>
            
            <h3>Script won't start</h3>
            <ul>
                <li>Check interpreter path is correct</li>
                <li>Verify script file exists</li>
                <li>Check execution permissions</li>
            </ul>
            
            <h3>Connection failed</h3>
            <ul>
                <li>Verify network connectivity</li>
                <li>Check firewall settings</li>
                <li>Validate credentials</li>
            </ul>
            
            <h3>Application crashes</h3>
            <ul>
                <li>Check error logs in ~/.config/neonlink/logs/</li>
                <li>Try resetting settings</li>
                <li>Update to latest version</li>
            </ul>
            
            <h2>Getting Help</h2>
            <p>If you need further assistance:</p>
            <ul>
                <li>Check documentation at docs.neonlink.io</li>
                <li>Report issues on GitHub</li>
                <li>Contact support@neonlink.io</li>
            </ul>
        """,
        
        "keyboard_shortcuts": """
            <h1>Keyboard Shortcuts</h1>
            
            <h2>General</h2>
            <table>
                <tr><td><b>Ctrl+N</b></td><td>New script</td></tr>
                <tr><td><b>Ctrl+O</b></td><td>Open script</td></tr>
                <tr><td><b>Ctrl+S</b></td><td>Save</td></tr>
                <tr><td><b>Ctrl+,</b></td><td>Settings</td></tr>
                <tr><td><b>F1</b></td><td>Help</td></tr>
            </table>
            
            <h2>Script Execution</h2>
            <table>
                <tr><td><b>Ctrl+R</b></td><td>Run script</td></tr>
                <tr><td><b>Ctrl+Shift+R</b></td><td>Run with arguments</td></tr>
                <tr><td><b>Ctrl+C</b></td><td>Stop script</td></tr>
            </table>
            
            <h2>Navigation</h2>
            <table>
                <tr><td><b>Ctrl+1</b></td><td>Scripts panel</td></tr>
                <tr><td><b>Ctrl+2</b></td><td>Connections panel</td></tr>
                <tr><td><b>Ctrl+3</b></td><td>Logs panel</td></tr>
            </table>
        """,
    }
    
    def __init__(self, parent: Optional[QWidget] = None):
        super().__init__(parent)
        
        self._init_ui()
    
    def _init_ui(self):
        """Initialize user interface."""
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        
        # Create splitter
        splitter = QSplitter(Qt.Orientation.Horizontal)
        
        # Left panel - Table of contents
        left_panel = self._create_toc_panel()
        splitter.addWidget(left_panel)
        
        # Right panel - Content
        right_panel = self._create_content_panel()
        splitter.addWidget(right_panel)
        
        # Set splitter proportions
        splitter.setSizes([250, 600])
        
        layout.addWidget(splitter)
    
    def _create_toc_panel(self) -> QWidget:
        """Create table of contents panel."""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(5, 5, 5, 5)
        
        # Search
        self.search_input = QLineEdit()
        self.search_input.setPlaceholderText("Search help...")
        self.search_input.textChanged.connect(self._on_search)
        layout.addWidget(self.search_input)
        
        # Topics list
        self.topic_list = QListWidget()
        self.topic_list.itemClicked.connect(self._on_topic_selected)
        
        # Add topics
        topics = [
            ("welcome", "📖 Welcome"),
            ("scripts", "📜 Scripts"),
            ("connections", "🔌 Connections"),
            ("logs", "📋 Logs"),
            ("settings", "⚙️ Settings"),
            ("troubleshooting", "🔧 Troubleshooting"),
            ("keyboard_shortcuts", "⌨️ Keyboard Shortcuts"),
        ]
        
        for topic_id, topic_name in topics:
            item = QListWidgetItem(topic_name)
            item.setData(Qt.ItemDataRole.UserRole, topic_id)
            self.topic_list.addItem(item)
        
        layout.addWidget(self.topic_list)
        
        return widget
    
    def _create_content_panel(self) -> QWidget:
        """Create content panel."""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(5, 5, 5, 5)
        
        # Title
        self.title_label = QLabel("Welcome")
        title_font = QFont()
        title_font.setPointSize(16)
        title_font.setBold(True)
        self.title_label.setFont(title_font)
        layout.addWidget(self.title_label)
        
        # Content browser
        self.content_browser = QTextBrowser()
        self.content_browser.setOpenExternalLinks(True)
        self.content_browser.setSearchEnabled(True)
        layout.addWidget(self.content_browser)
        
        # Navigation buttons
        nav_layout = QHBoxLayout()
        
        self.btn_back = QPushButton("← Back")
        self.btn_back.clicked.connect(self.content_browser.backward)
        nav_layout.addWidget(self.btn_back)
        
        self.btn_forward = QPushButton("Forward →")
        self.btn_forward.clicked.connect(self.content_browser.forward)
        nav_layout.addWidget(self.btn_forward)
        
        nav_layout.addStretch()
        
        self.btn_home = QPushButton("🏠 Home")
        self.btn_home.clicked.connect(lambda: self.show_topic("welcome"))
        nav_layout.addWidget(self.btn_home)
        
        layout.addLayout(nav_layout)
        
        # Show welcome by default
        self.show_topic("welcome")
        
        return widget
    
    def _on_topic_selected(self, item: QListWidgetItem):
        """Handle topic selection."""
        topic_id = item.data(Qt.ItemDataRole.UserRole)
        self.show_topic(topic_id)
        self.topic_selected.emit(topic_id)
    
    def _on_search(self, text: str):
        """Handle search."""
        if not text:
            self.topic_list.setCurrentRow(0)
            return
        
        # Simple search in topic titles
        text_lower = text.lower()
        
        for i in range(self.topic_list.count()):
            item = self.topic_list.item(i)
            if text_lower in item.text().lower():
                self.topic_list.setCurrentItem(item)
                break
    
    def show_topic(self, topic_id: str):
        """Show help topic."""
        content = self.HELP_CONTENT.get(topic_id, "<h1>Topic not found</h1>")
        
        self.content_browser.setHtml(content)
        
        # Update title
        titles = {
            "welcome": "Welcome",
            "scripts": "Scripts",
            "connections": "Connections",
            "logs": "Logs",
            "settings": "Settings",
            "troubleshooting": "Troubleshooting",
            "keyboard_shortcuts": "Keyboard Shortcuts",
        }
        
        self.title_label.setText(titles.get(topic_id, topic_id))
        
        # Update list selection
        for i in range(self.topic_list.count()):
            item = self.topic_list.item(i)
            if item.data(Qt.ItemDataRole.UserRole) == topic_id:
                self.topic_list.setCurrentItem(item)
                break
    
    def search_content(self, query: str) -> List[Tuple[str, str]]:
        """
        Search help content.
        
        Returns:
            List of (topic_id, matching_text) tuples
        """
        results = []
        
        for topic_id, content in self.HELP_CONTENT.items():
            if query.lower() in content.lower():
                # Extract first 100 chars of matching content
                idx = content.lower().find(query.lower())
                snippet = content[idx:idx+100].replace("\n", " ")
                results.append((topic_id, snippet))
        
        return results


class HelpTour:
    """Interactive help tour for new users."""
    
    def __init__(self, parent: QWidget):
        self.parent = parent
        self.current_step = 0
        self.steps = []
    
    def add_step(self, widget: QWidget, message: str):
        """Add a tour step."""
        self.steps.append((widget, message))
    
    def start(self):
        """Start the tour."""
        if not self.steps:
            return
        
        self.current_step = 0
        self._show_step()
    
    def next(self):
        """Go to next step."""
        self.current_step += 1
        
        if self.current_step >= len(self.steps):
            self.end()
        else:
            self._show_step()
    
    def _show_step(self):
        """Show current step."""
        widget, message = self.steps[self.current_step]
        
        # TODO: Implement highlight and tooltip
        # For now, just print
        print(f"Tour step {self.current_step + 1}/{len(self.steps)}: {message}")
    
    def end(self):
        """End the tour."""
        self.current_step = 0
        self.steps = []


def show_help_tour(main_window) -> HelpTour:
    """Create and show help tour for main window."""
    tour = HelpTour(main_window)
    
    # Add tour steps
    # tour.add_step(scripts_panel, "Manage your automation scripts here")
    # tour.add_step(connections_panel, "Configure server connections")
    # tour.add_step(logs_panel, "View application logs")
    # tour.add_step(settings_button, "Customize application settings")
    
    return tour
