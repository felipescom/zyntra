import { sub } from 'date-fns'
import type { ChatConversation } from '~/types'

export const chatConversations: ChatConversation[] = [{
  id: 1,
  name: 'Low Ticket Brasil',
  channel: 'Felipe',
  unreadCount: 1,
  avatar: {
    src: 'https://i.pravatar.cc/128?u=chat-1'
  },
  messages: [{
    id: 1,
    text: 'Hi! Is there a way to migrate all my contacts?',
    date: sub(new Date(), { minutes: 15 }).toISOString()
  }, {
    id: 2,
    text: 'Yes, we can help you with that. Do you use CSV exports?',
    date: sub(new Date(), { minutes: 13 }).toISOString(),
    fromMe: true
  }, {
    id: 3,
    text: 'Great, I do. I will send it now.',
    date: sub(new Date(), { minutes: 11 }).toISOString()
  }]
}, {
  id: 2,
  name: 'NodeJS - WhatsApp APIs',
  channel: 'Felipe',
  isGroup: true,
  avatar: {
    src: 'https://i.pravatar.cc/128?u=chat-2'
  },
  messages: [{
    id: 1,
    text: 'Can we deploy this tonight?',
    date: sub(new Date(), { hours: 1, minutes: 7 }).toISOString()
  }, {
    id: 2,
    text: 'We can, but we need to merge the pending PR first.',
    date: sub(new Date(), { hours: 1, minutes: 2 }).toISOString(),
    fromMe: true
  }]
}, {
  id: 3,
  name: 'Tamyres',
  channel: 'Felipe',
  avatar: {
    src: 'https://i.pravatar.cc/128?u=chat-3'
  },
  messages: [{
    id: 1,
    text: 'Good afternoon! Did you receive my file?',
    date: sub(new Date(), { hours: 2, minutes: 18 }).toISOString()
  }]
}, {
  id: 4,
  name: 'Gracy Araujo',
  channel: 'Felipe',
  avatar: {
    src: 'https://i.pravatar.cc/128?u=chat-4'
  },
  messages: [{
    id: 1,
    text: 'Good morning',
    date: sub(new Date(), { hours: 4, minutes: 3 }).toISOString()
  }, {
    id: 2,
    text: 'Good morning! How can I help you today?',
    date: sub(new Date(), { hours: 4, minutes: 1 }).toISOString(),
    fromMe: true
  }]
}, {
  id: 5,
  name: 'Eva Fernandes',
  channel: 'Felipe',
  unreadCount: 3,
  avatar: {
    src: 'https://i.pravatar.cc/128?u=chat-5'
  },
  messages: [{
    id: 1,
    text: 'I have been waiting for 33 days 😅',
    date: sub(new Date(), { days: 1, hours: 2 }).toISOString()
  }]
}, {
  id: 6,
  name: 'Kezia',
  channel: 'Felipe',
  avatar: {
    src: 'https://i.pravatar.cc/128?u=chat-6'
  },
  messages: [{
    id: 1,
    text: 'No messages yet',
    date: sub(new Date(), { days: 2 }).toISOString()
  }]
}]
