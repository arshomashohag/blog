<template>
  <article class="blog-post" v-if="post">
    <header class="post-header">
      <div class="container">
        <router-link to="/blogs" class="back-link">← Back to Articles</router-link>
        <span class="category-tag" v-if="post.category">{{ post.category }}</span>
        <h1 class="post-title">{{ post.title }}</h1>
        <div class="post-meta">
          <time>{{ formatDate(post.published_at) }}</time>
        </div>
      </div>
    </header>
    
    <div class="container">
      <div class="post-content" v-html="post.content_html"></div>
    </div>
  </article>
  
  <div v-else-if="loading" class="loading">
    <div class="spinner"></div>
  </div>
  
  <div v-else class="not-found">
    <div class="container">
      <h1>Post Not Found</h1>
      <p>The article you're looking for doesn't exist.</p>
      <router-link to="/blogs" class="btn btn-primary">Browse Articles</router-link>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import api from '@/services/api'

const route = useRoute()
const post = ref(null)
const loading = ref(true)

const formatDate = (dateStr) => {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
}

const loadPost = async () => {
  loading.value = true
  post.value = null
  
  try {
    const res = await api.getBlogBySlug(route.params.slug)
    post.value = res.post
    
    // Update page title
    if (post.value) {
      document.title = `${post.value.title} - Blog`
    }
  } catch (error) {
    console.error('Failed to load post:', error)
  } finally {
    loading.value = false
  }
}

watch(() => route.params.slug, loadPost)
onMounted(loadPost)
</script>

<style scoped>
.post-header {
  background: var(--color-bg-secondary);
  padding: 4rem 2rem;
  border-bottom: 1px solid var(--color-border);
}

.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 0 2rem;
}

.back-link {
  display: inline-block;
  color: var(--color-text-light);
  text-decoration: none;
  margin-bottom: 1.5rem;
  transition: color 0.2s;
}

.back-link:hover {
  color: var(--color-primary);
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
  margin-bottom: 1rem;
}

.post-title {
  font-family: 'Playfair Display', serif;
  font-size: 2.5rem;
  font-weight: 700;
  line-height: 1.2;
  margin-bottom: 1rem;
}

.post-meta {
  color: var(--color-text-muted);
  font-size: 0.9rem;
}

.post-content {
  padding: 3rem 0;
  font-size: 1.1rem;
  line-height: 1.8;
  color: var(--color-text);
}

.post-content :deep(h1),
.post-content :deep(h2),
.post-content :deep(h3) {
  font-family: 'Playfair Display', serif;
  margin: 2rem 0 1rem;
}

.post-content :deep(h1) { font-size: 2rem; }
.post-content :deep(h2) { font-size: 1.5rem; }
.post-content :deep(h3) { font-size: 1.25rem; }

.post-content :deep(p) {
  margin-bottom: 1.5rem;
}

.post-content :deep(a) {
  color: var(--color-primary);
}

.post-content :deep(blockquote) {
  border-left: 4px solid var(--color-primary);
  padding-left: 1.5rem;
  margin: 2rem 0;
  font-style: italic;
  color: var(--color-text-light);
}

.post-content :deep(pre) {
  background: var(--color-bg);
  padding: 1.5rem;
  border-radius: 8px;
  overflow-x: auto;
  margin: 1.5rem 0;
}

.post-content :deep(code) {
  font-family: 'Fira Code', monospace;
  font-size: 0.9em;
}

.post-content :deep(img) {
  max-width: 100%;
  height: auto;
  border-radius: 8px;
  margin: 1.5rem 0;
}

.post-content :deep(ul),
.post-content :deep(ol) {
  margin: 1.5rem 0;
  padding-left: 2rem;
}

.post-content :deep(li) {
  margin-bottom: 0.5rem;
}

.loading,
.not-found {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 60vh;
  text-align: center;
}

.not-found h1 {
  font-family: 'Playfair Display', serif;
  font-size: 2rem;
  margin-bottom: 1rem;
}

.not-found p {
  color: var(--color-text-light);
  margin-bottom: 2rem;
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
  .post-title {
    font-size: 1.75rem;
  }
  
  .post-content {
    font-size: 1rem;
  }
}
</style>
