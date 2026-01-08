import { createRouter, createWebHashHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

// Layouts
import PublicLayout from '@/layouts/PublicLayout.vue'
import AdminLayout from '@/layouts/AdminLayout.vue'

// Public pages
import Home from '@/views/public/Home.vue'
import Blogs from '@/views/public/Blogs.vue'
import BlogPost from '@/views/public/BlogPost.vue'

// Admin pages
import Login from '@/views/admin/Login.vue'
import Dashboard from '@/views/admin/Dashboard.vue'
import Editor from '@/views/admin/Editor.vue'

const routes = [
  {
    path: '/',
    component: PublicLayout,
    children: [
      { path: '', name: 'home', component: Home },
      { path: 'blogs', name: 'blogs', component: Blogs },
      { path: 'blog/:slug', name: 'blog', component: BlogPost }
    ]
  },
  {
    path: '/admin',
    component: AdminLayout,
    children: [
      { path: '', name: 'admin-login', component: Login },
      { 
        path: 'dashboard', 
        name: 'admin-dashboard', 
        component: Dashboard,
        meta: { requiresAuth: true }
      },
      { 
        path: 'editor', 
        name: 'admin-editor-new', 
        component: Editor,
        meta: { requiresAuth: true }
      },
      { 
        path: 'editor/:id', 
        name: 'admin-editor', 
        component: Editor,
        meta: { requiresAuth: true }
      }
    ]
  }
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) return savedPosition
    return { top: 0 }
  }
})

// Navigation guard for admin routes
router.beforeEach((to, from, next) => {
  const authStore = useAuthStore()
  
  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    next({ name: 'admin-login' })
  } else if (to.name === 'admin-login' && authStore.isAuthenticated) {
    next({ name: 'admin-dashboard' })
  } else {
    next()
  }
})

export default router
