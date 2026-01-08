<template>
  <div class="home">
    <section class="hero">
      <div class="hero-content">
        <h1 class="hero-title">Welcome to the Blog</h1>
        <p class="hero-subtitle">Thoughts, stories, and ideas worth sharing</p>
        <router-link to="/blogs" class="btn btn-primary">Browse Articles</router-link>
      </div>
    </section>

    <section class="featured" v-if="latestPost">
      <div class="container">
        <h2 class="section-title">Latest Post</h2>
        <article class="featured-post" @click="goToPost(latestPost.slug)">
          <div class="featured-content">
            <span class="category-tag" v-if="latestPost.category">{{ latestPost.category }}</span>
            <h3 class="featured-title">{{ latestPost.title }}</h3>
            <p class="featured-excerpt">{{ latestPost.excerpt }}</p>
            <div class="post-meta">
              <time>{{ formatDate(latestPost.published_at) }}</time>
            </div>
          </div>
        </article>
      </div>
    </section>

    <section class="recent-posts" v-if="recentPosts.length">
      <div class="container">
        <h2 class="section-title">Recent Articles</h2>
        <div class="posts-grid">
          <article 
            v-for="post in recentPosts" 
            :key="post.id" 
            class="post-card"
            @click="goToPost(post.slug)"
          >
            <span class="category-tag" v-if="post.category">{{ post.category }}</span>
            <h3 class="post-title">{{ post.title }}</h3>
            <p class="post-excerpt">{{ post.excerpt }}</p>
            <time class="post-date">{{ formatDate(post.published_at) }}</time>
          </article>
        </div>
        <div class="view-all">
          <router-link to="/blogs" class="btn btn-secondary">View All Articles →</router-link>
        </div>
      </div>
    </section>

    <div v-if="loading" class="loading">
      <div class="spinner"></div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/services/api'

const router = useRouter()
const latestPost = ref(null)
const recentPosts = ref([])
const loading = ref(true)

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

onMounted(async () => {
  try {
    const [latestRes, blogsRes] = await Promise.all([
      api.getLatestBlog().catch(() => null),
      api.getBlogs({ limit: 4 })
    ])
    
    if (latestRes?.post) {
      latestPost.value = latestRes.post
    }
    
    if (blogsRes?.posts) {
      // Exclude the latest post from recent posts
      recentPosts.value = blogsRes.posts
        .filter(p => p.id !== latestPost.value?.id)
        .slice(0, 3)
    }
  } catch (error) {
    console.error('Failed to load posts:', error)
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, var(--color-bg) 0%, var(--color-bg-secondary) 100%);
  padding: 6rem 2rem;
  text-align: center;
  border-bottom: 1px solid var(--color-border);
}

.hero-title {
  font-family: 'Playfair Display', serif;
  font-size: 3.5rem;
  font-weight: 700;
  margin-bottom: 1rem;
  color: var(--color-text);
}

.hero-subtitle {
  font-size: 1.25rem;
  color: var(--color-text-light);
  margin-bottom: 2rem;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 2rem;
}

.section-title {
  font-family: 'Playfair Display', serif;
  font-size: 2rem;
  margin-bottom: 2rem;
  text-align: center;
}

.featured {
  padding: 4rem 0;
}

.featured-post {
  background: var(--color-bg-secondary);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  padding: 3rem;
  cursor: pointer;
  transition: all 0.3s ease;
}

.featured-post:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.08);
}

.featured-title {
  font-family: 'Playfair Display', serif;
  font-size: 2rem;
  margin: 1rem 0;
}

.featured-excerpt {
  color: var(--color-text-light);
  font-size: 1.1rem;
  line-height: 1.7;
}

.recent-posts {
  padding: 4rem 0;
  background: var(--color-bg-secondary);
}

.posts-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 2rem;
}

.post-card {
  background: var(--color-bg);
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

.post-title {
  font-family: 'Playfair Display', serif;
  font-size: 1.25rem;
  margin: 0.75rem 0;
}

.post-excerpt {
  color: var(--color-text-light);
  font-size: 0.95rem;
  line-height: 1.6;
  margin-bottom: 1rem;
}

.post-date {
  font-size: 0.85rem;
  color: var(--color-text-muted);
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

.view-all {
  text-align: center;
  margin-top: 3rem;
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
  .hero-title {
    font-size: 2.5rem;
  }
  
  .featured-post {
    padding: 2rem;
  }
  
  .featured-title {
    font-size: 1.5rem;
  }
}
</style>
