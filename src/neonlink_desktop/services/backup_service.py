"""
BackupService - Backup and restore functionality for NeonLink Desktop.

Features:
- Export/import configuration to/from encrypted ZIP archive
- Automatic scheduled backups
- Backup rotation (keep last N backups)
- Backup metadata tracking
"""

import os
import json
import shutil
import zipfile
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from enum import Enum
import asyncio

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


class BackupError(Exception):
    """Raised when backup operation fails."""
    pass


class BackupSchedule(str, Enum):
    """Backup schedule options."""
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    MANUAL = "manual"


class BackupMetadata:
    """Metadata for a backup."""
    
    def __init__(
        self,
        version: str,
        created_at: datetime,
        app_version: str,
        config_count: int = 0,
        connection_count: int = 0,
        script_count: int = 0,
        encrypted: bool = True,
    ):
        self.version = version
        self.created_at = created_at
        self.app_version = app_version
        self.config_count = config_count
        self.connection_count = connection_count
        self.script_count = script_count
        self.encrypted = encrypted
    
    def to_dict(self) -> dict:
        """Convert to dictionary."""
        return {
            "version": self.version,
            "created_at": self.created_at.isoformat(),
            "app_version": self.app_version,
            "config_count": self.config_count,
            "connection_count": self.connection_count,
            "script_count": self.script_count,
            "encrypted": self.encrypted,
        }
    
    @classmethod
    def from_dict(cls, data: dict) -> "BackupMetadata":
        """Create from dictionary."""
        return cls(
            version=data["version"],
            created_at=datetime.fromisoformat(data["created_at"]),
            app_version=data["app_version"],
            config_count=data.get("config_count", 0),
            connection_count=data.get("connection_count", 0),
            script_count=data.get("script_count", 0),
            encrypted=data.get("encrypted", True),
        )


class BackupService:
    """
    Service for backup and restore operations.
    
    Backup structure:
        neonlink_backup_YYYY-MM-DD_HH-MM-SS.zip
        ├── config.enc          # Encrypted configuration
        ├── connections.enc     # Encrypted connections
        ├── scripts/            # Scripts folder
        ├── metadata.json       # Backup metadata
        └── version.txt        # App version
    """
    
    # Default paths
    CONFIG_DIR = Path.home() / '.config' / 'neonlink'
    BACKUP_DIR = CONFIG_DIR / 'backups'
    CONFIG_FILE = CONFIG_DIR / 'config.enc'
    CONNECTIONS_FILE = CONFIG_DIR / 'connections.enc'
    SCRIPTS_DIR = CONFIG_DIR / 'scripts'
    
    # App version
    APP_VERSION = "1.0.0"
    
    def __init__(
        self,
        backup_dir: Optional[Path] = None,
        max_backups: int = 10,
    ):
        """
        Initialize BackupService.
        
        Args:
            backup_dir: Custom backup directory
            max_backups: Maximum number of backups to keep
        """
        self.backup_dir = backup_dir or self.BACKUP_DIR
        self.max_backups = max_backups
        self._encryption_key: Optional[bytes] = None
    
    def set_encryption_key(self, key: bytes):
        """Set encryption key for backups."""
        self._encryption_key = key
    
    def _ensure_backup_dir(self):
        """Ensure backup directory exists."""
        self.backup_dir.mkdir(parents=True, exist_ok=True)
    
    def _generate_backup_name(self) -> str:
        """Generate backup file name with timestamp."""
        return f"neonlink_backup_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.zip"
    
    def _encrypt_data(self, data: bytes) -> bytes:
        """Encrypt data using AES-GCM."""
        if not self._encryption_key:
            return data
        
        nonce = os.urandom(12)
        aesgcm = AESGCM(self._encryption_key)
        ciphertext = aesgcm.encrypt(nonce, data, None)
        
        return nonce + ciphertext
    
    def _decrypt_data(self, encrypted_data: bytes) -> bytes:
        """Decrypt data using AES-GCM."""
        if not self._encryption_key:
            return encrypted_data
        
        if len(encrypted_data) < 28:
            raise BackupError("Invalid encrypted data")
        
        nonce = encrypted_data[:12]
        ciphertext = encrypted_data[12:]
        
        aesgcm = AESGCM(self._encryption_key)
        return aesgcm.decrypt(nonce, ciphertext, None)
    
    async def create_backup(
        self,
        destination: Optional[Path] = None,
        include_scripts: bool = True,
        include_connections: bool = True,
    ) -> Path:
        """
        Create a new backup.
        
        Args:
            destination: Custom destination path
            include_scripts: Include scripts in backup
            include_connections: Include connections in backup
            
        Returns:
            Path to created backup file
        """
        self._ensure_backup_dir()
        
        # Determine backup path
        if destination:
            backup_path = destination
        else:
            backup_path = self.backup_dir / self._generate_backup_name()
        
        # Collect counts for metadata
        config_count = 1 if self.CONFIG_FILE.exists() else 0
        connection_count = 1 if self.CONNECTIONS_FILE.exists() else 0
        
        script_count = 0
        if include_scripts and self.SCRIPTS_DIR.exists():
            script_count = len(list(self.SCRIPTS_DIR.glob("*")))
        
        # Create metadata
        metadata = BackupMetadata(
            version="1.0",
            created_at=datetime.now(),
            app_version=self.APP_VERSION,
            config_count=config_count,
            connection_count=connection_count,
            script_count=script_count,
            encrypted=bool(self._encryption_key),
        )
        
        # Create ZIP archive
        with zipfile.ZipFile(backup_path, 'w', zipfile.ZIP_DEFLATED) as zf:
            # Add metadata
            zf.writestr(
                "metadata.json",
                json.dumps(metadata.to_dict(), indent=2)
            )
            
            # Add version
            zf.writestr("version.txt", self.APP_VERSION)
            
            # Add config
            if self.CONFIG_FILE.exists():
                config_data = self.CONFIG_FILE.read_bytes()
                encrypted_config = self._encrypt_data(config_data)
                zf.writestr("config.enc", encrypted_config)
            
            # Add connections
            if include_connections and self.CONNECTIONS_FILE.exists():
                connections_data = self.CONNECTIONS_FILE.read_bytes()
                encrypted_connections = self._encrypt_data(connections_data)
                zf.writestr("connections.enc", encrypted_connections)
            
            # Add scripts
            if include_scripts and self.SCRIPTS_DIR.exists():
                for script_file in self.SCRIPTS_DIR.rglob("*"):
                    if script_file.is_file():
                        arcname = f"scripts/{script_file.name}"
                        zf.write(script_file, arcname)
        
        # Run rotation
        await self._rotate_backups()
        
        return backup_path
    
    async def restore_backup(
        self,
        backup_path: Path,
        restore_scripts: bool = True,
        restore_connections: bool = True,
        password: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Restore from a backup.
        
        Args:
            backup_path: Path to backup file
            restore_scripts: Restore scripts
            restore_connections: Restore connections
            password: Optional password for encrypted backup
            
        Returns:
            Dictionary with restore results
        """
        if not backup_path.exists():
            raise BackupError(f"Backup file not found: {backup_path}")
        
        # If password provided, use it for decryption
        if password:
            from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
            from cryptography.hazmat.primitives import hashes
            
            salt = b"neonlink_backup"  # Fixed salt for backups
            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=salt,
                iterations=100000,
            )
            self._encryption_key = kdf.derive(password.encode())
        
        results = {
            "config_restored": False,
            "connections_restored": False,
            "scripts_restored": False,
            "metadata": None,
        }
        
        # Ensure directories exist
        self.CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        
        with zipfile.ZipFile(backup_path, 'r') as zf:
            # Read metadata
            if "metadata.json" in zf.namelist():
                metadata_data = zf.read("metadata.json")
                metadata = BackupMetadata.from_dict(json.loads(metadata_data))
                results["metadata"] = metadata.to_dict()
            
            # Restore config
            if "config.enc" in zf.namelist() and self.CONFIG_FILE.parent.exists():
                config_data = zf.read("config.enc")
                try:
                    decrypted = self._decrypt_data(config_data)
                    self.CONFIG_FILE.write_bytes(decrypted)
                    results["config_restored"] = True
                except Exception as e:
                    raise BackupError(f"Failed to decrypt config: {e}")
            
            # Restore connections
            if restore_connections and "connections.enc" in zf.namelist():
                connections_data = zf.read("connections.enc")
                try:
                    decrypted = self._decrypt_data(connections_data)
                    self.CONNECTIONS_FILE.write_bytes(decrypted)
                    results["connections_restored"] = True
                except Exception as e:
                    raise BackupError(f"Failed to decrypt connections: {e}")
            
            # Restore scripts
            if restore_scripts:
                script_files = [f for f in zf.namelist() if f.startswith("scripts/")]
                
                if script_files:
                    self.SCRIPTS_DIR.mkdir(parents=True, exist_ok=True)
                    
                    for arcname in script_files:
                        filename = Path(arcname).name
                        source = zf.open(arcname)
                        target = self.SCRIPTS_DIR / filename
                        
                        with open(target, 'wb') as f:
                            shutil.copyfileobj(source, f)
                        
                        results["scripts_restored"] = True
        
        return results
    
    async def list_backups(self) -> List[Dict[str, Any]]:
        """
        List all available backups.
        
        Returns:
            List of backup info dictionaries
        """
        self._ensure_backup_dir()
        
        backups = []
        
        for backup_file in sorted(self.backup_dir.glob("neonlink_backup_*.zip")):
            try:
                with zipfile.ZipFile(backup_file, 'r') as zf:
                    metadata = None
                    
                    if "metadata.json" in zf.namelist():
                        metadata_data = zf.read("metadata.json")
                        metadata = json.loads(metadata_data)
                    
                    backups.append({
                        "path": str(backup_file),
                        "name": backup_file.name,
                        "size": backup_file.stat().st_size,
                        "created": metadata.get("created_at") if metadata else None,
                        "app_version": metadata.get("app_version") if metadata else None,
                        "config_count": metadata.get("config_count", 0) if metadata else 0,
                        "connection_count": metadata.get("connection_count", 0) if metadata else 0,
                        "script_count": metadata.get("script_count", 0) if metadata else 0,
                    })
            except Exception:
                continue
        
        return sorted(backups, key=lambda x: x["created"] or "", reverse=True)
    
    async def get_backup_info(self, backup_path: Path) -> Optional[Dict[str, Any]]:
        """Get detailed info about a backup."""
        if not backup_path.exists():
            return None
        
        try:
            with zipfile.ZipFile(backup_path, 'r') as zf:
                metadata = None
                
                if "metadata.json" in zf.namelist():
                    metadata_data = zf.read("metadata.json")
                    metadata = json.loads(metadata_data)
                
                return {
                    "path": str(backup_path),
                    "name": backup_path.name,
                    "size": backup_path.stat().st_size,
                    "metadata": metadata,
                    "files": zf.namelist(),
                }
        except Exception:
            return None
    
    async def delete_backup(self, backup_path: Path) -> bool:
        """Delete a backup file."""
        try:
            if backup_path.exists():
                backup_path.unlink()
                return True
            return False
        except Exception:
            return False
    
    async def _rotate_backups(self):
        """Remove old backups exceeding max_backups limit."""
        backups = await self.list_backups()
        
        if len(backups) > self.max_backups:
            # Delete oldest backups
            for backup in backups[self.max_backups:]:
                backup_path = Path(backup["path"])
                if backup_path.exists():
                    backup_path.unlink()
    
    # Scheduled backup functionality
    
    async def create_scheduled_backup(
        self,
        schedule: BackupSchedule,
    ) -> Optional[Path]:
        """
        Create backup based on schedule.
        
        Args:
            schedule: Backup schedule
            
        Returns:
            Path to created backup or None
        """
        if schedule == BackupSchedule.MANUAL:
            return None
        
        # Check last backup time
        backups = await self.list_backups()
        
        if not backups:
            # No backups yet, create one
            return await self.create_backup()
        
        # Parse last backup time
        last_backup = backups[0]
        if not last_backup.get("created"):
            return await self.create_backup()
        
        last_time = datetime.fromisoformat(last_backup["created"])
        now = datetime.now()
        
        # Check if it's time for a new backup
        should_backup = False
        
        if schedule == BackupSchedule.DAILY:
            should_backup = (now - last_time) >= timedelta(days=1)
        elif schedule == BackupSchedule.WEEKLY:
            should_backup = (now - last_time) >= timedelta(weeks=1)
        elif schedule == BackupSchedule.MONTHLY:
            should_backup = (now - last_time) >= timedelta(days=30)
        
        if should_backup:
            return await self.create_backup()
        
        return None
    
    async def get_backup_stats(self) -> Dict[str, Any]:
        """Get backup statistics."""
        backups = await self.list_backups()
        
        total_size = sum(b["size"] for b in backups)
        
        return {
            "backup_count": len(backups),
            "total_size": total_size,
            "oldest_backup": backups[-1]["created"] if backups else None,
            "newest_backup": backups[0]["created"] if backups else None,
            "max_backups": self.max_backups,
        }
    
    async def cleanup_backups(self, keep_count: int) -> int:
        """
        Clean up old backups, keeping only the most recent ones.
        
        Args:
            keep_count: Number of backups to keep
            
        Returns:
            Number of deleted backups
        """
        backups = await self.list_backups()
        
        deleted = 0
        for backup in backups[keep_count:]:
            if await self.delete_backup(Path(backup["path"])):
                deleted += 1
        
        return deleted


# Singleton instance
_backup_service: Optional[BackupService] = None


def get_backup_service() -> BackupService:
    """Get singleton BackupService instance."""
    global _backup_service
    
    if _backup_service is None:
        _backup_service = BackupService()
    
    return _backup_service
