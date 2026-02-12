"""
Script models for NeonLink Desktop.

Defines data structures for script management.
"""

from enum import Enum
from pathlib import Path
from datetime import datetime
from pydantic import BaseModel, Field, field_validator
from typing import Optional


class ScriptType(str, Enum):
    """Types of supported scripts."""
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


class ScriptModel(BaseModel):
    """
    Model for script storage and management.
    
    Attributes:
        id:-based)
        name Unique identifier (timestamp: Display name of the script
        source_path: Path to the source file
        install_method: How to install the script
        target_directory: Target directory for installation
        script_type: Type of script (Python/Bash/PowerShell)
        arguments: Command-line arguments
        environment: Environment variables (dict)
        auto_start: Auto-start on application launch
        enabled: Script is enabled in the list
        created_at: Creation timestamp
        updated_at: Last modification timestamp
    """
    
    id: str = Field(default_factory=lambda: str(datetime.now().timestamp()))
    name: str = Field(..., min_length=1, max_length=100)
    source_path: Path
    install_method: ScriptInstallMethod = ScriptInstallMethod.COPY
    target_directory: Optional[Path] = None
    script_type: ScriptType
    arguments: str = ""
    environment: dict[str, str] = Field(default_factory=dict)
    auto_start: bool = False
    enabled: bool = True
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)
    
    @field_validator('source_path')
    @classmethod
    def validate_source_path(cls, v: Path) -> Path:
        """Validate that source path exists."""
        if not v.exists():
            # Allow non-existent paths for newly created scripts
            return v
        if not v.is_file():
            raise ValueError(f"Source path is not a file: {v}")
        return v
    
    @property
    def file_size(self) -> int:
        """Get file size in bytes."""
        if self.source_path.exists():
            return self.source_path.stat().st_size
        return 0
    
    @property
    def extension(self) -> str:
        """Get file extension."""
        return self.source_path.suffix.lower()
    
    @property
    def is_python(self) -> bool:
        """Check if script is Python."""
        return self.extension == '.py' or self.script_type == ScriptType.PYTHON
    
    @property
    def is_bash(self) -> bool:
        """Check if script is Bash."""
        return self.extension == '.sh' or self.script_type == ScriptType.BASH
    
    @property
    def is_powershell(self) -> bool:
        """Check if script is PowerShell."""
        return self.extension in ('.ps1', '.psm1') or self.script_type == ScriptType.POWERSHELL
    
    @property
    def icon(self) -> str:
        """Get icon emoji based on script type."""
        if self.is_python:
            return "🐍"
        elif self.is_bash:
            return "💻"
        elif self.is_powershell:
            return "⚡"
        return "📄"


class RunningScript(BaseModel):
    """
    Information about a running script process.
    
    Attributes:
        script: The script model
        status: Current execution status
        pid: Process ID
        start_time: When the script was started
        exit_code: Exit code (if finished)
        stdout_buffer: Captured stdout lines
        stderr_buffer: Captured stderr lines
    """
    
    script: ScriptModel
    status: ScriptStatus = ScriptStatus.IDLE
    pid: Optional[int] = None
    start_time: Optional[datetime] = None
    exit_code: Optional[int] = None
    stdout_buffer: list[str] = Field(default_factory=list)
    stderr_buffer: list[str] = Field(default_factory=list)
    
    @property
    def duration_seconds(self) -> Optional[float]:
        """Get script duration in seconds."""
        if self.start_time:
            return (datetime.now() - self.start_time).total_seconds()
        return None
