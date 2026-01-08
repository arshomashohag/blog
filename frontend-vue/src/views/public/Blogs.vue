<template>
  <div class="blogs-page">
    <header class="page-header">
      <div class="container">
        <h1 class="page-title">Articles</h1>
        <p class="page-subtitle">Explore all our published content</p>
      </div>
    </header>

    <div class="container">
      <!-- Category Filter -->
      <div class="filters">
        <label class="filter-label">Filter by category:</label>
        <select v-model="selectedCategory" class="category-select">
          <option value="">All Categories ({{ posts.length }})</option>
          <option 
            v-for="cat in categories" 
            :key="cat.name" 
            :value="cat.name"
          >
            {{ cat.name }} ({{ cat.post_count }})
          </option>
        </select>
      </div>

      <!-- Posts Grid -->
      <div class="posts-grid" v-if="filteredPosts.length">
        <article 
          v-for="post in filteredPosts" 
          :key="post.id" 
          class="post-card"
          @click="goToPost(post.slug)"
        >
          <span class="category-tag" v-if="post.category">{{ post.category }}</span>
          <h2 class="post-title">{{ post.title }}</h2>
          <p class="post-excerpt">{{ post.excerpt }}</p>
          <div class="post-meta">
            <time>{{ formatDate(post.published_at) }}</time>
          </div>
        </article>
      </div>

      <!-- Empty State -->
      <div v-else-if="!loading" class="empty-state">
        <p>No articles found{{ selectedCategory ? ` in "${selectedCategory}"` : '' }}</p>
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
import { useRouter, useRoute } from 'vue-router'
import api from '@/services/api'

const router = useRouter()
const route = useRoute()
const posts = ref([])
const categories = ref([])
const selectedCategory = ref('')
const loading = ref(true)

const filteredPosts = computed(() => {
  if (!selectedCategory.value) return posts.value
  return posts.value.filter(p => p.category === selectedCategory.value)
})

const formatDate = (dateStr) => {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
}

const goToPost = (slug) => {
  router.push({ name: 'blog', params: { slug } })
}

const loadData = async () => {
  loading.value = true
  try {
    const [blogsRes, catsRes] = await Promise.all([
      api.getBlogs({ limit: 50 }),
      api.getCategories()
    ])
    
    posts.value = blogsRes.posts || []
    categories.value = catsRes.categories || []
    
    // Check for category in URL
    if (route.query.category) {
      selectedCategory.value = route.query.category
    }
  } catch (error) {
    console.error('Failed to load data:', error)
  } finally {
    loading.value = false
  }
}

// Update URL when category changes
watch(selectedCategory, (newCat) => {
  const query = newCat ? { category: newCat } : {}
  router.replace({ query })
})

onMounted(loadData)
</script>

<style scoped>
.page-header {
  background: var(--color-bg-secondary);
  padding: 4rem 2rem;
  text-align: center;
  border-bottom: 1px solid var(--color-border);
}

.page-title {
  font-family: 'Playfair Display', serif;
  font-size: 2.5rem;
  margin-bottom: 0.5rem;
}

.page-subtitle {
  color: var(--color-text-light);
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

.filters {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 2rem;
  padding-bottom: 2rem;
  border-bottom: 1px solid var(--color-border);
}

.filter-label {
  color: var(--color-text-light);
  font-size: 0.9rem;
}

.category-select {
  padding: 0.6rem 2rem 0.6rem 1rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-bg-secondary);
  color: var(--color-text);
  font-size: 0.95rem;
  font-family: inherit;
  cursor: pointer;
  appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%235c5852' d='M6 8L1 3h10z'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 0.75rem center;
  min-width: 200px;
}

.category-select:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(139, 115, 85, 0.1);
}

.posts-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 2rem;
}

.post-card {
  background: var(--color-bg-secondary);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  padding: 2rem;
  cursor: pointer;
  transition: all 0.3s ease;
}

.post-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.06);
}

.category-tag {
  display: inline-block;
  background: var(--color-bg-warm);
  color: var(--color-primary);
  padding: 0.25rem 0.75rem;
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  border: 1px solid var(--color-border);
}

.post-title {
  font-family: 'Playfair Display', serif;
  font-size: 1.25rem;
  margin: 1rem 0;
  color: var(--color-text);
}

.post-excerpt {
  color: var(--color-text-light);
  font-size: 0.95rem;
  line-height: 1.6;
  margin-bottom: 1rem;
}

.post-meta time {
  font-size: 0.85rem;
  color: var(--color-text-muted);
}

.empty-state {
  text-align: center;
  padding: 4rem;
  color: var(--color-text-light);
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
  .page-title {
    font-size: 2rem;
  }
  
  .posts-grid {
    grid-template-columns: 1fr;
  }
}
</style>
