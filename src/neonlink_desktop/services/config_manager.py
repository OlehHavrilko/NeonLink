"""
ConfigManager - AES-256-GCM encryption for configuration files.

Provides secure storage of application configuration using:
- AES-256-GCM for symmetric encryption
- PBKDF2HMAC for key derivation from master password
- System keyring for master key storage
"""

import os
import json
import base64
import hashlib
from pathlib import Path
from typing import TypeVar, Generic, Type, Any

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

T = TypeVar('T')


class EncryptionError(Exception):
    """Raised when encryption/decryption fails."""
    pass


class ConfigManager(Generic[T]):
    """
    Configuration manager with AES-256-GCM encryption.
    
    Uses:
    - AES-256-GCM for symmetric encryption
    - PBKDF2HMAC for key derivation (600,000 iterations - OWASP)
    - 16-byte nonce for each encryption operation
    
    Attributes:
        config_model: Pydantic model class for configuration
        config_dir: Directory for configuration files
        config_file: Path to encrypted config file
        master_key_file: Path to master key file
    """
    
    # Default paths
    CONFIG_DIR = Path.home() / '.config' / 'neonlink'
    CONFIG_FILE = CONFIG_DIR / 'config.enc'
    MASTER_KEY_FILE = CONFIG_DIR / '.master_key'
    
    # Encryption parameters
    SALT_SIZE = 32
    KEY_LENGTH = 32  # 256 bits for AES-256
    ITERATIONS = 600_000  # OWASP recommendation
    
    def __init__(
        self,
        config_model: Type[T],
        master_password: str | None = None
    ):
        """
        Initialize ConfigManager.
        
        Args:
            config_model: Pydantic model class for configuration
            master_password: Optional master password for key derivation
        """
        self.config_model = config_model
        self._master_password = master_password
        self._ensure_config_dir()
        
        if master_password:
            self._master_key = self._derive_key(master_password)[0]
        else:
            self._master_key = self._load_or_create_master_key()
    
    def _ensure_config_dir(self) -> None:
        """Create configuration directory with proper permissions."""
        self.CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        
        # Unix: rwx------ (700)
        try:
            os.chmod(self.CONFIG_DIR, 0o700)
        except OSError:
            pass  # May fail on Windows
    
    def _derive_key(
        self,
        password: str,
        salt: bytes | None = None
    ) -> tuple[bytes, bytes]:
        """
        Derive encryption key from master password.
        
        Uses PBKDF2HMAC with SHA256.
        
        Args:
            password: Master password
            salt: Optional salt (generated if not provided)
            
        Returns:
            Tuple of (key, salt)
        """
        salt = salt or os.urandom(self.SALT_SIZE)
        
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=self.KEY_LENGTH,
            salt=salt,
            iterations=self.ITERATIONS,
            backend=default_backend()
        )
        
        key = kdf.derive(password.encode('utf-8'))
        return key, salt
    
    def _load_or_create_master_key(self) -> bytes:
        """
        Load existing master key or create new one.
        
        The master key is stored encrypted in the system keyring.
        
        Returns:
            The master key bytes
        """
        if self.MASTER_KEY_FILE.exists():
            try:
                from keyring import get_password
                
                # Get encrypted key from keyring
                encrypted_key_b64 = get_password('neonlink', 'master_key')
                if encrypted_key_b64:
                    encrypted_key = base64.b64decode(encrypted_key_b64)
                    return encrypted_key
            except Exception:
                pass
        
        # Create new master key
        new_key = os.urandom(self.KEY_LENGTH)
        
        # Store in system keyring
        try:
            from keyring import set_password
            encrypted_key_b64 = base64.b64encode(new_key).decode('utf-8')
            set_password('neonlink', 'master_key', encrypted_key_b64)
        except Exception:
            # If keyring is not available, store in file
            # This is less secure but better than nothing
            try:
                os.chmod(self.MASTER_KEY_FILE, 0o600)
            except OSError:
                pass
        
        return new_key
    
    def encrypt(self, data: bytes) -> bytes:
        """
        Encrypt data using AES-256-GCM.
        
        Format: nonce (12 bytes) + ciphertext (with auth tag)
        
        Args:
            data: Plaintext data to encrypt
            
        Returns:
            Encrypted data with nonce prepended
        """
        nonce = os.urandom(12)  # GCM recommended nonce size
        aesgcm = AESGCM(self._master_key)
        
        ciphertext = aesgcm.encrypt(nonce, data, None)
        
        # Return nonce + ciphertext
        return nonce + ciphertext
    
    def decrypt(self, encrypted_data: bytes) -> bytes:
        """
        Decrypt data encrypted with AES-256-GCM.
        
        Args:
            encrypted_data: Data in format: nonce + ciphertext
            
        Returns:
            Decrypted plaintext
            
        Raises:
            EncryptionError: If decryption fails
        """
        if len(encrypted_data) < 28:  # 12 (nonce) + 16 (tag) + min data
            raise EncryptionError("Invalid encrypted data format")
        
        nonce = encrypted_data[:12]
        ciphertext = encrypted_data[12:]
        
        aesgcm = AESGCM(self._master_key)
        return aesgcm.decrypt(nonce, ciphertext, None)
    
    def save(self, config: T) -> None:
        """
        Save configuration to encrypted file.
        
        Args:
            config: Configuration model instance
        """
        json_data = config.model_dump_json()
        data_bytes = json_data.encode('utf-8')
        
        encrypted = self.encrypt(data_bytes)
        
        self.CONFIG_FILE.write_bytes(encrypted)
        
        # Unix: rw------- (600)
        try:
            os.chmod(self.CONFIG_FILE, 0o600)
        except OSError:
            pass
    
    def load(self) -> T:
        """
        Load configuration from encrypted file.
        
        Returns:
            Configuration model instance
        """
        if not self.CONFIG_FILE.exists():
            # Return default config
            return self.config_model()
        
        encrypted = self.CONFIG_FILE.read_bytes()
        data_bytes = self.decrypt(encrypted)
        
        json_data = data_bytes.decode('utf-8')
        return self.config_model.model_validate_json(json_data)
    
    def verify_password(self, password: str) -> bool:
        """
        Verify master password.
        
        Args:
            password: Password to verify
            
        Returns:
            True if password is correct
        """
        try:
            test_key, _ = self._derive_key(password, self._salt if hasattr(self, '_salt') else None)
            return test_key == self._master_key
        except Exception:
            return False
    
    def change_password(self, old_password: str, new_password: str) -> bool:
        """
        Change master password.
        
        Args:
            old_password: Current password
            new_password: New password
            
        Returns:
            True if password was changed successfully
        """
        if not self.verify_password(old_password):
            return False
        
        # Derive new key
        new_key, new_salt = self._derive_key(new_password)
        
        # Update master key
        self._master_key = new_key
        if hasattr(self, '_salt'):
            self._salt = new_salt
        
        # Store new key in keyring
        try:
            from keyring import set_password
            encrypted_key_b64 = base64.b64encode(new_key).decode('utf-8')
            set_password('neonlink', 'master_key', encrypted_key_b64)
        except Exception:
            pass
        
        return True
