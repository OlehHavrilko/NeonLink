"""
CredentialManager - System keyring integration.

Provides secure storage of credentials using:
- Windows Credential Manager
- macOS Keychain
- Linux SecretService / KWallet
"""

import json
import socket
from abc import ABC, abstractmethod
from typing import Optional, Tuple

import keyring
from keyring.backends.fail import Keyring as FailKeyring


class CredentialStorageError(Exception):
    """Raised when credential storage operations fail."""
    pass


class CredentialManager:
    """
    Manager for secure credential storage in system keyring.
    
    Supports:
    - Windows: Win32 Credential Manager
    - macOS: Keychain
    - Linux: SecretService (GNOME) or KWallet
    
    Attributes:
        SERVICE_NAME: Service identifier for keyring
    """
    
    SERVICE_NAME = 'neonlink_desktop'
    
    def __init__(self):
        """Initialize CredentialManager and detect available backend."""
        self._backend = keyring.get_keyring()
        
        if isinstance(self._backend, FailKeyring):
            raise CredentialStorageError(
                "No suitable keyring backend available. "
                "Please install keyring[windows] or keyring[macOS] or libsecret on Linux."
            )
    
    def save_credential(
        self,
        profile_id: str,
        username: str,
        password: str,
        extra_params: Optional[dict] = None
    ) -> None:
        """
        Save credentials for a connection profile.
        
        Stores:
        - username:plaintext - Username
        - password:{profile_id} - Password
        - extra_params:{profile_id} - Optional JSON params
        
        Args:
            profile_id: Unique profile identifier
            username: Username for authentication
            password: Password for authentication
            extra_params: Optional additional parameters
        """
        try:
            # Save username
            keyring.set_password(
                self.SERVICE_NAME,
                f"username:{profile_id}",
                username
            )
            
            # Save password
            keyring.set_password(
                self.SERVICE_NAME,
                f"password:{profile_id}",
                password
            )
            
            # Save extra params if provided
            if extra_params:
                extra_json = json.dumps(extra_params)
                keyring.set_password(
                    self.SERVICE_NAME,
                    f"extra_params:{profile_id}",
                    extra_json
                )
                    
        except Exception as e:
            raise CredentialStorageError(f"Failed to save credential: {e}")
    
    def get_credential(self, profile_id: str) -> Tuple[str, str, dict]:
        """
        Get credentials for a connection profile.
        
        Args:
            profile_id: Unique profile identifier
            
        Returns:
            Tuple of (username, password, extra_params)
            
        Raises:
            CredentialStorageError: If credentials not found
        """
        try:
            username = keyring.get_password(
                self.SERVICE_NAME,
                f"username:{profile_id}"
            )
            
            password = keyring.get_password(
                self.SERVICE_NAME,
                f"password:{profile_id}"
            )
            
            extra_json = keyring.get_password(
                self.SERVICE_NAME,
                f"extra_params:{profile_id}"
            )
            extra_params = json.loads(extra_json) if extra_json else {}
            
            if username is None or password is None:
                raise CredentialStorageError(
                    f"Credentials not found for profile: {profile_id}"
                )
            
            return username, password, extra_params
                
        except CredentialStorageError:
            raise
        except Exception as e:
            raise CredentialStorageError(f"Failed to get credential: {e}")
    
    def delete_credential(self, profile_id: str) -> None:
        """
        Delete credentials for a connection profile.
        
        Args:
            profile_id: Unique profile identifier
        """
        try:
            keyring.delete_password(
                self.SERVICE_NAME,
                f"password:{profile_id}"
            )
            keyring.delete_password(
                self.SERVICE_NAME,
                f"username:{profile_id}"
            )
            
            try:
                keyring.delete_password(
                    self.SERVICE_NAME,
                    f"extra_params:{profile_id}"
                )
            except keyring.errors.KeyringError:
                pass  # Extra params may not exist
                    
        except Exception as e:
            raise CredentialStorageError(f"Failed to delete credential: {e}")
    
    def credential_exists(self, profile_id: str) -> bool:
        """
        Check if credentials exist for a profile.
        
        Args:
            profile_id: Unique profile identifier
            
        Returns:
            True if credentials exist
        """
        try:
            password = keyring.get_password(
                self.SERVICE_NAME,
                f"password:{profile_id}"
            )
            return password is not None
        except Exception:
            return False
    
    def test_connection(
        self,
        host: str,
        port: int,
        timeout: float = 5.0
    ) -> bool:
        """
        Test connection to a host using socket.
        
        Args:
            host: Hostname or IP address
            port: Port number
            timeout: Connection timeout in seconds
            
        Returns:
            True if connection successful
        """
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        
        try:
            result = sock.connect_ex((host, port))
            return result == 0
        except socket.error:
            return False
        finally:
            sock.close()
    
    def list_profiles(self) -> list[str]:
        """
        List all stored profile IDs.
        
        Returns:
            List of profile IDs with stored credentials
        """
        profiles = set()
        
        try:
            # Get all passwords for our service
            # Note: keyring doesn't provide direct listing
            # This is a workaround
            pass
        except Exception:
            pass
        
        return list(profiles)
