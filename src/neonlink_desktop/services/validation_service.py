"""
ValidationService - Input validation utilities.

Provides validation for:
- IP addresses and hostnames
- Port numbers
- URLs and URIs
- JSON strings
- File paths
"""

import re
from typing import Optional, Tuple


class ValidationError(Exception):
    """Raised when validation fails."""
    pass


class ValidationService:
    """
    Service for validating user input and configuration values.
    """
    
    # Regex patterns
    IPV4_PATTERN = re.compile(
        r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}'
        r'(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    )
    
    IPV6_PATTERN = re.compile(
        r'^(?:(?:[0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|'
        r'(?:[0-9a-fA-F]{1,4}:){1,7}:|'
        r'(?:[0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|'
        r'(?:[0-9a-fA-F]{1,4}:){1,5}(?::[0-9a-fA-F]{1,4}){1,2}|'
        r'(?:[0-9a-fA-F]{1,4}:){1,4}(?::[0-9a-fA-F]{1,4}){1,3}|'
        r'(?:[0-9a-fA-F]{1,4}:){1,3}(?::[0-9a-fA-F]{1,4}){1,4}|'
        r'(?:[0-9a-fA-F]{1,4}:){1,2}(?::[0-9a-fA-F]{1,4}){1,5}|'
        r'[0-9a-fA-F]{1,4}:(?:(?::[0-9a-fA-F]{1,4}){1,6})|'
        r':(?:(?::[0-9a-fA-F]{1,4}){1,7}|:)|'
        r'fe80:(?::[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]+|'
        r'(?:(?:[0-9a-fA-F]{1,4}:){1,4}|):(?:(?:(?:25[0-5]|2[0-4][0-9]|'
        r'[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))$'
    )
    
    HOSTNAME_PATTERN = re.compile(
        r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
        r'(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    )
    
    EMAIL_PATTERN = re.compile(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    )
    
    def __init__(self):
        """Initialize ValidationService."""
        pass
    
    def validate_host(self, host: str) -> Tuple[bool, Optional[str]]:
        """
        Validate a host (IP address or hostname).
        
        Args:
            host: Hostname or IP address
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not host or len(host) > 255:
            return False, "Host must be 1-255 characters"
        
        # Check IPv4
        if self.IPV4_PATTERN.match(host):
            return True, None
        
        # Check IPv6
        if self.IPV6_PATTERN.match(host):
            return True, None
        
        # Check hostname
        if self.HOSTNAME_PATTERN.match(host):
            return True, None
        
        return False, "Invalid host format"
    
    def validate_port(self, port: int) -> Tuple[bool, Optional[str]]:
        """
        Validate a port number.
        
        Args:
            port: Port number
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not isinstance(port, int):
            return False, "Port must be an integer"
        
        if port < 1 or port > 65535:
            return False, "Port must be between 1 and 65535"
        
        return True, None
    
    def validate_ip(self, ip: str) -> Tuple[bool, Optional[str]]:
        """
        Validate an IP address (IPv4 or IPv6).
        
        Args:
            ip: IP address string
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if self.IPV4_PATTERN.match(ip):
            return True, None
        
        if self.IPV6_PATTERN.match(ip):
            return True, None
        
        return False, "Invalid IP address format"
    
    def validate_hostname(self, hostname: str) -> Tuple[bool, Optional[str]]:
        """
        Validate a hostname.
        
        Args:
            hostname: Hostname string
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not hostname or len(hostname) < 1 or len(hostname) > 253:
            return False, "Hostname must be 1-253 characters"
        
        if self.HOSTNAME_PATTERN.match(hostname):
            return True, None
        
        return False, "Invalid hostname format"
    
    def validate_email(self, email: str) -> Tuple[bool, Optional[str]]:
        """
        Validate an email address.
        
        Args:
            email: Email address string
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not email:
            return False, "Email cannot be empty"
        
        if self.EMAIL_PATTERN.match(email):
            return True, None
        
        return False, "Invalid email format"
    
    def validate_json(self, json_str: str) -> Tuple[bool, Optional[str]]:
        """
        Validate a JSON string.
        
        Args:
            json_str: JSON string
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        import json
        
        try:
            json.loads(json_str)
            return True, None
        except json.JSONDecodeError as e:
            return False, f"Invalid JSON: {e.msg} at position {e.pos}"
    
    def validate_username(self, username: str) -> Tuple[bool, Optional[str]]:
        """
        Validate a username.
        
        Args:
            username: Username string
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not username:
            return False, "Username cannot be empty"
        
        if len(username) < 1 or len(username) > 100:
            return False, "Username must be 1-100 characters"
        
        if not re.match(r'^[a-zA-Z0-9_-]+$', username):
            return False, "Username can only contain letters, numbers, underscores, and hyphens"
        
        return True, None
    
    def validate_script_name(self, name: str) -> Tuple[bool, Optional[str]]:
        """
        Validate a script name.
        
        Args:
            name: Script name
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not name:
            return False, "Script name cannot be empty"
        
        if len(name) < 1 or len(name) > 100:
            return False, "Script name must be 1-100 characters"
        
        return True, None
    
    def validate_path(self, path: str) -> Tuple[bool, Optional[str]]:
        """
        Validate a file path.
        
        Args:
            path: File path string
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not path:
            return False, "Path cannot be empty"
        
        try:
            from pathlib import Path
            p = Path(path)
            # Check for null bytes and other invalid characters
            if '\x00' in path:
                return False, "Path contains null bytes"
            return True, None
        except Exception:
            return False, "Invalid path"
    
    def validate_url(self, url: str) -> Tuple[bool, Optional[str]]:
        """
        Validate a URL.
        
        Args:
            url: URL string
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not url:
            return False, "URL cannot be empty"
        
        # Simple URL validation
        pattern = re.compile(
            r'^(https?|ftp)://'
            r'[^\s/$.?#].[^\s]*$',
            re.IGNORECASE
        )
        
        if pattern.match(url):
            return True, None
        
        return False, "Invalid URL format"
    
    def validate_color_hex(self, color: str) -> Tuple[bool, Optional[str]]:
        """
        Validate a hex color code.
        
        Args:
            color: Hex color string (with or without #)
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not color:
            return False, "Color cannot be empty"
        
        pattern = re.compile(r'^#?([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$')
        
        if pattern.match(color):
            return True, None
        
        return False, "Invalid hex color format"
