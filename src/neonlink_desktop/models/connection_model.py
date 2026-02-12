"""
Connection models for NeonLink Desktop.

Defines data structures for server connections.
"""

import re
from enum import Enum
from datetime import datetime
from pydantic import BaseModel, Field, field_validator
from typing import Optional


class ConnectionStatus(str, Enum):
    """Connection status."""
    UNKNOWN = "unknown"
    CONNECTING = "connecting"
    CONNECTED = "connected"
    DISCONNECTED = "disconnected"
    ERROR = "error"


class ExtraParams(BaseModel):
    """
    Additional connection parameters.
    
    Attributes:
        timeout: Connection timeout in seconds
        ssl: Use SSL/TLS
        ssl_verify: Verify SSL certificate
        cert_path: Path to client certificate
        proxy: Proxy server address
        keep_alive: Keep-alive interval in seconds
    """
    
    timeout: int = Field(default=30, ge=1, le=300)
    ssl: bool = False
    ssl_verify: bool = True
    cert_path: Optional[str] = None
    proxy: Optional[str] = None
    keep_alive: int = Field(default=60, ge=10, le=3600)
    
    def to_json(self) -> str:
        """Serialize to JSON string."""
        return self.model_dump_json()
    
    @classmethod
    def from_json(cls, json_str: str) -> 'ExtraParams':
        """Deserialize from JSON string."""
        return cls.model_validate_json(json_str)


class ConnectionProfile(BaseModel):
    """
    Model for server connection profile.
    
    Attributes:
        id: Unique identifier (timestamp-based)
        name: Display name for the profile
        host: IP address or hostname
        port: Port number (1-65535)
        username: Username for authentication
        password_hash: Deprecated, use keyring instead
        extra_params: Additional connection parameters
        last_connected: Last successful connection timestamp
        favorite: Mark as favorite (shown first)
        color: Color for visual identification (hex)
    """
    
    id: str = Field(default_factory=lambda: str(datetime.now().timestamp()))
    name: str = Field(..., min_length=1, max_length=100)
    host: str = Field(..., min_length=1, max_length=255)
    port: int = Field(default=9876, ge=1, le=65535)
    username: str = Field(..., min_length=1, max_length=100)
    password_hash: Optional[str] = None  # Deprecated, use keyring
    extra_params: ExtraParams = Field(default_factory=ExtraParams)
    last_connected: Optional[datetime] = None
    favorite: bool = False
    color: str = "#6C5CE7"  # Neon purple default
    
    @field_validator('host')
    @classmethod
    def validate_host(cls, v: str) -> str:
        """Validate host format (IP or hostname)."""
        # Check for valid hostname pattern
        hostname_pattern = r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
        if re.match(hostname_pattern, v):
            return v
        
        # Check for valid IPv4
        try:
            import ipaddress
            ipaddress.IPv4Address(v)
            return v
        except ipaddress.AddressValueError:
            pass
        
        # Check for valid IPv6
        try:
            ipaddress.IPv6Address(v)
            return v
        except ipaddress.AddressValueError:
            pass
        
        raise ValueError(f"Invalid host format: {v}")
    
    @property
    def connection_string(self) -> str:
        """Get connection string for display."""
        return f"{self.username}@{self.host}:{self.port}"
    
    @property
    def is_localhost(self) -> bool:
        """Check if connection is to localhost."""
        return self.host in ('localhost', '127.0.0.1', '::1')
    
    @property
    def display_color(self) -> str:
        """Get display color (ensure valid hex)."""
        if self.color.startswith('#') and len(self.color) == 7:
            return self.color
        return "#6C5CE7"  # Default neon purple
