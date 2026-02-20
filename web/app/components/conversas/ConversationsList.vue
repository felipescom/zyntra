<script setup lang="ts">
import { format, isToday } from 'date-fns'
import type { ChatConversation } from '~/types'

const props = defineProps<{
  conversations: ChatConversation[]
}>()

const selectedConversationId = defineModel<number | null>()

const conversationRefs = ref<Record<number, Element | null>>({})

function getLastMessage(conversation: ChatConversation) {
  return conversation.messages[conversation.messages.length - 1]
}

watch(selectedConversationId, () => {
  if (!selectedConversationId.value) {
    return
  }

  const ref = conversationRefs.value[selectedConversationId.value]
  if (ref) {
    ref.scrollIntoView({ block: 'nearest' })
  }
})

defineShortcuts({
  arrowdown: () => {
    const index = props.conversations.findIndex(conversation => conversation.id === selectedConversationId.value)

    if (index === -1) {
      selectedConversationId.value = props.conversations[0]?.id ?? null
    } else if (index < props.conversations.length - 1) {
      const nextConversation = props.conversations[index + 1]
      if (nextConversation) {
        selectedConversationId.value = nextConversation.id
      }
    }
  },
  arrowup: () => {
    const index = props.conversations.findIndex(conversation => conversation.id === selectedConversationId.value)

    if (index === -1) {
      selectedConversationId.value = props.conversations[props.conversations.length - 1]?.id ?? null
    } else if (index > 0) {
      const previousConversation = props.conversations[index - 1]
      if (previousConversation) {
        selectedConversationId.value = previousConversation.id
      }
    }
  }
})
</script>

<template>
  <div class="overflow-y-auto divide-y divide-default">
    <button
      v-for="conversation in conversations"
      :key="conversation.id"
      :ref="(el) => { conversationRefs[conversation.id] = el as Element | null }"
      type="button"
      class="w-full p-4 sm:px-6 text-left border-l-2 transition-colors"
      :class="selectedConversationId === conversation.id
        ? 'border-primary bg-primary/10'
        : 'border-bg hover:border-primary hover:bg-primary/5'"
      @click="selectedConversationId = conversation.id"
    >
      <div class="flex items-start gap-3">
        <UAvatar v-bind="conversation.avatar" :alt="conversation.name" />

        <div class="min-w-0 flex-1">
          <div class="flex items-center justify-between gap-2">
            <p class="truncate text-sm font-medium text-highlighted">
              {{ conversation.name }}
            </p>

            <span class="shrink-0 text-xs text-muted">
              {{ isToday(new Date(getLastMessage(conversation)?.date || Date.now()))
                ? format(new Date(getLastMessage(conversation)?.date || Date.now()), 'HH:mm')
                : format(new Date(getLastMessage(conversation)?.date || Date.now()), 'dd MMM') }}
            </span>
          </div>

          <div class="mt-1 flex items-center justify-between gap-2">
            <p class="truncate text-xs text-dimmed">
              {{ conversation.channel }} · {{ getLastMessage(conversation)?.text || 'No messages yet' }}
            </p>

            <div class="flex items-center gap-1">
              <UBadge
                v-if="conversation.isGroup"
                size="xs"
                color="neutral"
                variant="subtle"
                label="Group"
              />
              <UBadge
                v-if="conversation.unreadCount"
                size="xs"
                color="primary"
                variant="solid"
                :label="String(conversation.unreadCount)"
              />
            </div>
          </div>
        </div>
      </div>
    </button>
  </div>
</template>
