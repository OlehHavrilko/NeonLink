"""
Application configuration models for NeonLink Desktop.

Defines the main application configuration structure.
"""

from pydantic import BaseModel, Field, ConfigDict
from typing import Optional
from datetime import datetime


class AppConfigModel(BaseModel):
    """
    Main application configuration model.
    
    Attributes:
        theme: UI theme (dark/light)
        language: Interface language code
        auto_start: Auto-start application on login
        minimize_to_tray: Minimize to system tray instead of closing
        check_updates: Check for updates on startup
        update_channel: Update channel (stable/beta)
        max_log_entries: Maximum number of log entries to keep
        default_port: Default connection port
        recent_connections: List of recently connected profiles
    """
    
    model_config = ConfigDict(
        populate_by_name=True,
        ser_json_timedelta="iso8601",
    )
    
    theme: str = Field(default="dark", pattern="^(dark|light)$")
    language: str = Field(default="en")
    auto_start: bool = False
    minimize_to_tray: bool = True
    check_updates: bool = True
    update_channel: str = Field(default="stable", pattern="^(stable|beta)$")
    max_log_entries: int = Field(default=1000, ge=100, le=10000)
    default_port: int = Field(default=9876, ge=1, le=65535)
    recent_connections: list[str] = Field(default_factory=list)
    last_opened: Optional[datetime] = None
