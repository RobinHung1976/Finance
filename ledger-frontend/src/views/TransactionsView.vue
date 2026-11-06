<script setup lang="ts">
import TransactionList from '@/components/TransactionList.vue'
</script>

<template>
  <section class="panel">
    <div class="panel-body">
      <TransactionList :refresh-key="0" />
    </div>
  </section>
</template>
