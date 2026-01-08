"""Authentication utilities for admin routes."""
import os
import hmac
from functools import wraps
from flask import request, jsonify, current_app


def get_admin_token():
    """Get admin token from environment or config."""
    return os.environ.get('ADMIN_TOKEN', current_app.config.get('ADMIN_TOKEN'))


def verify_admin_token(token: str) -> bool:
    """
    Verify the admin token using constant-time comparison.
    
    Args:
        token: Token to verify
        
    Returns:
        True if valid, False otherwise
    """
    expected_token = get_admin_token()
    if not expected_token or not token:
        return False
    
    # Use constant-time comparison to prevent timing attacks
    return hmac.compare_digest(token, expected_token)


def require_admin(f):
    """
    Decorator to require admin authentication.
    Expects Authorization header with Bearer token.
    
    Note: IP whitelisting is handled by WAF at CloudFront level,
    this provides an additional layer of security.
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        
        if not auth_header.startswith('Bearer '):
            return jsonify({
                'error': 'Unauthorized',
                'message': 'Missing or invalid authorization header'
            }), 401
        
        token = auth_header[7:]  # Remove 'Bearer ' prefix
        
        if not verify_admin_token(token):
            return jsonify({
                'error': 'Unauthorized',
                'message': 'Invalid admin token'
            }), 401
        
        return f(*args, **kwargs)
    
    return decorated_function
