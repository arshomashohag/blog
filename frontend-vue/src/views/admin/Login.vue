<template>
  <div class="login-page">
    <div class="login-container">
      <div class="login-card">
        <h1 class="login-title">✦ Blog Admin</h1>
        <p class="login-subtitle">Enter your admin token to continue</p>
        
        <form @submit.prevent="handleLogin" class="login-form">
          <div class="form-group">
            <label for="token">Admin Token</label>
            <input 
              type="password" 
              id="token" 
              v-model="token"
              required 
              placeholder="Enter admin token"
              :disabled="loading"
              class="input"
            >
          </div>
          
          <p v-if="error" class="error-message">{{ error }}</p>
          
          <button type="submit" class="btn btn-primary btn-block" :disabled="loading">
            {{ loading ? 'Verifying...' : 'Login' }}
          </button>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const token = ref('')
const loading = ref(false)
const error = ref('')

const handleLogin = async () => {
  if (!token.value.trim()) return
  
  loading.value = true
  error.value = ''
  
  try {
    const success = await authStore.login(token.value.trim())
    if (success) {
      router.push({ name: 'admin-dashboard' })
    } else {
      error.value = 'Invalid admin token'
    }
  } catch (e) {
    error.value = 'Authentication failed'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg);
  padding: 2rem;
}

.login-container {
  width: 100%;
  max-width: 400px;
}

.login-card {
  background: var(--color-bg-secondary);
  padding: 3rem;
  border-radius: 16px;
  border: 1px solid var(--color-border);
  text-align: center;
}

.login-title {
  font-family: 'Playfair Display', serif;
  font-size: 2rem;
  margin-bottom: 0.5rem;
}

.login-subtitle {
  color: var(--color-text-light);
  margin-bottom: 2rem;
}

.login-form {
  text-align: left;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
  color: var(--color-text);
}

.error-message {
  color: var(--color-danger);
  font-size: 0.9rem;
  margin-bottom: 1rem;
  text-align: center;
}

.btn-block {
  width: 100%;
}
</style>
