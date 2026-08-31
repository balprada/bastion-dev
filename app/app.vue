<script setup lang="ts">
// Root shell: layout wraps every page; text-size preference applies once,
// globally (login page included — it skips the layout, not the preference).
const { init } = useTextSize()
onMounted(init)
</script>

<template>
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
</template>
