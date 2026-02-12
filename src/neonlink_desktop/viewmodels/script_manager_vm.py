"""
ScriptManagerViewModel - ViewModel for script management.

Handles business logic for adding, removing, and executing scripts.
"""

import asyncio
from pathlib import Path
from typing import Optional
from PyQt6.QtCore import pyqtSignal, QObject

from .base_viewmodel import BaseViewModel
from ..models.script_model import ScriptModel, ScriptType, RunningScript, ScriptStatus
from ..services.script_runner import ScriptRunner, ScriptExecutionError
from ..services.script_installer import ScriptInstaller


class ScriptManagerViewModel(BaseViewModel):
    """
    ViewModel for managing scripts.
    
    Signals:
        scriptsChanged: Emitted when scripts list changes
        scriptAdded: Emitted when a script is added
        scriptRemoved: Emitted when a script is removed
        scriptStatusChanged: Emitted when script status changes
    """
    
    scriptsChanged = pyqtSignal()
    scriptAdded = pyqtSignal(ScriptModel)
    scriptRemoved = pyqtSignal(str)
    scriptStatusChanged = pyqtSignal(str, ScriptStatus)
    
    def __init__(self, script_runner: ScriptRunner):
        """
        Initialize ScriptManagerViewModel.
        
        Args:
            script_runner: ScriptRunner service instance
        """
        super().__init__()
        self._script_runner = script_runner
        self._script_installer = ScriptInstaller()
        self._scripts: list[ScriptModel] = []
        self._running_scripts: dict[str, RunningScript] = {}
    
    @property
    def scripts(self) -> list[ScriptModel]:
        """Get list of all scripts."""
        return self._scripts
    
    def get_script(self, script_id: str) -> Optional[ScriptModel]:
        """Get a script by ID."""
        for script in self._scripts:
            if script.id == script_id:
                return script
        return None
    
    def add_script(self, script: ScriptModel) -> None:
        """
        Add a new script.
        
        Args:
            script: ScriptModel to add
        """
        if script.id not in [s.id for s in self._scripts]:
            self._scripts.append(script)
            self.scriptAdded.emit(script)
            self.scriptsChanged.emit()
    
    def add_script_from_path(self, source_path: Path) -> ScriptModel:
        """
        Create and add a script from a file path.
        
        Args:
            source_path: Path to script file
            
        Returns:
            Created ScriptModel
            
        Raises:
            ValueError: If file doesn't exist or has unsupported type
        """
        if not source_path.exists():
            raise ValueError(f"File not found: {source_path}")
        
        if not source_path.is_file():
            raise ValueError(f"Not a file: {source_path}")
        
        # Determine script type from extension
        suffix = source_path.suffix.lower()
        if suffix == '.py':
            script_type = ScriptType.PYTHON
        elif suffix == '.sh':
            script_type = ScriptType.BASH
        elif suffix in ('.ps1', '.psm1'):
            script_type = ScriptType.POWERSHELL
        else:
            raise ValueError(
                f"Unsupported script type: {suffix}. "
                "Supported types: .py, .sh, .ps1"
            )
        
        # Create script model
        script = ScriptModel(
            name=source_path.stem.replace('_', ' ').replace('-', ' ').title(),
            source_path=source_path,
            script_type=script_type
        )
        
        self.add_script(script)
        return script
    
    def remove_script(self, script_id: str) -> None:
        """
        Remove a script by ID.
        
        Args:
            script_id: Script identifier
        """
        self._scripts = [s for s in self._scripts if s.id != script_id]
        self.scriptRemoved.emit(script_id)
        self.scriptsChanged.emit()
    
    def update_script(self, script: ScriptModel) -> None:
        """
        Update an existing script.
        
        Args:
            script: Updated ScriptModel
        """
        for i, s in enumerate(self._scripts):
            if s.id == script.id:
                self._scripts[i] = script
                self.scriptsChanged.emit()
                break
    
    async def start_script(self, script_id: str) -> bool:
        """
        Start a script by ID.
        
        Args:
            script_id: Script identifier
            
        Returns:
            True if started successfully
        """
        script = self.get_script(script_id)
        if not script:
            self.error = f"Script not found: {script_id}"
            return False
        
        try:
            self.loading = True
            running_script = await self._script_runner.start_script(script)
            self._running_scripts[script_id] = running_script
            self.scriptStatusChanged.emit(script_id, ScriptStatus.RUNNING)
            return True
        except ScriptExecutionError as e:
            self.error = str(e)
            return False
        finally:
            self.loading = False
    
    async def stop_script(self, script_id: str) -> bool:
        """
        Stop a running script.
        
        Args:
            script_id: Script identifier
            
        Returns:
            True if stopped successfully
        """
        success = await self._script_runner.stop_script(script_id)
        if success:
            self.scriptStatusChanged.emit(script_id, ScriptStatus.STOPPED)
            self._running_scripts.pop(script_id, None)
        return success
    
    def get_running_script(self, script_id: str) -> Optional[RunningScript]:
        """Get running script information."""
        return self._running_scripts.get(script_id)
    
    def get_all_running(self) -> list[RunningScript]:
        """Get all running scripts."""
        return self._script_runner.get_all_running()
    
    def is_running(self, script_id: str) -> bool:
        """Check if a script is currently running."""
        return script_id in self._running_scripts
    
    def filter_by_type(self, script_type: ScriptType) -> list[ScriptModel]:
        """Filter scripts by type."""
        return [s for s in self._scripts if s.script_type == script_type]
    
    def filter_by_status(self, running: bool) -> list[ScriptModel]:
        """Filter scripts by running status."""
        if running:
            return [s for s in self._scripts if s.id in self._running_scripts]
        else:
            return [s for s in self._scripts if s.id not in self._running_scripts]
    
    def search_scripts(self, query: str) -> list[ScriptModel]:
        """
        Search scripts by name.
        
        Args:
            query: Search query
            
        Returns:
            Matching scripts
        """
        query = query.lower()
        return [s for s in self._scripts if query in s.name.lower()]
    
    async def shutdown(self) -> None:
        """Stop all running scripts."""
        await self._script_runner.shutdown()
        self._running_scripts.clear()
