"""
Log entry models for NeonLink Desktop.

Defines data structures for logging and log entries.
"""

from enum import Enum
from datetime import datetime
from pydantic import BaseModel, Field
from typing import Optional


class LogLevel(str, Enum):
    """Log levels."""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


class LogEntry(BaseModel):
    """
    Model for a single log entry.
    
    Attributes:
        timestamp: When the log entry was created
        level: Log severity level
        message: Log message
        source: Source of the log (script name, module, etc.)
        script_id: Associated script ID (if applicable)
        line_number: Line number in source file (if available)
    """
    
    timestamp: datetime = Field(default_factory=datetime.now)
    level: LogLevel = LogLevel.INFO
    message: str
    source: Optional[str] = None
    script_id: Optional[str] = None
    line_number: Optional[int] = None
    
    @property
    def level_icon(self) -> str:
        """Get icon based on log level."""
        icons = {
            LogLevel.DEBUG: "🔍",
            LogLevel.INFO: "ℹ️",
            LogLevel.WARNING: "⚠️",
            LogLevel.ERROR: "❌",
            LogLevel.CRITICAL: "🔴",
        }
        return icons.get(self.level, "📝")
    
    @property
    def formatted_timestamp(self) -> str:
        """Get formatted timestamp for display."""
        return self.timestamp.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    
    def to_display_string(self) -> str:
        """Get string for display in log widget."""
        parts = [self.formatted_timestamp]
        
        if self.source:
            parts.append(f"[{self.source}]")
        
        parts.append(f"{self.level_icon} {self.message}")
        
        return " ".join(parts)


class LogBuffer(BaseModel):
    """
    Circular buffer for log entries.
    
    Attributes:
        entries: List of log entries
        max_size: Maximum number of entries to keep
    """
    
    entries: list[LogEntry] = Field(default_factory=list)
    max_size: int = Field(default=1000, ge=1, le=10000)
    
    def add(self, entry: LogEntry) -> None:
        """Add a new entry to the buffer."""
        self.entries.append(entry)
        
        # Remove old entries if buffer is full
        if len(self.entries) > self.max_size:
            self.entries = self.entries[-self.max_size:]
    
    def clear(self) -> None:
        """Clear all entries."""
        self.entries.clear()
    
    def get_recent(self, count: int = 100) -> list[LogEntry]:
        """Get recent entries."""
        return self.entries[-count:]
    
    def filter_by_level(self, level: LogLevel) -> list[LogEntry]:
        """Filter entries by log level."""
        return [e for e in self.entries if e.level == level]
    
    def filter_by_source(self, source: str) -> list[LogEntry]:
        """Filter entries by source."""
        return [e for e in self.entries if e.source == source]
