"""PynamoDB models for blog posts and categories."""
import os
from datetime import datetime, timezone
from pynamodb.models import Model
from pynamodb.attributes import (
    UnicodeAttribute,
    UTCDateTimeAttribute,
    NumberAttribute,
    MapAttribute,
)
from pynamodb.indexes import GlobalSecondaryIndex, AllProjection


class StatusPublishedIndex(GlobalSecondaryIndex):
    """GSI for querying posts by status and published date."""
    
    class Meta:
        index_name = 'status-publishedAt-index'
        projection = AllProjection()
        read_capacity_units = 1
        write_capacity_units = 1
    
    status = UnicodeAttribute(hash_key=True)
    published_at = UnicodeAttribute(range_key=True)


class CategoryPostIndex(GlobalSecondaryIndex):
    """GSI for querying posts by category."""
    
    class Meta:
        index_name = 'category-publishedAt-index'
        projection = AllProjection()
        read_capacity_units = 1
        write_capacity_units = 1
    
    category = UnicodeAttribute(hash_key=True)
    published_at = UnicodeAttribute(range_key=True)


class BlogPost(Model):
    """Blog post model using single-table design."""
    
    class Meta:
        table_name = os.environ.get('DYNAMODB_TABLE', 'blog-table')
        region = os.environ.get('AWS_REGION', 'us-east-1')
        host = os.environ.get('DYNAMODB_HOST', None)  # For local development
    
    # Primary Key
    pk = UnicodeAttribute(hash_key=True)  # BLOG#<uuid>
    sk = UnicodeAttribute(range_key=True)  # METADATA
    
    # GSI keys
    status = UnicodeAttribute()  # PUBLISHED or DRAFT
    published_at = UnicodeAttribute(null=True)  # ISO timestamp for sorting
    category = UnicodeAttribute(null=True)
    
    # Attributes
    id = UnicodeAttribute()
    title = UnicodeAttribute()
    slug = UnicodeAttribute()
    excerpt = UnicodeAttribute(null=True)
    content_delta = UnicodeAttribute()  # Quill Delta JSON
    content_html = UnicodeAttribute()   # Rendered HTML for display
    
    created_at = UnicodeAttribute()
    updated_at = UnicodeAttribute()
    
    # GSI
    status_index = StatusPublishedIndex()
    category_index = CategoryPostIndex()
    
    def to_dict(self, include_content=True):
        """Convert model to dictionary."""
        data = {
            'id': self.id,
            'title': self.title,
            'slug': self.slug,
            'excerpt': self.excerpt,
            'status': self.status,
            'category': self.category,
            'created_at': self.created_at,
            'updated_at': self.updated_at,
            'published_at': self.published_at,
        }
        if include_content:
            data['content_delta'] = self.content_delta
            data['content_html'] = self.content_html
        return data


class Category(Model):
    """Category model."""
    
    class Meta:
        table_name = os.environ.get('DYNAMODB_TABLE', 'blog-table')
        region = os.environ.get('AWS_REGION', 'us-east-1')
        host = os.environ.get('DYNAMODB_HOST', None)
    
    # Primary Key
    pk = UnicodeAttribute(hash_key=True)  # CATEGORY#<name>
    sk = UnicodeAttribute(range_key=True)  # METADATA
    
    name = UnicodeAttribute()
    description = UnicodeAttribute(null=True)
    post_count = NumberAttribute(default=0)
    
    def to_dict(self):
        """Convert model to dictionary."""
        return {
            'name': self.name,
            'description': self.description,
            'post_count': self.post_count,
        }
