<template>
  <div class="dashboard">
    <div class="admin-main">
      <div class="admin-header">
        <h1>Dashboard</h1>
        <router-link to="/admin/editor" class="btn btn-primary">+ New Post</router-link>
      </div>

      <!-- Stats -->
      <div class="stats-grid">
        <div class="stat-card">
          <span class="stat-number">{{ stats.published }}</span>
          <span class="stat-label">Published</span>
        </div>
        <div class="stat-card">
          <span class="stat-number">{{ stats.drafts }}</span>
          <span class="stat-label">Drafts</span>
        </div>
        <div class="stat-card">
          <span class="stat-number">{{ stats.categories }}</span>
          <span class="stat-label">Categories</span>
        </div>
      </div>

      <!-- Filter Tabs -->
      <div class="filter-tabs">
        <button 
          :class="['tab', { active: filter === '' }]"
          @click="filter = ''"
        >
          All Posts
        </button>
        <button 
          :class="['tab', { active: filter === 'PUBLISHED' }]"
          @click="filter = 'PUBLISHED'"
        >
          Published
        </button>
        <button 
          :class="['tab', { active: filter === 'DRAFT' }]"
          @click="filter = 'DRAFT'"
        >
          Drafts
        </button>
      </div>

      <!-- Posts Table -->
      <div class="posts-table" v-if="filteredPosts.length">
        <div 
          v-for="post in filteredPosts" 
          :key="post.id" 
          class="post-row"
          @click="editPost(post.id)"
        >
          <div class="post-info">
            <h3 class="post-title">{{ post.title }}</h3>
            <div class="post-meta">
              <span class="category" v-if="post.category">{{ post.category }}</span>
              <span class="date">{{ formatDate(post.updated_at) }}</span>
            </div>
          </div>
          <div class="post-status">
            <span :class="['status-badge', post.status.toLowerCase()]">
              {{ post.status }}
            </span>
          </div>
        </div>
      </div>

      <!-- Empty State -->
      <div v-else-if="!loading" class="empty-state">
        <p>No posts found</p>
        <router-link to="/admin/editor" class="btn btn-primary">Create your first post</router-link>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="loading">
        <div class="spinner"></div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/services/api'

const router = useRouter()
const posts = ref([])
const categories = ref([])
const loading = ref(true)
const filter = ref('')

const stats = computed(() => ({
  published: posts.value.filter(p => p.status === 'PUBLISHED').length,
  drafts: posts.value.filter(p => p.status === 'DRAFT').length,
  categories: categories.value.length
}))

const filteredPosts = computed(() => {
  if (!filter.value) return posts.value
  return posts.value.filter(p => p.status === filter.value)
})

const formatDate = (dateStr) => {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  })
}

const editPost = (id) => {
  router.push({ name: 'admin-editor', params: { id } })
}

const loadData = async () => {
  loading.value = true
  try {
    const [postsRes, catsRes] = await Promise.all([
      api.getAdminBlogs({ limit: 100 }),
      api.getAdminCategories()
    ])
    
    posts.value = postsRes.posts || []
    categories.value = catsRes.categories || []
  } catch (error) {
    console.error('Failed to load data:', error)
  } finally {
    loading.value = false
  }
}

onMounted(loadData)
</script>

<style scoped>
.admin-main {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

.admin-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.admin-header h1 {
  font-family: 'Playfair Display', serif;
  font-size: 2rem;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.5rem;
  margin-bottom: 2rem;
}

.stat-card {
  background: var(--color-bg-secondary);
  padding: 2rem;
  border-radius: 12px;
  border: 1px solid var(--color-border);
  text-align: center;
}

.stat-number {
  display: block;
  font-size: 2.5rem;
  font-weight: 700;
  color: var(--color-primary);
}

.stat-label {
  display: block;
  color: var(--color-text-light);
  margin-top: 0.5rem;
}

.filter-tabs {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
  border-bottom: 1px solid var(--color-border);
  padding-bottom: 1rem;
}

.tab {
  padding: 0.5rem 1rem;
  border: none;
  background: transparent;
  color: var(--color-text-light);
  cursor: pointer;
  border-radius: 8px;
  transition: all 0.2s;
}

.tab:hover {
  background: var(--color-bg-secondary);
}

.tab.active {
  background: var(--color-primary);
  color: white;
}

.posts-table {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.post-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: var(--color-bg-secondary);
  padding: 1.5rem;
  border-radius: 12px;
  border: 1px solid var(--color-border);
  cursor: pointer;
  transition: all 0.2s;
}

.post-row:hover {
  border-color: var(--color-primary);
  transform: translateX(4px);
}

.post-title {
  font-size: 1.1rem;
  font-weight: 500;
  margin-bottom: 0.5rem;
}

.post-meta {
  display: flex;
  gap: 1rem;
  font-size: 0.85rem;
  color: var(--color-text-light);
}

.category {
  background: var(--color-bg);
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
}

.status-badge {
  padding: 0.25rem 0.75rem;
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
}

.status-badge.published {
  background: #e8f0e7;
  color: #5a7a56;
}

.status-badge.draft {
  background: #f5efe5;
  color: #8b7355;
}

.empty-state {
  text-align: center;
  padding: 4rem;
  color: var(--color-text-light);
}

.empty-state p {
  margin-bottom: 1rem;
}

.loading {
  display: flex;
  justify-content: center;
  padding: 4rem;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid var(--color-border);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 768px) {
  .stats-grid {
    grid-template-columns: 1fr;
  }
  
  .admin-header {
    flex-direction: column;
    gap: 1rem;
    align-items: flex-start;
  }
}
</style>
