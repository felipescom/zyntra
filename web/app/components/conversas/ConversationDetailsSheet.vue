<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { ChatConversation } from '~/types'

const props = defineProps<{
  conversation: ChatConversation
}>()

const emits = defineEmits<{
  close: []
}>()

const assignedAgent = ref('')
const assignedTeam = ref('none')
const priority = ref('none')
const openSection = ref('actions')

const sectionItems = [{
  label: 'Contato',
  value: 'contact',
  slot: 'contact'
}, {
  label: 'Ações da conversa',
  value: 'actions',
  slot: 'actions'
}, {
  label: 'Agente atribuído',
  value: 'agent',
  slot: 'agent'
}, {
  label: 'Time atribuído',
  value: 'team',
  slot: 'team'
}, {
  label: 'Prioridade',
  value: 'priority',
  slot: 'priority'
}, {
  label: 'Etiquetas da conversa',
  value: 'tags',
  slot: 'tags'
}, {
  label: 'Macros',
  value: 'macros',
  slot: 'macros'
}, {
  label: 'Informação da conversa',
  value: 'conversationInfo',
  slot: 'conversation-info'
}, {
  label: 'Atributos do contato',
  value: 'contactAttributes',
  slot: 'contact-attributes'
}, {
  label: 'Notas do contato',
  value: 'contactNotes',
  slot: 'contact-notes'
}, {
  label: 'Conversas anteriores',
  value: 'previousConversations',
  slot: 'previous-conversations'
}]

const assignedAgentItems = computed(() => [{
  label: props.conversation.channel,
  value: props.conversation.channel
}, {
  label: 'Equipe Comercial',
  value: 'equipe-comercial'
}, {
  label: 'Sem agente',
  value: 'none'
}])

const teamItems = [{
  label: 'Nenhum',
  value: 'none'
}, {
  label: 'Suporte',
  value: 'suporte'
}, {
  label: 'Comercial',
  value: 'comercial'
}]

const priorityItems = [{
  label: 'Nenhuma',
  value: 'none'
}, {
  label: 'Baixa',
  value: 'low'
}, {
  label: 'Média',
  value: 'medium'
}, {
  label: 'Alta',
  value: 'high'
}]

const contactEmail = computed(() => {
  const normalized = props.conversation.name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '.')
    .replace(/(^\.|\.$)/g, '')

  return `${normalized || 'contato'}@example.com`
})

const tags = computed(() => {
  const values = ['WhatsApp']

  if (props.conversation.isGroup) {
    values.push('Grupo')
  }

  if (props.conversation.unreadCount) {
    values.push('Não lido')
  }

  return values
})

watch(() => props.conversation.id, () => {
  assignedAgent.value = props.conversation.channel
  assignedTeam.value = 'none'
  priority.value = 'none'
  openSection.value = 'actions'
}, { immediate: true })
</script>

<template>
  <div class="flex h-full min-h-0 flex-col bg-default">
    <UDashboardNavbar title="Detalhes da conversa" :toggle="false">
      <template #right>
        <UButton
          icon="i-lucide-x"
          color="neutral"
          variant="ghost"
          @click="emits('close')"
        />
      </template>
    </UDashboardNavbar>

    <div class="flex-1 overflow-y-auto p-4 sm:p-5">
      <UAccordion
        v-model="openSection"
        :items="sectionItems"
        type="single"
        :collapsible="false"
        :unmount-on-hide="false"
      >
        <template #contact-body>
          <div class="rounded-lg border border-default p-3">
            <div class="flex items-start gap-3">
              <UAvatar
                v-bind="conversation.avatar"
                :alt="conversation.name"
                size="lg"
              />

              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-semibold text-highlighted">
                  {{ conversation.name }}
                </p>
                <p class="truncate text-xs text-muted">
                  @{{ conversation.channel }}
                </p>
              </div>
            </div>

            <div class="mt-3 space-y-2 text-sm">
              <p class="text-toned">
                +55 11 98888-0000
              </p>
              <p class="truncate text-toned">
                {{ contactEmail }}
              </p>
            </div>
          </div>
        </template>

        <template #actions-body>
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <p class="text-sm font-medium text-highlighted">
                Ações rápidas
              </p>

              <UButton
                icon="i-lucide-plus"
                color="neutral"
                variant="ghost"
                size="xs"
              />
            </div>

            <p class="text-sm text-muted">
              Nenhuma ação configurada.
            </p>
          </div>
        </template>

        <template #agent-body>
          <USelect v-model="assignedAgent" :items="assignedAgentItems" class="w-full" />
        </template>

        <template #team-body>
          <USelect v-model="assignedTeam" :items="teamItems" class="w-full" />
        </template>

        <template #priority-body>
          <USelect v-model="priority" :items="priorityItems" class="w-full" />
        </template>

        <template #tags-body>
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <p class="text-sm font-medium text-highlighted">
                Etiquetas ativas
              </p>

              <UButton
                icon="i-lucide-plus"
                color="neutral"
                variant="ghost"
                size="xs"
              />
            </div>

            <div class="flex flex-wrap gap-1.5">
              <UBadge
                v-for="tag in tags"
                :key="tag"
                :label="tag"
                color="neutral"
                variant="subtle"
              />
            </div>
          </div>
        </template>

        <template #macros-body>
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <p class="text-sm font-medium text-highlighted">
                Macros disponíveis
              </p>

              <UButton
                icon="i-lucide-plus"
                color="neutral"
                variant="ghost"
                size="xs"
              />
            </div>

            <p class="text-sm text-muted">
              Nenhuma macro disponível.
            </p>
          </div>
        </template>

        <template #conversation-info-body>
          <p class="text-sm text-muted">
            Canal: WhatsApp · Última interação: agora
          </p>
        </template>

        <template #contact-attributes-body>
          <p class="text-sm text-muted">
            Sem atributos adicionais no momento.
          </p>
        </template>

        <template #contact-notes-body>
          <p class="text-sm text-muted">
            Nenhuma nota adicionada.
          </p>
        </template>

        <template #previous-conversations-body>
          <p class="text-sm text-muted">
            Nenhuma conversa anterior encontrada.
          </p>
        </template>
      </UAccordion>
    </div>
  </div>
</template>
