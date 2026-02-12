"""
ScriptRunner - Asynchronous script execution service.

Provides:
- Async script execution (Python, Bash, PowerShell)
- Real-time stdout/stderr streaming
- Process lifecycle management (start/stop)
- Thread-safe operations with asyncio.Lock
"""

import asyncio
import signal
import subprocess
import os
import sys
import shutil  # DEBUG: Import moved to top to fix NameError issue
from pathlib import Path
from typing import AsyncGenerator, Optional
from datetime import datetime
from loguru import logger

from ..models.script_model import ScriptModel, ScriptStatus, RunningScript


class ScriptExecutionError(Exception):
    """Raised when script execution fails."""
    pass


class ScriptRunner:
    """
    Asynchronous script runner with real-time output streaming.
    
    Supports:
    - Python scripts
    - Bash scripts (Unix)
    - PowerShell scripts (Windows)
    
    Attributes:
        _running_scripts: Dict of running script processes
        _process_locks: Dict of asyncio locks for thread safety
        _shutdown_event: Event for graceful shutdown
    """
    
    def __init__(self):
        """Initialize ScriptRunner."""
        self._running_scripts: dict[str, RunningScript] = {}
        self._process_locks: dict[str, asyncio.Lock] = {}
        self._shutdown_event = asyncio.Event()
    
    async def start_script(
        self,
        script: ScriptModel,
        arguments: str = "",
        working_dir: Optional[Path] = None
    ) -> RunningScript:
        """
        Start a script in a separate process.
        
        Args:
            script: Script model
            arguments: Additional command-line arguments
            working_dir: Working directory (defaults to script directory)
            
        Returns:
            RunningScript with process information
            
        Raises:
            ScriptExecutionError: If script already running or fails to start
        """
        script_id = script.id
        
        if script_id in self._running_scripts:
            raise ScriptExecutionError(
                f"Script '{script.name}' is already running"
            )
        
        # Create lock for this script
        if script_id not in self._process_locks:
            self._process_locks[script_id] = asyncio.Lock()
        
        async with self._process_locks[script_id]:
            # Build command
            cmd = self._build_command(script, arguments)
            
            # Prepare environment
            env = os.environ.copy()
            env.update(script.environment)
            
            # Working directory
            cwd = working_dir or script.source_path.parent
            
            try:
                # Start subprocess
                process = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    env=env,
                    cwd=str(cwd)
                )
                
                running_script = RunningScript(
                    script=script,
                    status=ScriptStatus.RUNNING,
                    pid=process.pid,
                    start_time=datetime.now()
                )
                
                self._running_scripts[script_id] = running_script
                
                # Start streaming output
                asyncio.create_task(
                    self._stream_output(script_id, process)
                )
                
                logger.info(
                    f"Started script: {script.name} (PID: {process.pid})"
                )
                return running_script
                
            except OSError as e:
                raise ScriptExecutionError(
                    f"Failed to start script: {e}"
                )
    
    def _build_command(
        self,
        script: ScriptModel,
        arguments: str
    ) -> list[str]:
        """
        Build command for script execution.
        
        Args:
            script: Script model
            arguments: Additional arguments
            
        Returns:
            Command as list of strings
        """
        cmd = []
        
        # Determine interpreter
        if script.is_python:
            cmd.extend([sys.executable, str(script.source_path)])
        elif script.is_bash:
            cmd.extend(["/bin/bash", str(script.source_path)])
        elif script.is_powershell:
            pwsh_path = self._get_powershell_path()
            cmd.extend([pwsh_path, "-File", str(script.source_path)])
        else:
            # Execute directly (shebang will be used)
            cmd.append(str(script.source_path))
        
        # Add arguments from script model
        if script.arguments:
            cmd.extend(script.arguments.split())
        
        # Add additional arguments
        if arguments:
            cmd.extend(arguments.split())
        
        return cmd
    
    def _get_powershell_path(self) -> str:
        """Get PowerShell executable path."""
        # Try PowerShell Core first
        pwsh = shutil.which("pwsh")
        if pwsh:
            return pwsh
        
        # Fallback to Windows PowerShell
        return "powershell.exe"
    
    async def _stream_output(
        self,
        script_id: str,
        process: asyncio.subprocess.Process
    ) -> None:
        """
        Stream stdout/stderr from subprocess in real-time.
        
        Args:
            script_id: Script identifier
            process: Subprocess handle
        """
        running_script = self._running_scripts.get(script_id)
        if not running_script:
            logger.warning("[DEBUG] _stream_output: No running script found for {ScriptId}", script_id)
            return
        
        # DEBUG: Check if stdout/stderr are properly initialized
        if process.stdout is None:
            logger.error("[DEBUG] process.stdout is None for script {ScriptId}", script_id)
            return
        if process.stderr is None:
            logger.error("[DEBUG] process.stderr is None for script {ScriptId}", script_id)
            return
            
        stdout_lines = []
        stderr_lines = []
        
        logger.info("[DEBUG] Starting output stream for script {ScriptId}", script_id)
        
        try:
            while True:
                # Read stdout
                stdout_line = await process.stdout.readline()
                if stdout_line:
                    decoded = stdout_line.decode(
                        'utf-8',
                        errors='replace'
                    ).rstrip()
                    stdout_lines.append(decoded)
                    logger.info(
                        f"[{running_script.script.name}] STDOUT: {decoded}"
                    )
                
                # Read stderr
                stderr_line = await process.stderr.readline()
                if stderr_line:
                    decoded = stderr_line.decode(
                        'utf-8',
                        errors='replace'
                    ).rstrip()
                    stderr_lines.append(decoded)
                    logger.warning(
                        f"[{running_script.script.name}] STDERR: {decoded}"
                    )
                
                # Check if process finished
                if process.returncode is not None:
                    break
                
                await asyncio.sleep(0.01)  # Avoid busy waiting
        
        except Exception as e:
            logger.error(
                f"Error streaming output for {script_id}: {e}"
            )
        
        finally:
            # Update final status
            await self._finalize_script(
                script_id,
                process.returncode,
                stdout_lines,
                stderr_lines
            )
    
    async def stop_script(
        self,
        script_id: str,
        timeout: float = 5.0
    ) -> bool:
        """
        Stop a running script.
        
        Args:
            script_id: Script identifier
            timeout: Grace period before force kill (seconds)
            
        Returns:
            True if script was stopped successfully
        """
        running_script = self._running_scripts.get(script_id)
        if not running_script:
            return False
        
        pid = running_script.pid
        if not pid:
            return False
        
        async with self._process_locks.get(script_id, asyncio.Lock()):
            try:
                if sys.platform != 'win32':
                    # Unix: SIGTERM then SIGKILL
                    try:
                        os.kill(pid, signal.SIGTERM)
                        await asyncio.sleep(timeout)
                        
                        # Check if process finished
                        try:
                            os.kill(pid, 0)  # Check existence
                            os.kill(pid, signal.SIGKILL)  # Force kill
                        except ProcessLookupError:
                            pass  # Process already terminated
                    
                    except ProcessLookupError:
                        pass  # Process already terminated
                else:
                    # Windows: terminate
                    import psutil
                    try:
                        proc = psutil.Process(pid)
                        proc.terminate()
                        proc.wait(timeout=timeout)
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        pass
            
            except Exception as e:
                logger.error(
                    f"Error stopping script {script_id}: {e}"
                )
                return False
            
            return True
    
    async def _finalize_script(
        self,
        script_id: str,
        return_code: Optional[int],
        stdout_lines: list[str],
        stderr_lines: list[str]
    ) -> None:
        """
        Finalize script status after completion.
        
        Args:
            script_id: Script identifier
            return_code: Process exit code
            stdout_lines: Captured stdout lines
            stderr_lines: Captured stderr lines
        """
        running_script = self._running_scripts.get(script_id)
        if not running_script:
            return
        
        async with self._process_locks.get(script_id, asyncio.Lock()):
            running_script.status = (
                ScriptStatus.STOPPED
                if return_code == 0
                else ScriptStatus.ERROR
            )
            running_script.exit_code = return_code
            running_script.stdout_buffer = running_script.stdout_buffer[-1000:]
            running_script.stderr_buffer = running_script.stderr_buffer[-1000:]
            
            logger.info(
                f"Script '{running_script.script.name}' finished "
                f"with code {return_code}"
            )
    
    def get_running_script(self, script_id: str) -> Optional[RunningScript]:
        """
        Get information about a running script.
        
        Args:
            script_id: Script identifier
            
        Returns:
            RunningScript or None
        """
        return self._running_scripts.get(script_id)
    
    def get_all_running(self) -> list[RunningScript]:
        """
        Get all running scripts.
        
        Returns:
            List of RunningScript objects
        """
        return list(self._running_scripts.values())
    
    async def shutdown(self) -> None:
        """
        Stop all running scripts on application exit.
        """
        self._shutdown_event.set()
        
        for script_id in list(self._running_scripts.keys()):
            await self.stop_script(script_id, timeout=2.0)
        
        self._running_scripts.clear()
