// app/middleware/auth.global.ts
//
// Global route guard. Runs on every navigation, plus once on initial load.
// Public routes: /login and /about. Everything else requires a session.
//
// The first await matters: on a hard refresh the persisted session lives in
// localStorage and must be restored before any route decision. init() is
// idempotent — every navigation after the first reuses the resolved promise,
// so this costs ~0ms after startup.
export default defineNuxtRouteMiddleware(async (to) => {
  const { user, ready, init } = useSession()

  if (!ready.value) {
    await init()
  }

  const isPublic = to.path === '/login' || to.path === '/about'

  // Signed out on a protected route → login. replace: no back-button trap.
  if (!user.value && !isPublic) {
    return navigateTo('/login', { replace: true })
  }

  // Signed in but visiting /login → straight to the dashboard.
  if (user.value && to.path === '/login') {
    return navigateTo('/', { replace: true })
  }
})
