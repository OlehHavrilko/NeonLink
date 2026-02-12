"""
Unit tests for NeonLink Desktop models.
"""

import pytest
from pathlib import Path
from datetime import datetime

from neonlink_desktop.models.script_model import (
    ScriptModel,
    ScriptType,
    ScriptInstallMethod,
    ScriptStatus,
    RunningScript
)
from neonlink_desktop.models.connection_model import (
    ConnectionProfile,
    ConnectionStatus,
    ExtraParams
)
from neonlink_desktop.models.config_model import AppConfigModel
from neonlink_desktop.models.log_entry import LogEntry, LogLevel, LogBuffer


class TestScriptModel:
    """Tests for ScriptModel."""
    
    def test_create_python_script(self):
        """Test creating a Python script model."""
        script = ScriptModel(
            name="Test Script",
            source_path=Path("/path/to/script.py"),
            script_type=ScriptType.PYTHON
        )
        
        assert script.name == "Test Script"
        assert script.script_type == ScriptType.PYTHON
        assert script.enabled is True
        assert script.auto_start is False
    
    def test_script_properties(self):
        """Test script computed properties."""
        script = ScriptModel(
            name="Test Script",
            source_path=Path("/path/to/script.py"),
            script_type=ScriptType.PYTHON
        )
        
        assert script.is_python is True
        assert script.is_bash is False
        assert script.is_powershell is False


class TestConnectionModel:
    """Tests for ConnectionProfile."""
    
    def test_create_connection(self):
        """Test creating a connection profile."""
        conn = ConnectionProfile(
            name="Test Server",
            host="192.168.1.100",
            port=9876,
            username="admin"
        )
        
        assert conn.name == "Test Server"
        assert conn.host == "192.168.1.100"
        assert conn.port == 9876
        assert conn.username == "admin"
    
    def test_validate_ipv4(self):
        """Test IPv4 address validation."""
        conn = ConnectionProfile(
            name="Test",
            host="192.168.1.1",
            port=9876,
            username="user"
        )
        
        assert conn.host == "192.168.1.1"
    
    def test_connection_string(self):
        """Test connection string property."""
        conn = ConnectionProfile(
            name="Test",
            host="192.168.1.100",
            port=9876,
            username="admin"
        )
        
        assert conn.connection_string == "admin@192.168.1.100:9876"


class TestExtraParams:
    """Tests for ExtraParams."""
    
    def test_default_params(self):
        """Test default extra parameters."""
        params = ExtraParams()
        
        assert params.timeout == 30
        assert params.ssl is False
        assert params.keep_alive == 60
    
    def test_custom_params(self):
        """Test custom extra parameters."""
        params = ExtraParams(
            timeout=60,
            ssl=True,
            ssl_verify=True
        )
        
        assert params.timeout == 60
        assert params.ssl is True


class TestAppConfigModel:
    """Tests for AppConfigModel."""
    
    def test_default_config(self):
        """Test default configuration."""
        config = AppConfigModel()
        
        assert config.theme == "dark"
        assert config.language == "en"
        assert config.auto_start is False


class TestLogEntry:
    """Tests for LogEntry."""
    
    def test_create_log_entry(self):
        """Test creating a log entry."""
        entry = LogEntry(
            level=LogLevel.INFO,
            message="Test message",
            source="test.py"
        )
        
        assert entry.level == LogLevel.INFO
        assert entry.message == "Test message"
        assert entry.source == "test.py"
    
    def test_level_icon(self):
        """Test log level icons."""
        debug_entry = LogEntry(level=LogLevel.DEBUG, message="test")
        info_entry = LogEntry(level=LogLevel.INFO, message="test")
        error_entry = LogEntry(level=LogLevel.ERROR, message="test")
        
        assert "🔍" in debug_entry.level_icon
        assert "ℹ️" in info_entry.level_icon
        assert "❌" in error_entry.level_icon


class TestLogBuffer:
    """Tests for LogBuffer."""
    
    def test_buffer_creation(self):
        """Test creating a log buffer."""
        buffer = LogBuffer()
        
        assert len(buffer.entries) == 0
        assert buffer.max_size == 1000
    
    def test_add_entries(self):
        """Test adding entries to buffer."""
        buffer = LogBuffer()
        
        for i in range(5):
            buffer.add(LogEntry(message=f"Entry {i}"))
        
        assert len(buffer.entries) == 5
    
    def test_max_size(self):
        """Test buffer max size enforcement."""
        buffer = LogBuffer(max_size=3)
        
        for i in range(10):
            buffer.add(LogEntry(message=f"Entry {i}"))
        
        assert len(buffer.entries) == 3
    
    def test_filter_by_level(self):
        """Test filtering entries by level."""
        buffer = LogBuffer()
        
        buffer.add(LogEntry(level=LogLevel.INFO, message="info1"))
        buffer.add(LogEntry(level=LogLevel.ERROR, message="error1"))
        buffer.add(LogEntry(level=LogLevel.INFO, message="info2"))
        
        info_entries = buffer.filter_by_level(LogLevel.INFO)
        assert len(info_entries) == 2
