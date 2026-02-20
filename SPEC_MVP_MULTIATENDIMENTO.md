# Spec Técnica — Plataforma Multiatendimento (v0.1)

**Projeto:** zyntra  
**Data:** 2026-02-20  
**Status:** rascunho inicial (living document)

## 1. Objetivo

Construir uma plataforma de multiatendimento inspirada em Chatwoot, com foco em inbox unificada, operação de times e atualização em tempo real, usando:

- Backend em Go
- PostgreSQL como fonte de verdade
- Frontend em Nuxt 3 (Vue)
- Realtime via WebSocket
- Eventos assíncronos com NATS JetStream
- Redis para cache/presença/rate limit

## 2. Escopo do MVP

### 2.1 Incluído

- Multi-tenant por workspace
- Usuários, times e papéis (admin, supervisor, agente)
- Inbox unificada com conversas e mensagens
- Atribuição manual/automática de conversas
- Notas internas e tags
- Mensagens em tempo real no frontend
- Camada de conectores pronta para WhatsApp, Telegram e Instagram (integração real pode ser gradual)

### 2.2 Fora do MVP (fase posterior)

- Chatbot avançado/IA generativa
- BI avançado e relatórios complexos
- Omnichannel com voz
- SLA inteligente com automações complexas

## 3. Decisões de arquitetura

1. **Monorepo na raiz**, sem pasta `apps/`.
2. **Monólito modular em Go** no início (escala para microserviços quando necessário).
3. **NATS + Redis juntos**:
   - NATS JetStream: eventos/filas duráveis entre serviços
   - Redis: presença, cache e rate limiting
4. **Frontend não acessa NATS diretamente**; browser conversa com backend via HTTP + WebSocket.

## 4. Estrutura de pastas proposta

```txt
zyntra/
├─ backend/
│  ├─ cmd/
│  │  ├─ api/
│  │  ├─ realtime/
│  │  └─ worker/
│  ├─ internal/
│  │  ├─ modules/
│  │  │  ├─ auth/
│  │  │  ├─ workspaces/
│  │  │  ├─ users/
│  │  │  ├─ teams/
│  │  │  ├─ inboxes/
│  │  │  ├─ contacts/
│  │  │  ├─ conversations/
│  │  │  ├─ messages/
│  │  │  └─ integrations/
│  │  └─ platform/
│  │     ├─ postgres/
│  │     ├─ redis/
│  │     ├─ nats/
│  │     └─ websocket/
│  ├─ migrations/
│  ├─ pkg/
│  └─ go.mod
├─ web/
│  ├─ pages/
│  ├─ components/
│  ├─ stores/
│  ├─ composables/
│  ├─ services/
│  └─ plugins/
├─ packages/
│  └─ contracts/
└─ infra/
   ├─ docker/
   ├─ compose/
   └─ k8s/
```

## 5. Modelo de domínio inicial

Entidades principais:

- `workspaces`
- `users`
- `workspace_users` (papéis)
- `teams`
- `team_members`
- `inboxes`
- `contacts`
- `conversations`
- `conversation_participants`
- `messages`
- `message_attachments`
- `conversation_assignments`
- `integration_accounts`
- `integration_webhooks`
- `audit_logs`

Regras-chave:

- Toda entidade de negócio vinculada a `workspace_id`.
- Índices compostos por tenant (ex.: `workspace_id + created_at`).
- Soft delete para registros sensíveis de operação.

## 6. Fluxos críticos

## 6.1 Mensagem recebida (inbound)

1. Canal externo envia webhook para `backend/cmd/api`.
2. Backend valida assinatura e normaliza payload.
3. Upsert de contato + conversa + mensagem no PostgreSQL.
4. Publica evento `message.received` no NATS.
5. Serviço realtime consome evento e envia por WebSocket para agentes do workspace.
6. Frontend atualiza thread instantaneamente.

## 6.2 Mensagem enviada (outbound)

1. Agente envia mensagem no frontend.
2. API grava mensagem como `pending`.
3. Worker publica no canal externo.
4. Resultado atualiza status (`sent`, `delivered`, `failed`).
5. Evento de status retorna via WebSocket.

## 7. Realtime (estilo WhatsApp Web)

- Um gateway WebSocket dedicado (`cmd/realtime`).
- Autenticação por token de sessão JWT.
- Canais lógicos por workspace e por conversa:
  - `workspace:{id}`
  - `conversation:{id}`
- Eventos mínimos:
  - `conversation.created`
  - `message.received`
  - `message.sent`
  - `message.status.updated`
  - `conversation.assigned`
  - `typing.updated` (opcional no MVP)

## 8. Estratégia NATS + Redis

## 8.1 NATS JetStream

Uso recomendado:

- Filas duráveis para integrações
- Retry com backoff
- DLQ para falhas permanentes
- Eventos de domínio entre `api`, `worker` e `realtime`

Subjects sugeridos:

- `integration.inbound.*`
- `message.received`
- `message.outbound.requested`
- `message.outbound.status`
- `conversation.assignment.*`

## 8.2 Redis

Uso recomendado:

- Presença online/offline de agentes
- Indicador de digitação
- Rate limiting de API
- Cache de consultas quentes (com TTL curto)

## 9. Contratos de API (MVP)

Endpoints iniciais:

- `POST /v1/auth/login`
- `GET /v1/me`
- `GET /v1/inboxes`
- `GET /v1/conversations?inbox_id=&status=&assignee_id=`
- `POST /v1/conversations/{id}/assign`
- `GET /v1/conversations/{id}/messages`
- `POST /v1/conversations/{id}/messages`
- `POST /v1/webhooks/{provider}/{inbox_id}`

## 10. Segurança e governança

- Multi-tenant por isolamento lógico (`workspace_id`) + validação no service layer
- Assinatura/verificação de webhooks por provedor
- Criptografia em trânsito (TLS) e segredos fora do código
- Auditoria de ações críticas (atribuição, mudança de papel, exclusões)
- Política de retenção de mensagens e anexos alinhada a LGPD

## 11. Observabilidade

- Logs estruturados com `trace_id` e `workspace_id`
- Métricas de filas, latência API, latência de entrega realtime
- Tracing distribuído (OpenTelemetry)
- Alertas para falha de webhook, acúmulo de fila e queda de socket

## 12. Roadmap sugerido

## Fase 1 — Fundação

- Estrutura de pastas
- Autenticação + RBAC
- Base de dados e migrações iniciais

## Fase 2 — Core de atendimento

- Inboxes, contatos, conversas e mensagens
- UI de lista + thread
- Atribuição de conversa

## Fase 3 — Realtime

- Gateway WebSocket
- Eventos de mensagem e atribuição em tempo real

## Fase 4 — Integrações

- Contrato de conector
- Primeiro provedor (WhatsApp)
- Telegram/Instagram na sequência

## Fase 5 — Operação

- Observabilidade
- Hardening de segurança
- Testes de carga e readiness para produção

## 13. Decisões em aberto

- Estratégia exata de auto-assign (round robin, por carga, por skill)
- Política de retenção de mídia/anexos
- SLA operacional por tipo de inbox
- Regras de fallback quando provedor externo estiver indisponível

## 14. Próximos passos imediatos

1. Criar schema inicial SQL (v1).
2. Definir contratos de eventos (NATS subjects + payloads).
3. Definir contrato WebSocket (tipos de eventos e versionamento).
4. Especificar primeiro conector (WhatsApp Cloud API).
5. Montar backlog de implementação por sprint.
