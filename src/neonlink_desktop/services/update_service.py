"""
UpdateService - Automatic script update service for NeonLink Desktop.

Features:
- Check for updates from remote sources
- Download and apply updates
- Version comparison
- Update source management
- Automatic update checks
"""

import asyncio
import hashlib
import json
import shutil
from pathlib import Path
from datetime import datetime
from typing import Optional, List, Dict, Any, Callable
from enum import Enum
from dataclasses import dataclass
from packaging import version

try:
    import aiohttp
    AIOHTTP_AVAILABLE = True
except ImportError:
    AIOHTTP_AVAILABLE = False


class UpdateError(Exception):
    """Raised when update operation fails."""
    pass


class UpdateStatus(str, Enum):
    """Update status."""
    CHECKING = "checking"
    AVAILABLE = "available"
    DOWNLOADING = "downloading"
    READY = "ready"
    APPLYING = "applying"
    COMPLETED = "completed"
    FAILED = "failed"
    UP_TO_DATE = "up_to_date"


@dataclass
class UpdateSource:
    """Update source configuration."""
    name: str
    url: str  # URL to metadata JSON
    enabled: bool = True
    check_interval: int = 3600  # seconds
    last_check: Optional[datetime] = None


@dataclass
class ScriptUpdate:
    """Script update information."""
    script_id: str
    name: str
    current_version: str
    new_version: str
    download_url: str
    checksum: str  # sha256:...
    changelog: str
    size: int = 0
    
    @property
    def version_tuple(self):
        """Get version as tuple for comparison."""
        return version.parse(self.new_version)


@dataclass
class UpdateResult:
    """Result of update operation."""
    success: bool
    message: str
    updated_scripts: List[str] = None
    failed_scripts: List[str] = None
    
    def __post_init__(self):
        if self.updated_scripts is None:
            self.updated_scripts = []
        if self.failed_scripts is None:
            self.failed_scripts = []


class UpdateService:
    """
    Service for checking and applying script updates.
    
    Update source format (JSON):
    {
        "scripts": [
            {
                "id": "script-id",
                "name": "Script Name",
                "version": "1.2.0",
                "download_url": "https://example.com/scripts/script-v1.2.0.zip",
                "checksum": "sha256:abc123...",
                "changelog": "Fixed bug...",
                "size": 12345
            }
        ]
    }
    """
    
    def __init__(
        self,
        scripts_dir: Optional[Path] = None,
        timeout: int = 30,
    ):
        """
        Initialize UpdateService.
        
        Args:
            scripts_dir: Scripts directory
            timeout: HTTP request timeout
        """
        self.scripts_dir = scripts_dir or (Path.home() / '.config' / 'neonlink' / 'scripts')
        self.timeout = timeout
        
        self._sources: Dict[str, UpdateSource] = {}
        self._available_updates: Dict[str, ScriptUpdate] = {}
        self._check_task: Optional[asyncio.Task] = None
        self._running = False
    
    def add_source(self, source: UpdateSource):
        """Add an update source."""
        self._sources[source.name] = source
    
    def remove_source(self, name: str):
        """Remove an update source."""
        if name in self._sources:
            del self._sources[name]
    
    def get_sources(self) -> List[UpdateSource]:
        """Get all update sources."""
        return list(self._sources.values())
    
    def set_source_enabled(self, name: str, enabled: bool):
        """Enable/disable an update source."""
        if name in self._sources:
            self._sources[name].enabled = enabled
    
    async def check_for_updates(
        self,
        source_name: Optional[str] = None,
    ) -> Dict[str, List[ScriptUpdate]]:
        """
        Check for available updates.
        
        Args:
            source_name: Specific source to check (None = all)
            
        Returns:
            Dictionary mapping source name to list of updates
        """
        if not AIOHTTP_AVAILABLE:
            raise UpdateError("aiohttp not available")
        
        results = {}
        
        sources_to_check = (
            [self._sources[source_name]] if source_name and source_name in self._sources
            else [s for s in self._sources.values() if s.enabled]
        )
        
        for source in sources_to_check:
            try:
                updates = await self._check_source(source)
                results[source.name] = updates
                
                # Update last check time
                source.last_check = datetime.now()
            except Exception as e:
                results[source.name] = []
        
        self._available_updates = {
            update.script_id: update
            for updates in results.values()
            for update in updates
        }
        
        return results
    
    async def _check_source(self, source: UpdateSource) -> List[ScriptUpdate]:
        """Check a single source for updates."""
        async with aiohttp.ClientSession() as session:
            async with session.get(source.url, timeout=self.timeout) as response:
                if response.status != 200:
                    raise UpdateError(f"Failed to fetch update metadata: {response.status}")
                
                data = await response.json()
        
        updates = []
        
        for script_data in data.get("scripts", []):
            update = ScriptUpdate(
                script_id=script_data["id"],
                name=script_data.get("name", script_data["id"]),
                current_version="0.0.0",  # Will be updated from local
                new_version=script_data["version"],
                download_url=script_data["download_url"],
                checksum=script_data.get("checksum", ""),
                changelog=script_data.get("changelog", ""),
                size=script_data.get("size", 0),
            )
            
            # Check if we have a newer local version
            local_version = self._get_local_version(update.script_id)
            if local_version:
                update.current_version = local_version
            
            # Only include if new version is newer
            try:
                if version.parse(update.new_version) > version.parse(update.current_version):
                    updates.append(update)
            except Exception:
                # If version parsing fails, include the update
                updates.append(update)
        
        return updates
    
    def _get_local_version(self, script_id: str) -> Optional[str]:
        """Get local version of a script."""
        # Check for version file
        version_file = self.scripts_dir / script_id / "version.txt"
        
        if version_file.exists():
            try:
                return version_file.read_text().strip()
            except Exception:
                pass
        
        return None
    
    def get_available_updates(self) -> List[ScriptUpdate]:
        """Get all available updates."""
        return list(self._available_updates.values())
    
    def has_updates(self) -> bool:
        """Check if any updates are available."""
        return len(self._available_updates) > 0
    
    async def download_update(
        self,
        update: ScriptUpdate,
        destination: Optional[Path] = None,
        progress_callback: Optional[Callable[[int, int], None]] = None,
    ) -> Path:
        """
        Download an update.
        
        Args:
            update: Update to download
            destination: Custom destination path
            progress_callback: Progress callback (bytes_downloaded, total_bytes)
            
        Returns:
            Path to downloaded file
        """
        if not AIOHTTP_AVAILABLE:
            raise UpdateError("aiohttp not available")
        
        destination = destination or (self.scripts_dir / "temp" / f"{update.script_id}.zip")
        destination.parent.mkdir(parents=True, exist_ok=True)
        
        async with aiohttp.ClientSession() as session:
            async with session.get(update.download_url, timeout=self.timeout) as response:
                if response.status != 200:
                    raise UpdateError(f"Failed to download: {response.status}")
                
                total_size = int(response.headers.get("Content-Length", 0))
                downloaded = 0
                
                with open(destination, 'wb') as f:
                    async for chunk in response.content.iter_chunked(8192):
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        if progress_callback and total_size:
                            progress_callback(downloaded, total_size)
        
        # Verify checksum
        if update.checksum.startswith("sha256:"):
            expected_hash = update.checksum[7:]
            actual_hash = self._calculate_sha256(destination)
            
            if actual_hash != expected_hash:
                destination.unlink()
                raise UpdateError("Checksum verification failed")
        
        return destination
    
    def _calculate_sha256(self, filepath: Path) -> str:
        """Calculate SHA256 hash of file."""
        sha256 = hashlib.sha256()
        
        with open(filepath, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                sha256.update(chunk)
        
        return sha256.hexdigest()
    
    async def apply_update(
        self,
        update: ScriptUpdate,
        backup: bool = True,
    ) -> UpdateResult:
        """
        Apply an update.
        
        Args:
            update: Update to apply
            backup: Create backup before applying
            
        Returns:
            UpdateResult
        """
        try:
            # Download update
            archive_path = await self.download_update(update)
            
            # Create backup if requested
            script_dir = self.scripts_dir / update.script_id
            
            if backup and script_dir.exists():
                backup_dir = self.scripts_dir / "backups" / f"{update.script_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
                backup_dir.parent.mkdir(parents=True, exist_ok=True)
                shutil.copytree(script_dir, backup_dir)
            
            # Extract update
            import zipfile
            
            with zipfile.ZipFile(archive_path, 'r') as zf:
                zf.extractall(script_dir.parent)
            
            # Update version file
            version_file = script_dir / "version.txt"
            version_file.write_text(update.new_version)
            
            # Clean up
            archive_path.unlink()
            
            # Remove from available updates
            if update.script_id in self._available_updates:
                del self._available_updates[update.script_id]
            
            return UpdateResult(
                success=True,
                message=f"Updated {update.name} to {update.new_version}",
                updated_scripts=[update.script_id],
            )
            
        except Exception as e:
            return UpdateResult(
                success=False,
                message=f"Failed to update {update.name}: {str(e)}",
                failed_scripts=[update.script_id],
            )
    
    async def apply_all_updates(
        self,
        backup: bool = True,
    ) -> UpdateResult:
        """Apply all available updates."""
        updated = []
        failed = []
        
        for update in list(self._available_updates.values()):
            result = await self.apply_update(update, backup=backup)
            
            if result.success:
                updated.extend(result.updated_scripts)
            else:
                failed.extend(result.failed_scripts)
        
        if failed:
            message = f"Updated {len(updated)} scripts, {len(failed)} failed"
        else:
            message = f"Successfully updated {len(updated)} scripts"
        
        return UpdateResult(
            success=len(failed) == 0,
            message=message,
            updated_scripts=updated,
            failed_scripts=failed,
        )
    
    async def start_auto_check(self, interval: int = 3600):
        """Start automatic update checking."""
        if self._running:
            return
        
        self._running = True
        
        async def check_loop():
            while self._running:
                try:
                    await self.check_for_updates()
                except Exception:
                    pass
                
                await asyncio.sleep(interval)
        
        self._check_task = asyncio.create_task(check_loop())
    
    def stop_auto_check(self):
        """Stop automatic update checking."""
        self._running = False
        
        if self._check_task:
            self._check_task.cancel()
            self._check_task = None


# Singleton instance
_update_service: Optional[UpdateService] = None


def get_update_service() -> UpdateService:
    """Get singleton UpdateService instance."""
    global _update_service
    
    if _update_service is None:
        _update_service = UpdateService()
    
    return _update_service
