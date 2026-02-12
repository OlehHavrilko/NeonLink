"""
Configuration constants for NeonLink Desktop Control Center.
"""

import os
from pathlib import Path
from enum import Enum


class AppConfig:
    """Application configuration constants."""
    
    # Version
    VERSION = "1.0.0"
    APP_NAME = "NeonLink Control Center"
    
    # Paths
    CONFIG_DIR = Path.home() / '.config' / 'neonlink'
    SCRIPTS_DIR = CONFIG_DIR / 'scripts'
    LOGS_DIR = CONFIG_DIR / 'logs'
    
    # Files
    CONFIG_FILE = CONFIG_DIR / 'config.enc'
    CONNECTIONS_FILE = CONFIG_DIR / 'connections.enc'
    MASTER_KEY_FILE = CONFIG_DIR / '.master_key'
    
    # Encryption settings (PBKDF2)
    SALT_SIZE = 32
    KEY_LENGTH = 32  # 256 bits for AES-256
    ITERATIONS = 600_000  # OWASP recommendation
    
    # UI settings
    DEFAULT_THEME = "dark"
    WINDOW_MIN_WIDTH = 1200
    WINDOW_MIN_HEIGHT = 800
    WINDOW_DEFAULT_WIDTH = 1400
    WINDOW_DEFAULT_HEIGHT = 900


class ScriptType(str, Enum):
    """Supported script types."""
    PYTHON = "python"
    BASH = "bash"
    POWERSHELL = "powershell"


class ScriptInstallMethod(str, Enum):
    """Script installation methods."""
    COPY = "copy"
    SYMLINK = "symlink"
    PATH = "path"


class ScriptStatus(str, Enum):
    """Script execution status."""
    IDLE = "idle"
    RUNNING = "running"
    STOPPED = "stopped"
    ERROR = "error"


class ConnectionStatus(str, Enum):
    """Connection status."""
    UNKNOWN = "unknown"
    CONNECTING = "connecting"
    CONNECTED = "connected"
    DISCONNECTED = "disconnected"
    ERROR = "error"


class LogLevel(str, Enum):
    """Log levels."""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


class Platform(str, Enum):
    """Supported platforms."""
    WINDOWS = "windows"
    MACOS = "macos"
    LINUX = "linux"


def get_platform() -> Platform:
    """Get current platform."""
    import sys
    if sys.platform == "win32":
        return Platform.WINDOWS
    elif sys.platform == "darwin":
        return Platform.MACOS
    else:
        return Platform.LINUX


def get_python_executable() -> Path:
    """Get Python executable path."""
    import sys
    return Path(sys.executable)


def get_bash_executable() -> Path:
    """Get Bash executable path (Unix only)."""
    import shutil
    bash_path = shutil.which("bash")
    if bash_path:
        return Path(bash_path)
    return Path("/bin/bash")


def get_powershell_executable() -> Path:
    """Get PowerShell executable path (Windows only)."""
    import shutil
    # Try PowerShell Core (pwsh) first
    pwsh_path = shutil.which("pwsh")
    if pwsh_path:
        return Path(pwsh_path)
    # Fallback to Windows PowerShell
    return Path("powershell.exe")
