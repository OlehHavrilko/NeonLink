"""
Services package for NeonLink Desktop.

Contains business logic services for encryption, credentials,
script execution, and more.
"""

from .config_manager import ConfigManager, EncryptionError
from .credential_manager import CredentialManager, CredentialStorageError
from .script_runner import ScriptRunner, ScriptExecutionError
from .script_installer import ScriptInstaller, InstallationError
from .validation_service import ValidationService, ValidationError
from .database_service import DatabaseService, get_database_service, close_database_service
from .log_service import LogService, get_log_service, initialize_log_service, shutdown_log_service
from .backup_service import BackupService, BackupError, BackupSchedule, get_backup_service
from .notification_service import (
    NotificationService, NotificationType, Notification,
    get_notification_service, initialize_notification_service, shutdown_notification_service
)
from .update_service import (
    UpdateService, UpdateError, UpdateStatus, UpdateSource, ScriptUpdate, UpdateResult,
    get_update_service
)
from .error_handler import (
    ErrorHandler, ErrorSeverity, ErrorInfo,
    get_error_handler, initialize_error_handler, shutdown_error_handler
)

__all__ = [
    # Config Manager
    "ConfigManager",
    "EncryptionError",
    
    # Credential Manager
    "CredentialManager",
    "CredentialStorageError",
    
    # Script Runner
    "ScriptRunner",
    "ScriptExecutionError",
    
    # Script Installer
    "ScriptInstaller",
    "InstallationError",
    
    # Validation Service
    "ValidationService",
    "ValidationError",
    
    # Database Service
    "DatabaseService",
    "get_database_service",
    "close_database_service",
    
    # Log Service
    "LogService",
    "get_log_service",
    "initialize_log_service",
    "shutdown_log_service",
    
    # Backup Service
    "BackupService",
    "BackupError",
    "BackupSchedule",
    "get_backup_service",
    
    # Notification Service
    "NotificationService",
    "NotificationType",
    "Notification",
    "get_notification_service",
    "initialize_notification_service",
    "shutdown_notification_service",
    
    # Update Service
    "UpdateService",
    "UpdateError",
    "UpdateStatus",
    "UpdateSource",
    "ScriptUpdate",
    "UpdateResult",
    "get_update_service",
    
    # Error Handler
    "ErrorHandler",
    "ErrorSeverity",
    "ErrorInfo",
    "get_error_handler",
    "initialize_error_handler",
    "shutdown_error_handler",
]
