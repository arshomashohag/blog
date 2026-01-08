/**
 * Blog API Client
 */
const BlogAPI = {
    // Base URL will be set by CloudFront, use relative paths
    baseUrl: '/api/public',
    adminUrl: '/api/admin',
    
    /**
     * Make API request
     */
    async request(endpoint, options = {}) {
        const url = `${this.baseUrl}${endpoint}`;
        const response = await fetch(url, {
            headers: {
                'Content-Type': 'application/json',
                ...options.headers,
            },
            ...options,
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.message || 'API request failed');
        }
        
        return response.json();
    },
    
    /**
     * Get all published posts
     */
    async getPosts(limit = 10, category = '') {
        let endpoint = `/blogs?limit=${limit}`;
        if (category) {
            endpoint += `&category=${encodeURIComponent(category)}`;
        }
        const data = await this.request(endpoint);
        return data.posts || [];
    },
    
    /**
     * Get latest published post
     */
    async getLatestPost() {
        const data = await this.request('/blogs/latest');
        return data.post;
    },
    
    /**
     * Get single post by ID
     */
    async getPost(id) {
        const data = await this.request(`/blogs/${id}`);
        return data.post;
    },
    
    /**
     * Get post by slug
     */
    async getPostBySlug(slug) {
        const data = await this.request(`/blogs/slug/${encodeURIComponent(slug)}`);
        return data.post;
    },
    
    /**
     * Get all categories
     */
    async getCategories() {
        const data = await this.request('/categories');
        return data.categories || [];
    },
};

/**
 * Admin API Client
 */
const AdminAPI = {
    baseUrl: '/api/admin',
    token: localStorage.getItem('adminToken') || '',
    
    /**
     * Set admin token
     */
    setToken(token) {
        this.token = token;
        localStorage.setItem('adminToken', token);
    },
    
    /**
     * Clear admin token
     */
    clearToken() {
        this.token = '';
        localStorage.removeItem('adminToken');
    },
    
    /**
     * Check if authenticated
     */
    isAuthenticated() {
        return !!this.token;
    },
    
    /**
     * Make authenticated API request
     */
    async request(endpoint, options = {}) {
        const url = `${this.baseUrl}${endpoint}`;
        const response = await fetch(url, {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.token}`,
                ...options.headers,
            },
            ...options,
        });
        
        if (response.status === 401) {
            this.clearToken();
            window.location.href = '/admin/';
            throw new Error('Unauthorized');
        }
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.message || 'API request failed');
        }
        
        return response.json();
    },
    
    /**
     * Verify token is valid
     */
    async verifyToken() {
        try {
            await this.request('/health');
            return true;
        } catch {
            return false;
        }
    },
    
    /**
     * Get all posts (including drafts)
     */
    async getPosts(status = '') {
        let endpoint = '/blogs';
        if (status) {
            endpoint += `?status=${status}`;
        }
        const data = await this.request(endpoint);
        return data.posts || [];
    },
    
    /**
     * Get single post by ID
     */
    async getPost(id) {
        const data = await this.request(`/blogs/${id}`);
        return data.post;
    },
    
    /**
     * Create new post
     */
    async createPost(post) {
        const data = await this.request('/blogs', {
            method: 'POST',
            body: JSON.stringify(post),
        });
        return data.post;
    },
    
    /**
     * Update existing post
     */
    async updatePost(id, updates) {
        const data = await this.request(`/blogs/${id}`, {
            method: 'PUT',
            body: JSON.stringify(updates),
        });
        return data.post;
    },
    
    /**
     * Delete post
     */
    async deletePost(id) {
        return this.request(`/blogs/${id}`, {
            method: 'DELETE',
        });
    },
    
    /**
     * Get all categories
     */
    async getCategories() {
        const data = await this.request('/categories');
        return data.categories || [];
    },
    
    /**
     * Create category
     */
    async createCategory(name, description = '') {
        const data = await this.request('/categories', {
            method: 'POST',
            body: JSON.stringify({ name, description }),
        });
        return data.category;
    },
    
    /**
     * Delete category
     */
    async deleteCategory(name) {
        return this.request(`/categories/${encodeURIComponent(name)}`, {
            method: 'DELETE',
        });
    },
};
