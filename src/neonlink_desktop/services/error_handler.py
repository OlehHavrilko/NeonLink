"""
ErrorHandler - Global exception handler for NeonLink Desktop.

Features:
- Global exception catching
- Stack trace logging
- User-friendly error messages
- Optional crash reports
- Error recovery
"""

import sys
import traceback
import asyncio
from pathlib import Path
from datetime import datetime
from typing import Optional, Callable, Any, Dict
from dataclasses import dataclass
from enum import Enum
import threading

from loguru import logger as _loguru_logger


class ErrorSeverity(str, Enum):
    """Error severity levels."""
    DEBUG = "debug"
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"


@dataclass
class ErrorInfo:
    """Error information."""
    timestamp: datetime
    error_type: str
    message: str
    traceback: str
    severity: ErrorSeverity
    source: str
    context: Dict[str, Any]
    
    def to_dict(self) -> dict:
        """Convert to dictionary."""
        return {
            "timestamp": self.timestamp.isoformat(),
            "error_type": self.error_type,
            "message": self.message,
            "traceback": self.traceback,
            "severity": self.severity.value,
            "source": self.source,
            "context": self.context,
        }


class ErrorHandler:
    """
    Global error handler for the application.
    
    Features:
    - Thread-safe error handling
    - Configurable error callbacks
    - Automatic logging
    - User notification
    - Recovery actions
    """
    
    # Error log directory
    ERROR_LOG_DIR = Path.home() / '.config' / 'neonlink' / 'error_logs'
    
    def __init__(
        self,
        log_errors: bool = True,
        show_user_errors: bool = True,
        crash_report_enabled: bool = False,
    ):
        """
        Initialize ErrorHandler.
        
        Args:
            log_errors: Log errors to file
            show_user_errors: Show user-friendly error dialogs
            crash_report_enabled: Enable crash report collection
        """
        self.log_errors = log_errors
        self.show_user_errors = show_user_errors
        self.crash_report_enabled = crash_report_enabled
        
        self._original_excepthook = sys.excepthook
        self._original_thread_excepthook = None
        self._error_callbacks: list[Callable[[ErrorInfo], None]] = []
        self._recovery_actions: Dict[str, Callable] = {}
        self._error_count = 0
        self._lock = threading.Lock()
        
        self._setup_directories()
    
    def _setup_directories(self):
        """Setup error log directories."""
        self.ERROR_LOG_DIR.mkdir(parents=True, exist_ok=True)
    
    def register(self):
        """Register error handlers."""
        # Register main exception handler
        sys.excepthook = self._handle_exception
        
        # Register thread exception handler
        if hasattr(threading, 'ThreadExcepthook'):
            try:
                self._original_thread_excepthook = threading.ThreadExcepthook
                threading.ThreadExcepthook = self._handle_thread_exception
            except Exception:
                pass
        
        # Register asyncio exception handler
        try:
            asyncio.get_event_loop().set_exception_handler(self._handle_asyncio_exception)
        except Exception:
            pass
    
    def unregister(self):
        """Unregister error handlers."""
        sys.excepthook = self._original_excepthook
        
        if self._original_thread_excepthook:
            threading.ThreadExcepthook = self._original_thread_excepthook
    
    def _handle_exception(
        self,
        exc_type: type,
        exc_value: BaseException,
        exc_traceback: Any,
    ):
        """Handle uncaught exceptions."""
        self._handle_error(
            exc_type=exc_type,
            exc_value=exc_value,
            exc_traceback=exc_traceback,
            source="main",
            thread_name="MainThread",
        )
        
        # Call original excepthook for Python's default behavior
        if self._original_excepthook:
            self._original_excepthook(exc_type, exc_value, exc_traceback)
    
    def _handle_thread_exception(
        self,
        args: threading.ExceptHookArgs,
    ):
        """Handle thread exceptions."""
        self._handle_error(
            exc_type=args.exc_type,
            exc_value=args.exc_value,
            exc_traceback=args.exc_traceback,
            source="thread",
            thread_name=args.thread.name if args.thread else "Unknown",
        )
        
        if self._original_thread_excepthook:
            self._original_thread_excepthook(args)
    
    def _handle_asyncio_exception(
        self,
        loop: asyncio.AbstractEventLoop,
        context: Dict[str, Any],
    ):
        """Handle asyncio exceptions."""
        exc_type = context.get('exception type', Exception)
        exc_value = context.get('exception', Exception())
        exc_traceback = context.get('traceback', '')
        
        self._handle_error(
            exc_type=exc_type,
            exc_value=exc_value,
            exc_traceback=exc_traceback,
            source="asyncio",
            thread_name=context.get('task', 'Unknown').get_name() if context.get('task') else "Unknown",
        )
    
    def _handle_error(
        self,
        exc_type: type,
        exc_value: BaseException,
        exc_traceback: Any,
        source: str,
        thread_name: str = "Unknown",
    ):
        """Internal error handling."""
        with self._lock:
            self._error_count += 1
        
        # Get traceback string
        if exc_traceback and exc_traceback != '':
            traceback_str = ''.join(traceback.format_exception(exc_type, exc_value, exc_traceback))
        else:
            traceback_str = str(exc_value)
        
        # Determine severity
        severity = self._determine_severity(exc_type)
        
        # Create error info
        error_info = ErrorInfo(
            timestamp=datetime.now(),
            error_type=exc_type.__name__ if exc_type else "Unknown",
            message=str(exc_value),
            traceback=traceback_str,
            severity=severity,
            source=source,
            context={
                "thread": thread_name,
                "error_count": self._error_count,
            },
        )
        
        # Log error
        self._log_error(error_info)
        
        # Save crash report if enabled
        if self.crash_report_enabled:
            self._save_crash_report(error_info)
        
        # Notify callbacks
        for callback in self._error_callbacks:
            try:
                callback(error_info)
            except Exception:
                pass
    
    def _determine_severity(self, exc_type: type) -> ErrorSeverity:
        """Determine error severity based on exception type."""
        if exc_type in (KeyboardInterrupt, SystemExit):
            return ErrorSeverity.INFO
        elif exc_type in (MemoryError, RecursionError):
            return ErrorSeverity.CRITICAL
        elif issubclass(exc_type, Exception):
            return ErrorSeverity.ERROR
        else:
            return ErrorSeverity.WARNING
    
    def _log_error(self, error_info: ErrorInfo):
        """Log error to appropriate destination."""
        # Log to Loguru
        log_method = getattr(_loguru_logger, error_info.severity.value)
        
        log_method(
            f"[{error_info.source}] {error_info.error_type}: {error_info.message}\n"
            f"Thread: {error_info.context.get('thread')}\n"
            f"Traceback:\n{error_info.traceback}"
        )
        
        # Log to error file
        if self.log_errors:
            self._log_to_file(error_info)
    
    def _log_to_file(self, error_info: ErrorInfo):
        """Log error to file."""
        log_file = self.ERROR_LOG_DIR / f"error_{error_info.timestamp.strftime('%Y%m%d_%H%M%S')}.log"
        
        content = [
            f"Timestamp: {error_info.timestamp.isoformat()}",
            f"Type: {error_info.error_type}",
            f"Severity: {error_info.severity.value}",
            f"Source: {error_info.source}",
            f"Thread: {error_info.context.get('thread')}",
            f"Message: {error_info.message}",
            "",
            "Traceback:",
            error_info.traceback,
        ]
        
        log_file.write_text('\n'.join(content), encoding='utf-8')
    
    def _save_crash_report(self, error_info: ErrorInfo):
        """Save crash report for analysis."""
        crash_file = self.ERROR_LOG_DIR / f"crash_{error_info.timestamp.strftime('%Y%m%d_%H%M%S')}.json"
        
        import json
        
        crash_file.write_text(
            json.dumps(error_info.to_dict(), indent=2),
            encoding='utf-8'
        )
    
    def add_callback(self, callback: Callable[[ErrorInfo], None]):
        """Add error callback."""
        self._error_callbacks.append(callback)
    
    def remove_callback(self, callback: Callable[[ErrorInfo], None]):
        """Remove error callback."""
        if callback in self._error_callbacks:
            self._error_callbacks.remove(callback)
    
    def register_recovery_action(self, error_type: str, action: Callable):
        """Register a recovery action for specific error type."""
        self._recovery_actions[error_type] = action
    
    def attempt_recovery(self, error_info: ErrorInfo) -> bool:
        """Attempt to recover from error."""
        if error_info.error_type in self._recovery_actions:
            try:
                action = self._recovery_actions[error_info.error_type]
                action(error_info)
                return True
            except Exception:
                pass
        return False
    
    def get_error_count(self) -> int:
        """Get total error count."""
        return self._error_count
    
    def get_recent_errors(self, count: int = 10) -> list[ErrorInfo]:
        """Get recent error logs."""
        error_files = sorted(
            self.ERROR_LOG_DIR.glob("error_*.log"),
            key=lambda p: p.stat().st_mtime,
            reverse=True
        )[:count]
        
        errors = []
        
        for f in error_files:
            try:
                content = f.read_text(encoding='utf-8')
                lines = content.split('\n')
                
                error_info = ErrorInfo(
                    timestamp=datetime.fromisoformat(lines[0].split(': ', 1)[1]),
                    error_type=lines[1].split(': ', 1)[1],
                    message=lines[4].split(': ', 1)[1],
                    traceback='\n'.join(lines[7:]),
                    severity=ErrorSeverity(lines[2].split(': ', 1)[1]),
                    source=lines[3].split(': ', 1)[1],
                    context={},
                )
                
                errors.append(error_info)
            except Exception:
                continue
        
        return errors
    
    def clear_error_logs(self) -> int:
        """Clear old error logs."""
        count = 0
        
        for f in self.ERROR_LOG_DIR.glob("error_*.log"):
            try:
                f.unlink()
                count += 1
            except Exception:
                pass
        
        return count
    
    def get_user_message(self, error_info: ErrorInfo) -> str:
        """Get user-friendly error message."""
        messages = {
            "ConnectionError": "Не удалось подключиться к серверу. Проверьте интернет-соединение.",
            "TimeoutError": "Время ожидания истекло. Попробуйте позже.",
            "FileNotFoundError": "Файл не найден. Проверьте путь к файлу.",
            "PermissionError": "Нет доступа к файлу или папке.",
            "MemoryError": "Недостаточно памяти. Закройте другие приложения.",
            "EncryptionError": "Ошибка шифрования. Проверьте пароль.",
        }
        
        return messages.get(
            error_info.error_type,
            f"Произошла ошибка: {error_info.message}"
        )


# Singleton instance
_error_handler: Optional[ErrorHandler] = None


def get_error_handler() -> ErrorHandler:
    """Get singleton ErrorHandler instance."""
    global _error_handler
    
    if _error_handler is None:
        _error_handler = ErrorHandler()
    
    return _error_handler


def initialize_error_handler(**kwargs) -> ErrorHandler:
    """Initialize and register ErrorHandler."""
    global _error_handler
    
    _error_handler = ErrorHandler(**kwargs)
    _error_handler.register()
    
    return _error_handler


def shutdown_error_handler():
    """Shutdown ErrorHandler."""
    global _error_handler
    
    if _error_handler:
        _error_handler.unregister()
        _error_handler = None
