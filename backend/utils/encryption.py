import os
import base64
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from core.config import settings


def generate_key_from_password(password: str, salt: bytes = None) -> bytes:
    """Generate a Fernet key from a password"""
    if salt is None:
        salt = os.urandom(16)
    
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100000,
    )
    key = base64.urlsafe_b64encode(kdf.derive(password.encode()))
    return key


def get_encryption_key() -> bytes:
    """Get the encryption key from settings"""
    # Use the encryption key from settings
    # In production, this should be a proper base64-encoded key
    encryption_key = settings.encryption_key
    
    # If it's not a proper base64 key, derive one
    try:
        return base64.urlsafe_b64decode(encryption_key + '==')  # Add padding if needed
    except:
        # Generate key from the string
        return generate_key_from_password(encryption_key)


def encrypt_data(data: str) -> str:
    """Encrypt string data and return base64 encoded result"""
    key = get_encryption_key()
    f = Fernet(base64.urlsafe_b64encode(key[:32]))  # Ensure 32 bytes
    encrypted_data = f.encrypt(data.encode())
    return base64.b64encode(encrypted_data).decode()


def decrypt_data(encrypted_data: str) -> str:
    """Decrypt base64 encoded data and return original string"""
    key = get_encryption_key()
    f = Fernet(base64.urlsafe_b64encode(key[:32]))  # Ensure 32 bytes
    encrypted_bytes = base64.b64decode(encrypted_data.encode())
    decrypted_data = f.decrypt(encrypted_bytes)
    return decrypted_data.decode()