<template>
  <div class="admin-layout">
    <nav v-if="authStore.isAuthenticated" class="navbar admin-navbar">
      <div class="nav-container">
        <router-link to="/admin/dashboard" class="logo">✦ Blog Admin</router-link>
        <ul class="nav-links">
          <li><a href="/" target="_blank">View Site</a></li>
          <li><button @click="logout" class="btn-link">Logout</button></li>
        </ul>
      </div>
    </nav>
    
    <main>
      <router-view v-slot="{ Component }">
        <transition name="slide" mode="out-in">
          <component :is="Component" />
        </transition>
      </router-view>
    </main>
  </div>
</template>

<script setup>
import { useAuthStore } from '@/stores/auth'
import { useRouter } from 'vue-router'

const authStore = useAuthStore()
const router = useRouter()

const logout = () => {
  authStore.logout()
  router.push({ name: 'admin-login' })
}
</script>

<style scoped>
.admin-layout {
  min-height: 100vh;
  background: var(--color-bg);
}

.admin-navbar {
  background: var(--color-bg-secondary);
  border-bottom: 1px solid var(--color-border);
}

.slide-enter-active,
.slide-leave-active {
  transition: all 0.2s ease;
}

.slide-enter-from {
  opacity: 0;
  transform: translateX(20px);
}

.slide-leave-to {
  opacity: 0;
  transform: translateX(-20px);
}
</style>
