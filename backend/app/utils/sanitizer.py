"""HTML sanitization utilities to prevent XSS attacks."""
import bleach

# Allowed tags for blog content
ALLOWED_TAGS = [
    'p', 'br', 'strong', 'em', 'u', 's', 'sub', 'sup',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'ul', 'ol', 'li',
    'blockquote', 'pre', 'code',
    'a', 'img',
    'span', 'div',
    'table', 'thead', 'tbody', 'tr', 'th', 'td',
]

# Allowed attributes
ALLOWED_ATTRIBUTES = {
    '*': ['class', 'style'],
    'a': ['href', 'title', 'target', 'rel'],
    'img': ['src', 'alt', 'title', 'width', 'height'],
    'span': ['style'],
}

# Allowed CSS properties
ALLOWED_STYLES = [
    'color', 'background-color', 'font-size', 'font-weight',
    'font-style', 'text-decoration', 'text-align',
]


def sanitize_html(html_content: str) -> str:
    """
    Sanitize HTML content to prevent XSS attacks.
    
    Args:
        html_content: Raw HTML string from the editor
        
    Returns:
        Sanitized HTML string safe for rendering
    """
    if not html_content:
        return ''
    
    # Clean the HTML
    cleaned = bleach.clean(
        html_content,
        tags=ALLOWED_TAGS,
        attributes=ALLOWED_ATTRIBUTES,
        strip=True,
    )
    
    # Linkify URLs (optional, makes plain URLs clickable)
    cleaned = bleach.linkify(cleaned, skip_tags=['pre', 'code'])
    
    return cleaned


def strip_html(html_content: str) -> str:
    """
    Strip all HTML tags and return plain text.
    Useful for generating excerpts.
    
    Args:
        html_content: HTML string
        
    Returns:
        Plain text without HTML tags
    """
    if not html_content:
        return ''
    
    return bleach.clean(html_content, tags=[], strip=True)


def generate_excerpt(html_content: str, max_length: int = 200) -> str:
    """
    Generate a plain text excerpt from HTML content.
    
    Args:
        html_content: HTML string
        max_length: Maximum length of excerpt
        
    Returns:
        Plain text excerpt
    """
    plain_text = strip_html(html_content)
    
    if len(plain_text) <= max_length:
        return plain_text
    
    # Truncate at word boundary
    truncated = plain_text[:max_length].rsplit(' ', 1)[0]
    return truncated + '...'
