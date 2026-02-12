"""
Base ViewModel class for MVVM architecture.

Provides common functionality for all ViewModels.
"""

from abc import ABC
from typing import Any, Callable, Optional
from PyQt6.QtCore import QObject, pyqtSignal


class BaseViewModel(QObject):
    """
    Base class for all ViewModels in MVVM architecture.
    
    Provides:
    - Signal-based communication with Views
    - Loading state management
    - Error handling
    
    Signals:
        loadingChanged: Emitted when loading state changes
        errorOccurred: Emitted when an error occurs
        dataChanged: Emitted when underlying data changes
    """
    
    loadingChanged = pyqtSignal(bool)
    errorOccurred = pyqtSignal(str)
    dataChanged = pyqtSignal()
    
    def __init__(self):
        """Initialize BaseViewModel."""
        super().__init__()
        self._loading = False
        self._error: Optional[str] = None
    
    @property
    def loading(self) -> bool:
        """Get loading state."""
        return self._loading
    
    @loading.setter
    def loading(self, value: bool) -> None:
        """Set loading state and emit signal."""
        if self._loading != value:
            self._loading = value
            self.loadingChanged.emit(value)
    
    @property
    def error(self) -> Optional[str]:
        """Get last error message."""
        return self._error
    
    @error.setter
    def error(self, value: Optional[str]) -> None:
        """Set error message and emit signal."""
        self._error = value
        if value:
            self.errorOccurred.emit(value)
    
    def set_loading(self, loading: bool) -> None:
        """Set loading state."""
        self.loading = loading
    
    def set_error(self, error: str) -> None:
        """Set error message."""
        self.error = error
    
    def clear_error(self) -> None:
        """Clear error message."""
        self.error = None
    
    def notify_data_changed(self) -> None:
        """Notify views that data has changed."""
        self.dataChanged.emit()
