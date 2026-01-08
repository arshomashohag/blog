<template>
  <div class="editor-page">
    <div class="editor-main">
      <form @submit.prevent="savePost" class="editor-form">
        <!-- Header -->
        <div class="editor-header">
          <h1>{{ isEditing ? 'Edit Post' : 'New Post' }}</h1>
          <div class="header-actions">
            <router-link to="/admin/dashboard" class="btn btn-secondary">Cancel</router-link>
            <button type="submit" class="btn btn-primary" :disabled="saving">
              {{ saving ? 'Saving...' : 'Save' }}
            </button>
          </div>
        </div>

        <div class="editor-grid">
          <!-- Main Content -->
          <div class="editor-content">
            <div class="form-group">
              <input 
                v-model="form.title" 
                type="text" 
                class="input input-large" 
                placeholder="Post title..."
                required
              >
            </div>

            <div class="form-group">
              <div class="editor-wrapper" :class="{ fullscreen: isFullscreen }">
                <div ref="editorRef"></div>
              </div>
            </div>
          </div>

          <!-- Sidebar -->
          <div class="editor-sidebar">
            <!-- Status -->
            <div class="sidebar-card" v-if="isEditing">
              <h3>Status</h3>
              <select v-model="form.status" class="input">
                <option value="DRAFT">Draft</option>
                <option value="PUBLISHED">Published</option>
              </select>
            </div>

            <!-- Category -->
            <div class="sidebar-card">
              <h3>Category</h3>
              <input 
                v-model="form.category"
                list="categories-list"
                class="input"
                placeholder="Select or type category"
              >
              <datalist id="categories-list">
                <option v-for="cat in categories" :key="cat.name" :value="cat.name" />
              </datalist>
            </div>

            <!-- Actions -->
            <div class="sidebar-card">
              <h3>Actions</h3>
              <div class="action-buttons">
                <button 
                  type="button" 
                  class="btn btn-secondary btn-block"
                  @click="saveAsDraft"
                  :disabled="saving"
                >
                  Save as Draft
                </button>
                <button 
                  type="button" 
                  class="btn btn-primary btn-block"
                  @click="publish"
                  :disabled="saving"
                >
                  {{ form.status === 'PUBLISHED' ? 'Update' : 'Publish' }}
                </button>
              </div>
            </div>

            <!-- Danger Zone -->
            <div class="sidebar-card danger-zone" v-if="isEditing">
              <h3>Danger Zone</h3>
              <button 
                type="button" 
                class="btn btn-danger btn-block"
                @click="deletePost"
                :disabled="saving"
              >
                Delete Post
              </button>
            </div>
          </div>
        </div>
      </form>
    </div>

    <!-- Loading Overlay -->
    <div v-if="loading" class="loading-overlay">
      <div class="spinner"></div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/services/api'

const route = useRoute()
const router = useRouter()

const editorRef = ref(null)
let quillInstance = null

const loading = ref(false)
const saving = ref(false)
const isFullscreen = ref(false)
const categories = ref([])
const postId = ref(null)

const form = reactive({
  title: '',
  content_delta: '',
  content_html: '',
  category: '',
  status: 'DRAFT'
})

const isEditing = computed(() => !!postId.value)

// Initialize Quill editor
const initQuill = async () => {
  // Dynamic import for Quill
  const Quill = (await import('quill')).default
  await import('quill/dist/quill.snow.css')
  
  quillInstance = new Quill(editorRef.value, {
    theme: 'snow',
    placeholder: 'Write your post content here...',
    modules: {
      toolbar: [
        [{ 'header': [1, 2, 3, false] }],
        ['bold', 'italic', 'underline', 'strike'],
        [{ 'color': [] }, { 'background': [] }],
        [{ 'list': 'ordered'}, { 'list': 'bullet' }],
        ['blockquote', 'code-block'],
        ['link', 'image'],
        ['clean']
      ]
    }
  })
  
  // Add fullscreen button
  const toolbar = editorRef.value.parentElement.querySelector('.ql-toolbar')
  if (toolbar) {
    const fullscreenBtn = document.createElement('button')
    fullscreenBtn.type = 'button'
    fullscreenBtn.className = 'ql-fullscreen'
    fullscreenBtn.innerHTML = '⛶'
    fullscreenBtn.title = 'Toggle fullscreen'
    fullscreenBtn.onclick = () => { isFullscreen.value = !isFullscreen.value }
    
    const group = document.createElement('span')
    group.className = 'ql-formats'
    group.appendChild(fullscreenBtn)
    toolbar.appendChild(group)
  }
  
  // Set initial content if editing
  if (form.content_delta) {
    try {
      quillInstance.setContents(JSON.parse(form.content_delta))
    } catch (e) {
      console.error('Failed to parse content:', e)
    }
  }
}

// Get editor content
const getEditorContent = () => {
  if (!quillInstance) return { delta: '', html: '' }
  return {
    delta: JSON.stringify(quillInstance.getContents()),
    html: quillInstance.root.innerHTML
  }
}

// Generate excerpt
const generateExcerpt = (html, maxLength = 200) => {
  const text = html.replace(/<[^>]+>/g, '').trim()
  if (text.length <= maxLength) return text
  return text.substring(0, maxLength).trim() + '...'
}

// Save post
const savePost = async (status = form.status) => {
  if (!form.title.trim()) {
    alert('Please enter a title')
    return
  }
  
  saving.value = true
  
  try {
    const { delta, html } = getEditorContent()
    
    const data = {
      title: form.title.trim(),
      content_delta: delta,
      content_html: html,
      excerpt: generateExcerpt(html),
      category: form.category.trim() || null,
      status
    }
    
    if (isEditing.value) {
      await api.updateBlog(postId.value, data)
    } else {
      const res = await api.createBlog(data)
      postId.value = res.post.id
      // Update URL without navigation
      history.replaceState(null, '', `/admin/editor/${postId.value}`)
    }
    
    form.status = status
    
    // Show success feedback
    const msg = status === 'PUBLISHED' ? 'Published!' : 'Saved as draft'
    showToast(msg)
    
  } catch (error) {
    console.error('Failed to save:', error)
    alert('Failed to save post: ' + error.message)
  } finally {
    saving.value = false
  }
}

const saveAsDraft = () => savePost('DRAFT')
const publish = () => savePost('PUBLISHED')

// Delete post
const deletePost = async () => {
  if (!confirm('Are you sure you want to delete this post? This cannot be undone.')) {
    return
  }
  
  saving.value = true
  
  try {
    await api.deleteBlog(postId.value)
    router.push({ name: 'admin-dashboard' })
  } catch (error) {
    console.error('Failed to delete:', error)
    alert('Failed to delete post: ' + error.message)
  } finally {
    saving.value = false
  }
}

// Toast notification
const showToast = (message) => {
  const toast = document.createElement('div')
  toast.className = 'toast'
  toast.textContent = message
  document.body.appendChild(toast)
  
  setTimeout(() => toast.classList.add('show'), 10)
  setTimeout(() => {
    toast.classList.remove('show')
    setTimeout(() => toast.remove(), 300)
  }, 2000)
}

// Load post data
const loadPost = async () => {
  const id = route.params.id
  if (!id) {
    await nextTick()
    initQuill()
    return
  }
  
  loading.value = true
  postId.value = id
  
  try {
    const res = await api.getAdminBlog(id)
    const post = res.post
    
    form.title = post.title
    form.content_delta = post.content_delta
    form.content_html = post.content_html
    form.category = post.category || ''
    form.status = post.status
    
    await nextTick()
    initQuill()
    
  } catch (error) {
    console.error('Failed to load post:', error)
    router.push({ name: 'admin-dashboard' })
  } finally {
    loading.value = false
  }
}

// Load categories
const loadCategories = async () => {
  try {
    const res = await api.getAdminCategories()
    categories.value = res.categories || []
  } catch (error) {
    console.error('Failed to load categories:', error)
  }
}

// Keyboard shortcuts
const handleKeydown = (e) => {
  // Escape to exit fullscreen
  if (e.key === 'Escape' && isFullscreen.value) {
    isFullscreen.value = false
  }
  
  // Ctrl/Cmd + S to save
  if ((e.ctrlKey || e.metaKey) && e.key === 's') {
    e.preventDefault()
    savePost()
  }
}

onMounted(() => {
  loadPost()
  loadCategories()
  document.addEventListener('keydown', handleKeydown)
})

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown)
})
</script>

<style scoped>
.editor-main {
  max-width: 1400px;
  margin: 0 auto;
  padding: 2rem;
}

.editor-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.editor-header h1 {
  font-family: 'Playfair Display', serif;
  font-size: 1.5rem;
}

.header-actions {
  display: flex;
  gap: 0.5rem;
}

.editor-grid {
  display: grid;
  grid-template-columns: 1fr 300px;
  gap: 2rem;
}

.editor-content {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-group {
  margin-bottom: 0;
}

.input-large {
  font-size: 1.25rem;
  padding: 1rem;
}

.editor-wrapper {
  min-height: 500px;
  background: var(--color-bg-secondary);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  overflow: hidden;
}

.editor-wrapper.fullscreen {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 1000;
  border-radius: 0;
  min-height: 100vh;
}

.editor-wrapper :deep(.ql-toolbar) {
  border: none;
  border-bottom: 1px solid var(--color-border);
  background: var(--color-bg);
}

.editor-wrapper :deep(.ql-container) {
  border: none;
  font-size: 1rem;
}

.editor-wrapper :deep(.ql-editor) {
  min-height: 450px;
  padding: 1.5rem;
}

.editor-wrapper.fullscreen :deep(.ql-editor) {
  min-height: calc(100vh - 50px);
}

.editor-wrapper :deep(.ql-fullscreen) {
  width: 28px;
  height: 24px;
  font-size: 16px;
}

.editor-sidebar {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.sidebar-card {
  background: var(--color-bg-secondary);
  padding: 1.5rem;
  border-radius: 12px;
  border: 1px solid var(--color-border);
}

.sidebar-card h3 {
  font-size: 0.9rem;
  font-weight: 600;
  margin-bottom: 1rem;
  color: var(--color-text-light);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.action-buttons {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.danger-zone {
  border-color: var(--color-danger);
}

.danger-zone h3 {
  color: var(--color-danger);
}

.btn-block {
  width: 100%;
}

.loading-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(255, 255, 255, 0.9);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1001;
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

/* Toast notification */
:global(.toast) {
  position: fixed;
  bottom: 2rem;
  right: 2rem;
  background: #1a1a1a;
  color: white;
  padding: 1rem 1.5rem;
  border-radius: 8px;
  opacity: 0;
  transform: translateY(10px);
  transition: all 0.3s ease;
  z-index: 2000;
}

:global(.toast.show) {
  opacity: 1;
  transform: translateY(0);
}

@media (max-width: 1024px) {
  .editor-grid {
    grid-template-columns: 1fr;
  }
  
  .editor-sidebar {
    order: -1;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  }
}

@media (max-width: 768px) {
  .editor-header {
    flex-direction: column;
    gap: 1rem;
    align-items: flex-start;
  }
  
  .editor-sidebar {
    grid-template-columns: 1fr;
  }
}
</style>
