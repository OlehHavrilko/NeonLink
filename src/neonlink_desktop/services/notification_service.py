"""
NotificationService - Cross-platform system notifications for NeonLink Desktop.

Features:
- Windows 10 Toast Notifications
- macOS NSUserNotification (via plyer)
- Linux libnotify (via plyer)
- Notification types: script events, backup, updates
- Sound notifications (optional)
- Notification queue to prevent flooding
"""

import asyncio
from pathlib import Path
from datetime import datetime
from typing import Optional, List, Dict, Any
from enum import Enum
from dataclasses import dataclass
from queue import Queue
import threading

try:
    from plyer import notification as plyer_notification
    PLYER_AVAILABLE = True
except ImportError:
    PLYER_AVAILABLE = False


class NotificationType(str, Enum):
    """Types of notifications."""
    SCRIPT_STARTED = "script_started"
    SCRIPT_COMPLETED = "script_completed"
    SCRIPT_ERROR = "script_error"
    BACKUP_CREATED = "backup_created"
    UPDATE_AVAILABLE = "update_available"
    CONNECTION_STATUS = "connection_status"
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"


@dataclass
class Notification:
    """Notification data."""
    title: str
    message: str
    type: NotificationType
    icon: Optional[str] = None
    sound: bool = True
    timeout: int = 10  # seconds
    
    def __post_init__(self):
        if not self.icon:
            self.icon = self._get_default_icon()
    
    def _get_default_icon(self) -> str:
        """Get default icon based on type."""
        icons = {
            NotificationType.SCRIPT_STARTED: "start",
            NotificationType.SCRIPT_COMPLETED: "complete",
            NotificationType.SCRIPT_ERROR: "error",
            NotificationType.BACKUP_CREATED: "backup",
            NotificationType.UPDATE_AVAILABLE: "update",
            NotificationType.CONNECTION_STATUS: "connect",
            NotificationType.INFO: "info",
            NotificationType.WARNING: "warning",
            NotificationType.ERROR: "error",
        }
        return icons.get(self.type, "info")


class NotificationService:
    """
    Cross-platform notification service.
    
    Uses plyer for platform-independent notifications:
    - Windows: Toast notifications
    - macOS: NSUserNotification
    - Linux: libnotify
    """
    
    # Platform detection
    import platform
    SYSTEM = platform.system()
    IS_WINDOWS = SYSTEM == "Windows"
    IS_MACOS = SYSTEM == "Darwin"
    IS_LINUX = SYSTEM == "Linux"
    
    def __init__(
        self,
        enabled: bool = True,
        sound_enabled: bool = True,
        max_queue_size: int = 10,
    ):
        """
        Initialize NotificationService.
        
        Args:
            enabled: Enable/disable notifications
            sound_enabled: Enable/disable sound
            max_queue_size: Maximum notification queue size
        """
        self.enabled = enabled
        self.sound_enabled = sound_enabled
        self.max_queue_size = max_queue_size
        
        self._notification_queue: Queue = Queue()
        self._worker_thread: Optional[threading.Thread] = None
        self._running = False
        self._notification_types: Dict[NotificationType, bool] = {
            NotificationType.SCRIPT_STARTED: True,
            NotificationType.SCRIPT_COMPLETED: True,
            NotificationType.SCRIPT_ERROR: True,
            NotificationType.BACKUP_CREATED: True,
            NotificationType.UPDATE_AVAILABLE: True,
            NotificationType.CONNECTION_STATUS: True,
            NotificationType.INFO: True,
            NotificationType.WARNING: True,
            NotificationType.ERROR: True,
        }
        
        self._app_name = "NeonLink"
    
    def start(self):
        """Start notification worker thread."""
        if self._running:
            return
        
        self._running = True
        self._worker_thread = threading.Thread(target=self._worker, daemon=True)
        self._worker_thread.start()
    
    def stop(self):
        """Stop notification worker thread."""
        self._running = False
        
        if self._worker_thread:
            self._worker_thread.join(timeout=2)
    
    def _worker(self):
        """Worker thread for processing notification queue."""
        while self._running:
            try:
                notification = self._notification_queue.get(timeout=0.5)
                self._send_notification(notification)
            except Exception:
                continue
    
    def _send_notification(self, notification: Notification):
        """Send notification to system."""
        if not self.enabled:
            return
        
        # Check if notification type is enabled
        if not self._notification_types.get(notification.type, True):
            return
        
        if not PLYER_AVAILABLE:
            # Fallback to print if plyer not available
            print(f"[NOTIFICATION] {notification.title}: {notification.message}")
            return
        
        try:
            # Determine icon based on type and platform
            app_icon = self._get_icon_path()
            
            plyer_notification.notify(
                title=notification.title,
                message=notification.message,
                app_name=self._app_name,
                app_icon=app_icon,
                timeout=notification.timeout,
                sound=self.sound_enabled and notification.sound,
            )
        except Exception as e:
            # Log error but don't crash
            print(f"Notification error: {e}")
    
    def _get_icon_path(self) -> Optional[str]:
        """Get platform-specific icon path."""
        # Return None to use system default
        return None
    
    def _enqueue_notification(self, notification: Notification):
        """Add notification to queue."""
        # Drop old notifications if queue is full
        if self._notification_queue.qsize() >= self.max_queue_size:
            try:
                self._notification_queue.get_nowait()
            except Exception:
                pass
        
        self._notification_queue.put(notification)
    
    # Public API
    
    def notify(
        self,
        title: str,
        message: str,
        type: NotificationType = NotificationType.INFO,
        sound: bool = True,
    ):
        """
        Send a notification.
        
        Args:
            title: Notification title
            message: Notification message
            type: Notification type
            sound: Play sound
        """
        notification = Notification(
            title=title,
            message=message,
            type=type,
            sound=sound,
        )
        
        self._enqueue_notification(notification)
    
    def is_type_enabled(self, notification_type: NotificationType) -> bool:
        """Check if notification type is enabled."""
        return self._notification_types.get(notification_type, True)
    
    def set_type_enabled(self, notification_type: NotificationType, enabled: bool):
        """Enable/disable notification type."""
        self._notification_types[notification_type] = enabled
    
    def enable_all(self):
        """Enable all notification types."""
        for ntype in NotificationType:
            self._notification_types[ntype] = True
    
    def disable_all(self):
        """Disable all notification types."""
        for ntype in NotificationType:
            self._notification_types[ntype] = False
    
    # Convenience methods for common notifications
    
    def notify_script_started(self, script_name: str):
        """Notify script started."""
        self.notify(
            title="Script Started",
            message=f"Script '{script_name}' has started running",
            type=NotificationType.SCRIPT_STARTED,
        )
    
    def notify_script_completed(
        self,
        script_name: str,
        exit_code: int,
        duration: float,
    ):
        """Notify script completed."""
        if exit_code == 0:
            self.notify(
                title="Script Completed",
                message=f"Script '{script_name}' completed successfully ({duration:.1f}s)",
                type=NotificationType.SCRIPT_COMPLETED,
            )
        else:
            self.notify(
                title="Script Failed",
                message=f"Script '{script_name}' failed with exit code {exit_code}",
                type=NotificationType.SCRIPT_ERROR,
                sound=True,
            )
    
    def notify_script_error(self, script_name: str, error: str):
        """Notify script error."""
        self.notify(
            title="Script Error",
            message=f"Error in script '{script_name}': {error}",
            type=NotificationType.SCRIPT_ERROR,
            sound=True,
        )
    
    def notify_backup_created(self, backup_path: Path):
        """Notify backup created."""
        self.notify(
            title="Backup Created",
            message=f"Backup created: {backup_path.name}",
            type=NotificationType.BACKUP_CREATED,
        )
    
    def notify_update_available(self, script_name: str, version: str):
        """Notify update available."""
        self.notify(
            title="Update Available",
            message=f"New version {version} available for '{script_name}'",
            type=NotificationType.UPDATE_AVAILABLE,
        )
    
    def notify_connection_status(
        self,
        connection_name: str,
        status: str,
        message: str = "",
    ):
        """Notify connection status change."""
        if status == "connected":
            title = "Connected"
            msg = f"Connected to {connection_name}"
        elif status == "disconnected":
            title = "Disconnected"
            msg = f"Disconnected from {connection_name}"
        elif status == "error":
            title = "Connection Error"
            msg = f"Connection error: {connection_name}"
        else:
            title = "Connection"
            msg = f"{connection_name}: {status}"
        
        if message:
            msg += f" - {message}"
        
        self.notify(
            title=title,
            message=msg,
            type=NotificationType.CONNECTION_STATUS,
            sound=(status == "error"),
        )
    
    def notify_error(self, title: str, message: str):
        """Notify error."""
        self.notify(
            title=title,
            message=message,
            type=NotificationType.ERROR,
            sound=True,
        )
    
    def notify_warning(self, title: str, message: str):
        """Notify warning."""
        self.notify(
            title=title,
            message=message,
            type=NotificationType.WARNING,
        )
    
    def notify_info(self, title: str, message: str):
        """Notify info."""
        self.notify(
            title=title,
            message=message,
            type=NotificationType.INFO,
        )


# Singleton instance
_notification_service: Optional[NotificationService] = None


def get_notification_service() -> NotificationService:
    """Get singleton NotificationService instance."""
    global _notification_service
    
    if _notification_service is None:
        _notification_service = NotificationService()
    
    return _notification_service


def initialize_notification_service(
    enabled: bool = True,
    sound_enabled: bool = True,
) -> NotificationService:
    """Initialize and get NotificationService."""
    global _notification_service
    
    _notification_service = NotificationService(
        enabled=enabled,
        sound_enabled=sound_enabled,
    )
    _notification_service.start()
    
    return _notification_service


def shutdown_notification_service():
    """Shutdown NotificationService."""
    global _notification_service
    
    if _notification_service:
        _notification_service.stop()
        _notification_service = None
