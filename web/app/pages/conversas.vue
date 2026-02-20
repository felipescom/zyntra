<script setup lang="ts">
import { computed, ref, shallowRef, watch } from 'vue'
import { breakpointsTailwind } from '@vueuse/core'
import ConversationsList from '~/components/conversas/ConversationsList.vue'
import ConversationThread from '~/components/conversas/ConversationThread.vue'
import ConversationDetailsSheet from '~/components/conversas/ConversationDetailsSheet.vue'
import { chatConversations } from '~/utils/chats'
import type { ChatConversation, ChatMessage } from '~/types'

const filterItems = [{
  label: 'All',
  value: 'all'
}, {
  label: 'Unread',
  value: 'unread'
}, {
  label: 'Groups',
  value: 'groups'
}]

type ConversationFilter = 'all' | 'unread' | 'groups'

const selectedFilter = ref<ConversationFilter>('all')
const search = ref('')

const filterMenuItems = computed(() => filterItems.map(item => ({
  label: item.label,
  type: 'checkbox' as const,
  checked: selectedFilter.value === item.value,
  onSelect(event?: Event) {
    event?.preventDefault()
    selectedFilter.value = item.value as ConversationFilter
  }
})))

const conversations = shallowRef<ChatConversation[]>(structuredClone(chatConversations))
const selectedConversationId = ref<number | null>(null)

function getConversationById(id: number | null) {
  if (id === null) {
    return null
  }

  for (const conversation of conversations.value) {
    if (conversation.id === id) {
      return conversation
    }
  }

  return null
}

function updateConversation(id: number, updater: (conversation: ChatConversation) => ChatConversation) {
  conversations.value = conversations.value.map((conversation) => {
    if (conversation.id !== id) {
      return conversation
    }

    return updater(conversation)
  })
}

function getLastMessageDate(conversation: ChatConversation) {
  const message = conversation.messages[conversation.messages.length - 1]
  return message ? new Date(message.date).getTime() : 0
}

const filteredConversations = computed<ChatConversation[]>(() => {
  const query = search.value.trim().toLowerCase()
  const list: ChatConversation[] = []

  for (const conversation of conversations.value) {
    if (selectedFilter.value === 'unread' && !conversation.unreadCount) {
      continue
    }

    if (selectedFilter.value === 'groups' && !conversation.isGroup) {
      continue
    }

    if (!query) {
      list.push(conversation)
      continue
    }

    const matches = conversation.name.toLowerCase().includes(query)
      || conversation.channel.toLowerCase().includes(query)
      || conversation.messages.some(message => message.text.toLowerCase().includes(query))

    if (matches) {
      list.push(conversation)
    }
  }

  return list.sort((a, b) => getLastMessageDate(b) - getLastMessageDate(a))
})

const selectedConversation = computed<ChatConversation | null>(() => getConversationById(selectedConversationId.value))

watch(filteredConversations, (value) => {
  if (!selectedConversationId.value) {
    return
  }

  const exists = value.some(conversation => conversation.id === selectedConversationId.value)
  if (!exists) {
    selectedConversationId.value = null
  }
})

watch(selectedConversationId, (id) => {
  const conversation = getConversationById(id)
  if (!conversation) {
    isDetailsOpen.value = false
    return
  }

  if (!conversation.unreadCount) {
    return
  }

  updateConversation(conversation.id, item => ({
    ...item,
    unreadCount: 0
  }))
})

const breakpoints = useBreakpoints(breakpointsTailwind)
const isMobile = breakpoints.smaller('lg')
const isDetailsOpen = ref(false)

const isConversationPanelOpen = computed({
  get() {
    return !!selectedConversationId.value
  },
  set(value: boolean) {
    if (!value) {
      selectedConversationId.value = null
      isDetailsOpen.value = false
    }
  }
})

function onToggleDetails() {
  if (!selectedConversation.value) {
    return
  }

  isDetailsOpen.value = !isDetailsOpen.value
}

function onSendMessage(text: string) {
  const selected = getConversationById(selectedConversationId.value)
  if (!selected) {
    return
  }

  const nextId = (selected.messages[selected.messages.length - 1]?.id || 0) + 1
  const message: ChatMessage = {
    id: nextId,
    text,
    fromMe: true,
    date: new Date().toISOString()
  }

  updateConversation(selected.id, item => ({
    ...item,
    messages: [...item.messages, message]
  }))
}
</script>

<template>
  <UDashboardPanel
    id="conversas-1"
    :default-size="25"
    :min-size="22"
    :max-size="32"
    resizable
  >
    <UDashboardNavbar :ui="{ right: 'flex-1 min-w-0 max-w-none lg:max-w-sm' }">
      <template #leading>
        <UDashboardSidebarCollapse />
      </template>

      <template #right>
        <div class="flex w-full min-w-0 items-center gap-2">
          <UInput
            v-model="search"
            class="min-w-0 flex-1"
            icon="i-lucide-search"
            placeholder="Search chats..."
          />

          <UDropdownMenu :items="filterMenuItems" :content="{ align: 'end' }">
            <UButton
              icon="i-lucide-funnel"
              color="neutral"
              variant="ghost"
              aria-label="Filter conversations"
            />
          </UDropdownMenu>
        </div>
      </template>
    </UDashboardNavbar>

    <UDashboardToolbar>
      <template #left>
        <UTabs
          v-model="selectedFilter"
          :items="filterItems"
          :content="false"
          size="xs"
        />
      </template>
    </UDashboardToolbar>

    <ConversationsList v-model="selectedConversationId" :conversations="filteredConversations" />
  </UDashboardPanel>

  <ConversationThread
    v-if="selectedConversation && !isMobile"
    :conversation="selectedConversation"
    :details-open="isDetailsOpen"
    @close="selectedConversationId = null"
    @send="onSendMessage"
    @toggle-details="onToggleDetails"
  />

  <UDashboardPanel
    v-if="selectedConversation && isDetailsOpen && !isMobile"
    id="conversas-3"
    :default-size="24"
    :min-size="20"
    :max-size="32"
    resizable
  >
    <ConversationDetailsSheet
      :conversation="selectedConversation"
      @close="isDetailsOpen = false"
    />
  </UDashboardPanel>

  <div v-if="!selectedConversation && !isMobile" class="hidden lg:flex flex-1 items-center justify-center">
    <div class="text-center text-dimmed">
      <UIcon name="i-lucide-message-circle" class="mx-auto mb-3 size-12" />
      <p class="text-base">
        Select a chat to start messaging
      </p>
    </div>
  </div>

  <ClientOnly>
    <USlideover v-if="isMobile" v-model:open="isConversationPanelOpen">
      <template #content>
        <ConversationThread
          v-if="selectedConversation"
          :conversation="selectedConversation"
          :details-open="isDetailsOpen"
          @close="selectedConversationId = null"
          @send="onSendMessage"
          @toggle-details="onToggleDetails"
        />
      </template>
    </USlideover>

    <USlideover
      v-if="isMobile && selectedConversation"
      v-model:open="isDetailsOpen"
    >
      <template #content>
        <ConversationDetailsSheet
          :conversation="selectedConversation"
          @close="isDetailsOpen = false"
        />
      </template>
    </USlideover>
  </ClientOnly>
</template>
