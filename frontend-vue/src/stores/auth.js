import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '@/services/api'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('adminToken') || null)
  
  const isAuthenticated = computed(() => !!token.value)
  
  async function login(adminToken) {
    try {
      await api.verifyToken(adminToken)
      token.value = adminToken
      localStorage.setItem('adminToken', adminToken)
      return true
    } catch (error) {
      return false
    }
  }
  
  async function verifyToken() {
    if (!token.value) return false
    try {
      await api.verifyToken()
      return true
    } catch (error) {
      logout()
      return false
    }
  }
  
  function logout() {
    token.value = null
    localStorage.removeItem('adminToken')
  }
  
  return {
    token,
    isAuthenticated,
    login,
    logout,
    verifyToken
  }
})
