"""Public API routes for blog viewing."""
from flask import Blueprint, jsonify, request
from pynamodb.exceptions import DoesNotExist

from app.models.blog import BlogPost, Category

public_bp = Blueprint('public', __name__)


@public_bp.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({'status': 'healthy'}), 200


@public_bp.route('/blogs', methods=['GET'])
def list_blogs():
    """
    List all published blog posts.
    
    Query params:
        - limit: Number of posts to return (default: 10, max: 50)
        - category: Filter by category
        - cursor: Pagination cursor (last_evaluated_key)
    """
    limit = min(int(request.args.get('limit', 10)), 50)
    category = request.args.get('category')
    
    try:
        if category:
            # Query by category
            results = BlogPost.category_index.query(
                category,
                scan_index_forward=False,  # Newest first
                limit=limit,
                filter_condition=(BlogPost.status == 'PUBLISHED')
            )
        else:
            # Query all published posts
            results = BlogPost.status_index.query(
                'PUBLISHED',
                scan_index_forward=False,  # Newest first
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


@public_bp.route('/blogs/latest', methods=['GET'])
def get_latest_blog():
    """Get the most recently published blog post."""
    try:
        results = BlogPost.status_index.query(
            'PUBLISHED',
            scan_index_forward=False,
            limit=1
        )
        
        posts = list(results)
        if not posts:
            return jsonify({
                'error': 'Not Found',
                'message': 'No published blogs found'
            }), 404
        
        return jsonify({'post': posts[0].to_dict()}), 200
        
    except Exception as e:
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500


@public_bp.route('/blogs/<blog_id>', methods=['GET'])
def get_blog(blog_id):
    """Get a single published blog post by ID."""
    try:
        post = BlogPost.get(f'BLOG#{blog_id}', 'METADATA')
        
        # Only return published posts via public API
        if post.status != 'PUBLISHED':
            return jsonify({
                'error': 'Not Found',
                'message': 'Blog post not found'
            }), 404
        
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


@public_bp.route('/blogs/slug/<slug>', methods=['GET'])
def get_blog_by_slug(slug):
    """Get a single published blog post by slug."""
    try:
        # Scan for the slug (consider adding a GSI for better performance)
        results = BlogPost.status_index.query(
            'PUBLISHED',
            filter_condition=(BlogPost.slug == slug),
            limit=1
        )
        
        posts = list(results)
        if not posts:
            return jsonify({
                'error': 'Not Found',
                'message': 'Blog post not found'
            }), 404
        
        return jsonify({'post': posts[0].to_dict()}), 200
        
    except Exception as e:
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500


@public_bp.route('/categories', methods=['GET'])
def list_categories():
    """List all categories with post counts."""
    try:
        # Scan for all categories
        results = Category.scan(
            filter_condition=(Category.sk == 'METADATA') & 
                           (Category.pk.startswith('CATEGORY#'))
        )
        
        # Filter out categories with null/empty names
        categories = [
            cat.to_dict() for cat in results 
            if cat.name and cat.name.strip()
        ]
        
        return jsonify({
            'categories': categories,
            'count': len(categories)
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500
