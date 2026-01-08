const API_BASE = '/api'

class ApiService {
  constructor() {
    this.baseUrl = API_BASE
  }

  getToken() {
    return localStorage.getItem('adminToken')
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseUrl}${endpoint}`
    const headers = {
      'Content-Type': 'application/json',
      ...options.headers
    }

    if (options.auth) {
      const token = this.getToken()
      if (token) {
        headers['Authorization'] = `Bearer ${token}`
      }
    }

    const response = await fetch(url, {
      ...options,
      headers
    })

    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || `HTTP ${response.status}`)
    }

    return response.json()
  }

  // Public API
  async getBlogs(params = {}) {
    const query = new URLSearchParams(params).toString()
    return this.request(`/public/blogs${query ? `?${query}` : ''}`)
  }

  async getBlogBySlug(slug) {
    return this.request(`/public/blogs/slug/${slug}`)
  }

  async getLatestBlog() {
    return this.request('/public/blogs/latest')
  }

  async getCategories() {
    return this.request('/public/categories')
  }

  // Admin API
  async verifyToken(token) {
    return this.request('/admin/health', {
      auth: true,
      headers: token ? { 'Authorization': `Bearer ${token}` } : {}
    })
  }

  async getAdminBlogs(params = {}) {
    const query = new URLSearchParams(params).toString()
    return this.request(`/admin/blogs${query ? `?${query}` : ''}`, { auth: true })
  }

  async getAdminBlog(id) {
    return this.request(`/admin/blogs/${id}`, { auth: true })
  }

  async createBlog(data) {
    return this.request('/admin/blogs', {
      method: 'POST',
      auth: true,
      body: JSON.stringify(data)
    })
  }

  async updateBlog(id, data) {
    return this.request(`/admin/blogs/${id}`, {
      method: 'PUT',
      auth: true,
      body: JSON.stringify(data)
    })
  }

  async deleteBlog(id) {
    return this.request(`/admin/blogs/${id}`, {
      method: 'DELETE',
      auth: true
    })
  }

  async getAdminCategories() {
    return this.request('/admin/categories', { auth: true })
  }
}

export const api = new ApiService()
export default api
