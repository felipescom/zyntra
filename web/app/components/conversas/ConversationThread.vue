<script setup lang="ts">
import type { ChatConversation } from '~/types'

const props = withDefaults(defineProps<{
  conversation: ChatConversation
  detailsOpen?: boolean
}>(), {
  detailsOpen: false
})

const emits = defineEmits<{
  close: []
  send: [text: string]
  toggleDetails: []
}>()

const text = ref('')
const bodyRef = ref<HTMLElement | null>(null)

function scrollToBottom() {
  if (!bodyRef.value) {
    return
  }

  bodyRef.value.scrollTop = bodyRef.value.scrollHeight
}

watch(() => props.conversation.id, async () => {
  await nextTick()
  scrollToBottom()
}, { immediate: true })

watch(() => props.conversation.messages.length, async () => {
  await nextTick()
  scrollToBottom()
})

function onSubmit() {
  const value = text.value.trim()
  if (!value) {
    return
  }

  emits('send', value)
  text.value = ''
}
</script>

<template>
  <UDashboardPanel id="conversas-2">
    <UDashboardNavbar :title="conversation.name" :toggle="false">
      <template #leading>
        <UButton
          icon="i-lucide-arrow-left"
          color="neutral"
          variant="ghost"
          class="lg:hidden"
          @click="emits('close')"
        />

        <UAvatar
          v-bind="conversation.avatar"
          :alt="conversation.name"
          size="sm"
          class="shrink-0"
        />
      </template>

      <template #right>
        <UTooltip text="Call">
          <UButton icon="i-lucide-phone" color="neutral" variant="ghost" />
        </UTooltip>

        <UTooltip text="Video call">
          <UButton icon="i-lucide-video" color="neutral" variant="ghost" />
        </UTooltip>

        <UButton icon="i-lucide-ellipsis-vertical" color="neutral" variant="ghost" />
      </template>
    </UDashboardNavbar>

    <UButton
      v-if="!props.detailsOpen"
      icon="i-lucide-user-round"
      color="neutral"
      variant="soft"
      class="absolute right-1 top-[calc(var(--ui-header-height)+0.5rem)] z-20 rounded-full shadow-sm ring-1 ring-default"
      aria-label="Abrir detalhes da conversa"
      @click="emits('toggleDetails')"
    />

    <div
      ref="bodyRef"
      class="relative flex-1 overflow-y-auto p-4 sm:p-6"
    >
      <div class="absolute inset-0 opacity-30 [background-image:radial-gradient(rgba(120,120,120,0.15)_1px,transparent_1px)] [background-size:22px_22px]" />

      <div class="relative flex flex-col gap-3">
        <div
          v-for="message in conversation.messages"
          :key="message.id"
          class="flex"
          :class="message.fromMe ? 'justify-end' : 'justify-start'"
        >
          <div
            class="max-w-[85%] rounded-2xl px-3 py-2 text-sm border"
            :class="message.fromMe
              ? 'bg-primary/15 border-primary/30 text-highlighted rounded-br-sm'
              : 'bg-elevated border-default text-toned rounded-bl-sm'"
          >
            <p class="whitespace-pre-wrap break-words">
              {{ message.text }}
            </p>
            <p class="mt-1 text-[11px] text-muted">
              {{ new Date(message.date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }}
            </p>
          </div>
        </div>
      </div>
    </div>

    <form class="border-t border-default p-3 sm:p-4 bg-default" @submit.prevent="onSubmit">
      <div class="flex items-center gap-2">
        <UButton
          type="button"
          icon="i-lucide-paperclip"
          color="neutral"
          variant="ghost"
          square
        />

        <UInput
          v-model="text"
          class="flex-1"
          color="neutral"
          variant="subtle"
          placeholder="Type a message..."
          autocomplete="off"
        />

        <UButton
          type="submit"
          icon="i-lucide-send"
          color="primary"
          variant="soft"
          square
        />
      </div>
    </form>
  </UDashboardPanel>
</template>
