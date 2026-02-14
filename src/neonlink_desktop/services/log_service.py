"""
LogService - Centralized logging service for NeonLink Desktop.

Integrates:
- Loguru for console/file logging
- SQLite database for persistent storage
- Real-time log broadcasting
"""

import asyncio
import sys
import logging
from pathlib import Path
from datetime import datetime
from typing import Optional, List, Callable, Any
from contextlib import asynccontextmanager

from loguru import logger as _loguru_logger
from loguru._defaults import LOGURU_FORMAT

from models.log_entry import LogEntry, LogLevel
from services.database_service import DatabaseService, get_database_service


class LogService:
    """
    Centralized logging service with multiple output destinations.
    
    Features:
    - Console logging via Loguru
    - File logging with rotation
    - SQLite database storage
    - Real-time log callbacks
    - Log filtering by level
    """
    
    # Default log file path
    LOG_DIR = Path.home() / '.config' / 'neonlink' / 'logs'
    LOG_FILE = LOG_DIR / 'neonlink.log'
    
    # Log retention settings
    DEFAULT_MAX_LOG_SIZE = 10 * 1024 * 1024  # 10 MB
    DEFAULT_BACKUP_COUNT = 5
    
    def __init__(
        self,
        log_file: Optional[Path] = None,
        max_size: int = DEFAULT_MAX_LOG_SIZE,
        backup_count: int = DEFAULT_BACKUP_COUNT,
        level: str = "INFO",
    ):
        """
        Initialize LogService.
        
        Args:
            log_file: Custom log file path
            max_size: Maximum log file size before rotation
            backup_count: Number of backup files to keep
            level: Minimum log level
        """
        self.log_file = log_file or self.LOG_FILE
        self.max_size = max_size
        self.backup_count = backup_count
        self.min_level = level
        
        self._db_service: Optional[DatabaseService] = None
        self._callbacks: List[Callable[[LogEntry], None]] = []
        self._log_buffer: List[LogEntry] = []
        self._buffer_size = 100
        self._buffer_timer: Optional[asyncio.Task] = None
        self._is_initialized = False
    
    async def initialize(self):
        """Initialize log service and configure logging."""
        if self._is_initialized:
            return
        
        # Ensure log directory exists
        self.LOG_DIR.mkdir(parents=True, exist_ok=True)
        
        # Configure Loguru
        self._configure_loguru()
        
        # Initialize database
        self._db_service = await get_database_service()
        
        self._is_initialized = True
        
        # Start buffer flush timer
        self._start_buffer_timer()
        
        # Log startup
        self.info("LogService initialized", source="LogService")
    
    def _configure_loguru(self):
        """Configure Loguru logger."""
        # Remove default handler
        _loguru_logger.remove()
        
        # Console handler with color
        _loguru_logger.add(
            sys.stderr,
            format=LOGURU_FORMAT,
            level=self.min_level,
            colorize=True,
        )
        
        # File handler with rotation
        _loguru_logger.add(
            str(self.log_file),
            format=LOGURU_FORMAT,
            level=self.min_level,
            rotation=self.max_size,
            retention=self.backup_count,
            compression="zip",
            encoding="utf-8",
        )
    
    def _start_buffer_timer(self):
        """Start periodic buffer flush."""
        async def flush_loop():
            while True:
                await asyncio.sleep(5)  # Flush every 5 seconds
                await self._flush_buffer()
        
        self._buffer_timer = asyncio.create_task(flush_loop())
    
    async def _flush_buffer(self):
        """Flush log buffer to database."""
        if not self._log_buffer or not self._db_service:
            return
        
        entries = self._log_buffer.copy()
        self._log_buffer.clear()
        
        try:
            await self._db_service.add_logs_batch(entries)
        except Exception as e:
            # Fallback to console if DB fails
            _loguru_logger.error(f"Failed to flush log buffer: {e}")
    
    def _add_to_buffer(self, entry: LogEntry):
        """Add entry to buffer for batch database insert."""
        self._log_buffer.append(entry)
        
        # Flush immediately if buffer is full
        if len(self._log_buffer) >= self._buffer_size:
            asyncio.create_task(self._flush_buffer())
    
    def _notify_callbacks(self, entry: LogEntry):
        """Notify all registered callbacks."""
        for callback in self._callbacks:
            try:
                callback(entry)
            except Exception as e:
                _loguru_logger.error(f"Log callback error: {e}")
    
    def add_callback(self, callback: Callable[[LogEntry], None]):
        """Add a callback for real-time log notifications."""
        self._callbacks.append(callback)
    
    def remove_callback(self, callback: Callable[[LogEntry], None]):
        """Remove a log callback."""
        if callback in self._callbacks:
            self._callbacks.remove(callback)
    
    def _create_entry(
        self,
        level: LogLevel,
        message: str,
        source: Optional[str] = None,
        script_id: Optional[str] = None,
        line_number: Optional[int] = None,
    ) -> LogEntry:
        """Create a LogEntry instance."""
        return LogEntry(
            timestamp=datetime.now(),
            level=level,
            message=message,
            source=source,
            script_id=script_id,
            line_number=line_number,
        )
    
    def _log(
        self,
        level: LogLevel,
        message: str,
        source: Optional[str] = None,
        script_id: Optional[str] = None,
        line_number: Optional[int] = None,
    ):
        """Internal logging method."""
        # Create entry
        entry = self._create_entry(level, message, source, script_id, line_number)
        
        # Log to Loguru
        log_method = getattr(_loguru_logger, level.value.lower())
        log_method(f"[{source}] {message}" if source else message)
        
        # Add to database buffer
        if self._db_service:
            self._add_to_buffer(entry)
        
        # Notify callbacks
        self._notify_callbacks(entry)
    
    # Public logging methods
    
    def debug(self, message: str, source: Optional[str] = None, **kwargs):
        """Log debug message."""
        self._log(LogLevel.DEBUG, message, source, **kwargs)
    
    def info(self, message: str, source: Optional[str] = None, **kwargs):
        """Log info message."""
        self._log(LogLevel.INFO, message, source, **kwargs)
    
    def warning(self, message: str, source: Optional[str] = None, **kwargs):
        """Log warning message."""
        self._log(LogLevel.WARNING, message, source, **kwargs)
    
    def error(self, message: str, source: Optional[str] = None, **kwargs):
        """Log error message."""
        self._log(LogLevel.ERROR, message, source, **kwargs)
    
    def critical(self, message: str, source: Optional[str] = None, **kwargs):
        """Log critical message."""
        self._log(LogLevel.CRITICAL, message, source, **kwargs)
    
    # Script-specific logging
    
    def log_script_start(self, script_name: str, script_id: str):
        """Log script start."""
        self.info(
            f"Script started: {script_name}",
            source="ScriptRunner",
            script_id=script_id,
        )
    
    def log_script_complete(
        self,
        script_name: str,
        script_id: str,
        exit_code: int,
        duration: float,
    ):
        """Log script completion."""
        if exit_code == 0:
            self.info(
                f"Script completed: {script_name} (exit code: {exit_code}, duration: {duration:.2f}s)",
                source="ScriptRunner",
                script_id=script_id,
            )
        else:
            self.error(
                f"Script failed: {script_name} (exit code: {exit_code}, duration: {duration:.2f}s)",
                source="ScriptRunner",
                script_id=script_id,
            )
    
    def log_script_output(
        self,
        script_id: str,
        output: str,
        is_error: bool = False,
    ):
        """Log script output."""
        level = LogLevel.ERROR if is_error else LogLevel.INFO
        self._log(
            level,
            output.strip(),
            source="ScriptRunner",
            script_id=script_id,
        )
    
    def log_connection(self, connection_name: str, status: str, details: str = ""):
        """Log connection event."""
        message = f"Connection {status}: {connection_name}"
        if details:
            message += f" - {details}"
        
        if status == "success":
            self.info(message, source="ConnectionManager")
        else:
            self.warning(message, source="ConnectionManager")
    
    def log_config_change(self, key: str, old_value: Any, new_value: Any):
        """Log configuration change."""
        self.info(
            f"Config changed: {key} = {new_value} (was: {old_value})",
            source="ConfigManager",
        )
    
    # Async context manager for script logging
    
    @asynccontextmanager
    async def script_context(self, script_name: str, script_id: str):
        """Context manager for script execution with automatic logging."""
        start_time = datetime.now()
        self.log_script_start(script_name, script_id)
        
        try:
            yield
        except Exception as e:
            duration = (datetime.now() - start_time).total_seconds()
            self.error(
                f"Script error: {script_name} - {str(e)}",
                source="ScriptRunner",
                script_id=script_id,
            )
            raise
        finally:
            duration = (datetime.now() - start_time).total_seconds()
            # This won't be reached on exception, but it's okay
    
    # Database query methods
    
    async def get_logs(
        self,
        level: Optional[LogLevel] = None,
        source: Optional[str] = None,
        script_id: Optional[str] = None,
        search_text: Optional[str] = None,
        limit: int = 100,
    ) -> List[LogEntry]:
        """Get logs from database."""
        if not self._db_service:
            return []
        
        return await self._db_service.get_logs(
            level=level,
            source=source,
            script_id=script_id,
            search_text=search_text,
            limit=limit,
        )
    
    async def get_log_stats(self) -> dict:
        """Get log statistics."""
        if not self._db_service:
            return {}
        
        level_counts = await self._db_service.get_log_count_by_level()
        sources = await self._db_service.get_log_sources()
        db_size = await self._db_service.get_database_size()
        
        return {
            "by_level": {level.value: count for level, count in level_counts.items()},
            "sources": sources,
            "database_size": db_size,
        }
    
    async def cleanup_old_logs(self, days: int = 30) -> int:
        """Clean up old logs."""
        if not self._db_service:
            return 0
        
        count = await self._db_service.delete_old_logs(days)
        self.info(f"Cleaned up {count} old log entries", source="LogService")
        return count
    
    async def shutdown(self):
        """Shutdown log service gracefully."""
        # Flush remaining buffer
        await self._flush_buffer()
        
        # Cancel buffer timer
        if self._buffer_timer:
            self._buffer_timer.cancel()
            try:
                await self._buffer_timer
            except asyncio.CancelledError:
                pass
        
        # Close database
        if self._db_service:
            await self._db_service.close()
        
        self.info("LogService shut down", source="LogService")
        
        # Remove all handlers
        _loguru_logger.remove()


# Singleton instance
_log_service: Optional[LogService] = None


def get_log_service() -> LogService:
    """Get singleton LogService instance."""
    global _log_service
    
    if _log_service is None:
        _log_service = LogService()
    
    return _log_service


async def initialize_log_service() -> LogService:
    """Initialize and get LogService."""
    service = get_log_service()
    await service.initialize()
    return service


async def shutdown_log_service():
    """Shutdown LogService."""
    global _log_service
    
    if _log_service:
        await _log_service.shutdown()
        _log_service = None
