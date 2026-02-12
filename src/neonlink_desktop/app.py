"""
Main application class for NeonLink Desktop Control Center.

This module initializes the application, sets up logging, and manages
the main event loop.
"""

import sys
import os
import asyncio
from pathlib import Path
from typing import Optional

from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import Qt, QDir

# Setup paths
_root_dir = Path(__file__).parent.parent
if str(_root_dir) not in sys.path:
    sys.path.insert(0, str(_root_dir))


class NeonLinkApp(QApplication):
    """
    Main application class for NeonLink Control Center.
    
    Attributes:
        version: Application version string
        debug: Debug mode flag
        theme: Current UI theme
    """
    
    version = "1.0.0"
    
    def __init__(
        self,
        debug: bool = False,
        theme: str = "dark"
    ):
        super().__init__(['neonlink'])
        
        self._debug = debug
        self._theme = theme
        
        # Initialize application
        self._init_application()
        self._setup_logging()
        
    def _init_application(self) -> None:
        """Initialize application settings."""
        # Application metadata
        self.setApplicationName("NeonLink Control Center")
        self.setApplicationVersion(self.version)
        self.setOrganizationName("NeonLink")
        
        # Window settings (PyQt6 uses different enum names)
        try:
            from PyQt6.QtCore import Qt
            self.setAttribute(Qt.WidgetAttribute.AA_EnableHighDpiScaling)
            self.setAttribute(Qt.WidgetAttribute.AA_UseHighDpiPixmaps)
        except (ImportError, AttributeError):
            pass
        
        # Style settings
        self.setStyle("Fusion")
        
        # File system
        QDir.setSearchPaths(":/icons", [
            str(Path(__file__).parent / "resources" / "icons")
        ])
        
    def _setup_logging(self) -> None:
        """Configure logging for the application."""
        import logging
        from loguru import logger
        
        # Remove default handler
        logger.remove()
        
        # Determine log level
        log_level = "DEBUG" if self._debug else "INFO"
        
        # Console output
        logger.add(
            sys.stderr,
            level=log_level,
            format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
                   "<level>{level: <8}</level> | "
                   "<cyan>{message}</cyan>",
            colorize=True
        )
        
        # File output
        log_dir = Path.home() / '.config' / 'neonlink' / 'logs'
        log_dir.mkdir(parents=True, exist_ok=True)
        
        logger.add(
            str(log_dir / "neonlink_{time:YYYY-MM-DD}.log"),
            rotation="1 day",
            retention="7 days",
            level=log_level,
            format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {message}"
        )
        
        # Configure standard logging
        logging.basicConfig(
            level=getattr(logging, log_level),
            format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        )
        
    def run(self) -> int:
        """Run the application event loop."""
        from neonlink_desktop.views.main_window import MainWindow
        from neonlink_desktop.services.config_manager import ConfigManager
        from neonlink_desktop.models.config_model import AppConfigModel
        
        try:
            # Load or create configuration
            config_manager = ConfigManager(AppConfigModel)
            config = config_manager.load()
            
            # Apply saved theme
            theme = config.theme if hasattr(config, 'theme') else self._theme
            self.set_theme(theme)
            
            # Create and show main window
            window = MainWindow()
            window.show()
            
            # Event loop
            return self.exec()
            
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Application error: {e}")
            if self._debug:
                import traceback
                traceback.print_exc()
            return 1
    
    def get_theme(self) -> str:
        """Get current theme."""
        return self._theme
    
    def set_theme(self, theme: str) -> None:
        """Set application theme."""
        self._theme = theme
        
        # Load stylesheet
        style_path = Path(__file__).parent / "resources" / "styles"
        
        if theme == "dark":
            qss_path = style_path / "dark_theme.qss"
        else:
            qss_path = style_path / "light_theme.qss"
        
        if qss_path.exists():
            with open(qss_path, 'r', encoding='utf-8') as f:
                self.setStyleSheet(f.read())
        else:
            # Fallback to default dark theme
            self.setStyleSheet("")
