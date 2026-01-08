"""Admin API routes for blog management."""
import json
from datetime import datetime, timezone
from flask import Blueprint, jsonify, request
from pynamodb.exceptions import DoesNotExist, PutError
from slugify import slugify
from uuid6 import uuid7

from app.models.blog import BlogPost, Category
from app.utils.auth import require_admin
from app.utils.sanitizer import sanitize_html, generate_excerpt

admin_bp = Blueprint('admin', __name__)


def get_iso_timestamp():
    """Get current UTC timestamp in ISO format."""
    return datetime.now(timezone.utc).isoformat()


@admin_bp.route('/health', methods=['GET'])
@require_admin
def health_check():
    """Health check endpoint for admin API."""
    return jsonify({'status': 'healthy', 'admin': True}), 200


@admin_bp.route('/blogs', methods=['GET'])
@require_admin
def list_all_blogs():
    """
    List all blog posts (including drafts) for admin.
    
    Query params:
        - status: Filter by status (PUBLISHED, DRAFT)
        - limit: Number of posts to return (default: 20, max: 100)
    """
    limit = min(int(request.args.get('limit', 20)), 100)
    status = request.args.get('status')
    
    try:
        if status:
            results = BlogPost.status_index.query(
                status.upper(),
                scan_index_forward=False,
                limit=limit
            )
        else:
            # Scan all blog posts
            results = BlogPost.scan(
                filter_condition=(BlogPost.sk == 'METADATA') & (BlogPost.pk.startswith('BLOG#')),
                limit=limit
            )
        
        posts = [post.to_dict(include_content=False) for post in results]
        
        return jsonify({
            'posts': posts,
            'count': len(posts)
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500


@admin_bp.route('/blogs/<blog_id>', methods=['GET'])
@require_admin
def get_blog(blog_id):
    """Get a single blog post by ID (including drafts)."""
    try:
        post = BlogPost.get(f'BLOG#{blog_id}', 'METADATA')
        return jsonify({'post': post.to_dict()}), 200
        
    except DoesNotExist:
        return jsonify({
            'error': 'Not Found',
            'message': 'Blog post not found'
        }), 404
    except Exception as e:
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500


@admin_bp.route('/blogs', methods=['POST'])
@require_admin
def create_blog():
    """
    Create a new blog post.
    
    Expected JSON body:
        - title: string (required)
        - content_delta: string (Quill Delta JSON, required)
        - content_html: string (rendered HTML, required)
        - category: string (optional)
        - status: string (DRAFT or PUBLISHED, default: DRAFT)
        - excerpt: string (optional, auto-generated if not provided)
    """
    data = request.get_json()
    
    if not data:
        return jsonify({
            'error': 'Bad Request',
            'message': 'Request body is required'
        }), 400
    
    # Validate required fields
    required_fields = ['title', 'content_delta', 'content_html']
    missing = [f for f in required_fields if not data.get(f)]
    if missing:
        return jsonify({
            'error': 'Bad Request',
            'message': f'Missing required fields: {", ".join(missing)}'
        }), 400
    
    try:
        # Generate IDs and timestamps
        blog_id = str(uuid7())
        now = get_iso_timestamp()
        
        # Handle status - ensure it's a string
        raw_status = data.get('status', 'DRAFT')
        status = str(raw_status).upper() if raw_status else 'DRAFT'
        
        # Sanitize HTML content
        sanitized_html = sanitize_html(data['content_html'])
        
        # Generate excerpt if not provided
        excerpt = data.get('excerpt') or generate_excerpt(sanitized_html)
        
        # Generate slug from title
        slug = slugify(data['title'])
        
        # Clean category - strip whitespace and treat empty as None
        raw_category = data.get('category')
        category = raw_category.strip() if raw_category else None
        if category == '':
            category = None
        
        # Create the blog post
        post = BlogPost(
            pk=f'BLOG#{blog_id}',
            sk='METADATA',
            id=blog_id,
            title=data['title'],
            slug=slug,
            excerpt=excerpt,
            content_delta=data['content_delta'],
            content_html=sanitized_html,
            status=status,
            category=category,
            created_at=now,
            updated_at=now,
            published_at=now if status == 'PUBLISHED' else None
        )
        
        post.save()
        
        # Update category post count if category provided
        if category and status == 'PUBLISHED':
            update_category_count(category, 1)
        
        return jsonify({
            'message': 'Blog post created successfully',
            'post': post.to_dict()
        }), 201
        
    except Exception as e:
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500


@admin_bp.route('/blogs/<blog_id>', methods=['PUT'])
@require_admin
def update_blog(blog_id):
    """
    Update an existing blog post.
    
    Expected JSON body (all optional):
        - title: string
        - content_delta: string
        - content_html: string
        - category: string
        - status: string
        - excerpt: string
    """
    data = request.get_json()
    
    if not data:
        return jsonify({
            'error': 'Bad Request',
            'message': 'Request body is required'
        }), 400
    
    try:
        post = BlogPost.get(f'BLOG#{blog_id}', 'METADATA')
        old_status = post.status
        old_category = post.category
        
        now = get_iso_timestamp()
        
        # Update fields if provided
        if 'title' in data:
            post.title = data['title']
            post.slug = slugify(data['title'])
        
        if 'content_html' in data:
            post.content_html = sanitize_html(data['content_html'])
            # Regenerate excerpt if not explicitly provided
            if 'excerpt' not in data:
                post.excerpt = generate_excerpt(post.content_html)
        
        if 'content_delta' in data:
            post.content_delta = data['content_delta']
        
        if 'excerpt' in data:
            post.excerpt = data['excerpt']
        
        if 'category' in data:
            # Clean category - strip whitespace and treat empty as None
            raw_cat = data['category']
            post.category = raw_cat.strip() if raw_cat and isinstance(raw_cat, str) else None
        
        if 'status' in data:
            raw_status = data['status']
            new_status = str(raw_status).upper() if raw_status else post.status
            post.status = new_status
            
            # Set published_at when publishing for the first time
            if new_status == 'PUBLISHED' and old_status != 'PUBLISHED':
                post.published_at = now
        
        post.updated_at = now
        post.save()
        
        # Handle category post count updates
        new_category = post.category
        new_status = post.status
        
        if old_status == 'PUBLISHED' and new_status != 'PUBLISHED':
            # Unpublishing - decrease old category count
            if old_category:
                update_category_count(old_category, -1)
        elif old_status != 'PUBLISHED' and new_status == 'PUBLISHED':
            # Publishing - increase new category count
            if new_category:
                update_category_count(new_category, 1)
        elif old_status == 'PUBLISHED' and new_status == 'PUBLISHED':
            # Category change while published
            if old_category != new_category:
                if old_category:
                    update_category_count(old_category, -1)
                if new_category:
                    update_category_count(new_category, 1)
        
        return jsonify({
            'message': 'Blog post updated successfully',
            'post': post.to_dict()
        }), 200
        
    except DoesNotExist:
        return jsonify({
            'error': 'Not Found',
            'message': 'Blog post not found'
        }), 404
    except Exception as e:
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500


@admin_bp.route('/blogs/<blog_id>', methods=['DELETE'])
@require_admin
def delete_blog(blog_id):
    """Delete a blog post."""
    try:
        post = BlogPost.get(f'BLOG#{blog_id}', 'METADATA')
        
        # Update category count if published
        if post.status == 'PUBLISHED' and post.category:
            update_category_count(post.category, -1)
        
        post.delete()
        
        return jsonify({
            'message': 'Blog post deleted successfully'
        }), 200
        
    except DoesNotExist:
        return jsonify({
            'error': 'Not Found',
            'message': 'Blog post not found'
        }), 404
    except Exception as e:
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500


@admin_bp.route('/categories', methods=['GET'])
@require_admin
def list_categories():
    """List all categories."""
    try:
        results = Category.scan(
            filter_condition=(Category.sk == 'METADATA') & 
                           (Category.pk.startswith('CATEGORY#'))
        )
        
        categories = [cat.to_dict() for cat in results]
        
        return jsonify({
            'categories': categories,
            'count': len(categories)
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500


@admin_bp.route('/categories', methods=['POST'])
@require_admin
def create_category():
    """
    Create a new category.
    
    Expected JSON body:
        - name: string (required)
        - description: string (optional)
    """
    data = request.get_json()
    
    if not data or not data.get('name'):
        return jsonify({
            'error': 'Bad Request',
            'message': 'Category name is required'
        }), 400
    
    try:
        category_name = data['name'].strip()
        
        # Check if category exists
        try:
            existing = Category.get(f'CATEGORY#{category_name}', 'METADATA')
            return jsonify({
                'error': 'Conflict',
                'message': 'Category already exists'
            }), 409
        except DoesNotExist:
            pass
        
        category = Category(
            pk=f'CATEGORY#{category_name}',
            sk='METADATA',
            name=category_name,
            description=data.get('description'),
            post_count=0
        )
        
        category.save()
        
        return jsonify({
            'message': 'Category created successfully',
            'category': category.to_dict()
        }), 201
        
    except Exception as e:
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500


@admin_bp.route('/categories/<category_name>', methods=['DELETE'])
@require_admin
def delete_category(category_name):
    """Delete a category."""
    try:
        category = Category.get(f'CATEGORY#{category_name}', 'METADATA')
        category.delete()
        
        return jsonify({
            'message': 'Category deleted successfully'
        }), 200
        
    except DoesNotExist:
        return jsonify({
            'error': 'Not Found',
            'message': 'Category not found'
        }), 404
    except Exception as e:
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500


@admin_bp.route('/categories/cleanup', methods=['POST'])
@require_admin
def cleanup_categories():
    """Delete categories with null/empty names."""
    try:
        results = Category.scan(
            filter_condition=(Category.sk == 'METADATA') & 
                           (Category.pk.startswith('CATEGORY#'))
        )
        
        deleted = []
        for cat in results:
            if not cat.name or not cat.name.strip():
                cat.delete()
                deleted.append(cat.pk)
        
        return jsonify({
            'message': f'Cleaned up {len(deleted)} invalid categories',
            'deleted_keys': deleted
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500


def update_category_count(category_name: str, delta: int):
    """Update the post count for a category."""
    # Skip if category name is empty or whitespace
    if not category_name or not category_name.strip():
        return
    
    category_name = category_name.strip()
    
    try:
        category = Category.get(f'CATEGORY#{category_name}', 'METADATA')
        category.post_count = max(0, category.post_count + delta)
        category.save()
    except DoesNotExist:
        # Create category if it doesn't exist
        if delta > 0:
            category = Category(
                pk=f'CATEGORY#{category_name}',
                sk='METADATA',
                name=category_name,
                post_count=delta
            )
            category.save()
