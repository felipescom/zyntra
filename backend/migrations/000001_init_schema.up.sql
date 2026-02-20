CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

CREATE TABLE workspaces (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(160) NOT NULL,
    slug VARCHAR(120) NOT NULL,
    status SMALLINT NOT NULL DEFAULT 1,
    settings JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX uq_workspaces_slug ON workspaces (slug) WHERE deleted_at IS NULL;

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    password_hash TEXT NOT NULL,
    name VARCHAR(160) NOT NULL,
    avatar_url TEXT,
    is_super_admin BOOLEAN NOT NULL DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX uq_users_email_ci ON users (LOWER(email)) WHERE deleted_at IS NULL;

CREATE TABLE workspace_users (
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role SMALLINT NOT NULL DEFAULT 20,
    availability SMALLINT NOT NULL DEFAULT 0,
    auto_offline BOOLEAN NOT NULL DEFAULT TRUE,
    custom_attributes JSONB NOT NULL DEFAULT '{}'::JSONB,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (workspace_id, user_id),
    CONSTRAINT chk_workspace_users_role CHECK (role IN (10, 20, 30))
);

CREATE INDEX idx_workspace_users_user_id ON workspace_users (user_id);
CREATE INDEX idx_workspace_users_workspace_role ON workspace_users (workspace_id, role);

CREATE TABLE teams (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    allow_auto_assign BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX uq_teams_workspace_name ON teams (workspace_id, LOWER(name)) WHERE deleted_at IS NULL;

CREATE TABLE team_members (
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    team_id BIGINT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (team_id, user_id)
);

CREATE INDEX idx_team_members_workspace_user ON team_members (workspace_id, user_id);

CREATE TABLE integration_accounts (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    provider VARCHAR(64) NOT NULL,
    external_account_id VARCHAR(191),
    name VARCHAR(120),
    status SMALLINT NOT NULL DEFAULT 1,
    auth_config JSONB NOT NULL DEFAULT '{}'::JSONB,
    settings JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_integration_accounts_status CHECK (status IN (0, 1, 2)),
    CONSTRAINT chk_integration_accounts_provider CHECK (provider IN ('whatsapp', 'telegram', 'instagram', 'email', 'custom'))
);

CREATE UNIQUE INDEX uq_integration_accounts_workspace_provider_external
    ON integration_accounts (workspace_id, provider, external_account_id)
    WHERE external_account_id IS NOT NULL AND deleted_at IS NULL;

CREATE INDEX idx_integration_accounts_workspace_provider ON integration_accounts (workspace_id, provider);

CREATE TABLE inboxes (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    integration_account_id BIGINT REFERENCES integration_accounts(id) ON DELETE SET NULL,
    name VARCHAR(160) NOT NULL,
    channel_kind VARCHAR(32) NOT NULL,
    identifier VARCHAR(191),
    status SMALLINT NOT NULL DEFAULT 1,
    settings JSONB NOT NULL DEFAULT '{}'::JSONB,
    auto_assignment_config JSONB NOT NULL DEFAULT '{}'::JSONB,
    working_hours JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_inboxes_status CHECK (status IN (0, 1, 2)),
    CONSTRAINT chk_inboxes_channel_kind CHECK (channel_kind IN ('whatsapp', 'telegram', 'instagram', 'email', 'api'))
);

CREATE INDEX idx_inboxes_workspace_channel ON inboxes (workspace_id, channel_kind);
CREATE UNIQUE INDEX uq_inboxes_workspace_channel_identifier
    ON inboxes (workspace_id, channel_kind, identifier)
    WHERE identifier IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE integration_webhooks (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    integration_account_id BIGINT NOT NULL REFERENCES integration_accounts(id) ON DELETE CASCADE,
    inbox_id BIGINT REFERENCES inboxes(id) ON DELETE CASCADE,
    provider VARCHAR(64) NOT NULL,
    endpoint_url TEXT NOT NULL,
    secret_encrypted TEXT,
    signature_header VARCHAR(120),
    status SMALLINT NOT NULL DEFAULT 1,
    health_status SMALLINT NOT NULL DEFAULT 0,
    last_received_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_integration_webhooks_status CHECK (status IN (0, 1)),
    CONSTRAINT chk_integration_webhooks_health CHECK (health_status IN (0, 1, 2))
);

CREATE INDEX idx_integration_webhooks_workspace_provider ON integration_webhooks (workspace_id, provider);
CREATE INDEX idx_integration_webhooks_inbox ON integration_webhooks (inbox_id);

CREATE TABLE inbox_members (
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    inbox_id BIGINT NOT NULL REFERENCES inboxes(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role SMALLINT NOT NULL DEFAULT 30,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (inbox_id, user_id),
    CONSTRAINT chk_inbox_members_role CHECK (role IN (10, 20, 30))
);

CREATE INDEX idx_inbox_members_workspace_user ON inbox_members (workspace_id, user_id);

CREATE TABLE contacts (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    name VARCHAR(191) NOT NULL DEFAULT '',
    email VARCHAR(255),
    phone VARCHAR(40),
    identifier VARCHAR(191),
    avatar_url TEXT,
    blocked BOOLEAN NOT NULL DEFAULT FALSE,
    additional_attributes JSONB NOT NULL DEFAULT '{}'::JSONB,
    custom_attributes JSONB NOT NULL DEFAULT '{}'::JSONB,
    last_activity_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_contacts_workspace_last_activity ON contacts (workspace_id, last_activity_at DESC NULLS LAST);
CREATE INDEX idx_contacts_workspace_name_trgm ON contacts USING GIN (name gin_trgm_ops);
CREATE UNIQUE INDEX uq_contacts_workspace_email ON contacts (workspace_id, LOWER(email))
    WHERE email IS NOT NULL AND email <> '' AND deleted_at IS NULL;
CREATE UNIQUE INDEX uq_contacts_workspace_phone ON contacts (workspace_id, phone)
    WHERE phone IS NOT NULL AND phone <> '' AND deleted_at IS NULL;
CREATE UNIQUE INDEX uq_contacts_workspace_identifier ON contacts (workspace_id, identifier)
    WHERE identifier IS NOT NULL AND identifier <> '' AND deleted_at IS NULL;

CREATE TABLE contact_identities (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    contact_id BIGINT NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    inbox_id BIGINT NOT NULL REFERENCES inboxes(id) ON DELETE CASCADE,
    provider VARCHAR(64) NOT NULL,
    external_id VARCHAR(191) NOT NULL,
    handle VARCHAR(191),
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_contact_identities_provider CHECK (provider IN ('whatsapp', 'telegram', 'instagram', 'email', 'custom'))
);

CREATE UNIQUE INDEX uq_contact_identities_inbox_external ON contact_identities (inbox_id, external_id);
CREATE INDEX idx_contact_identities_workspace_contact ON contact_identities (workspace_id, contact_id);

CREATE TABLE workspace_sequences (
    workspace_id BIGINT PRIMARY KEY REFERENCES workspaces(id) ON DELETE CASCADE,
    conversation_display_seq BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE conversations (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    inbox_id BIGINT NOT NULL REFERENCES inboxes(id) ON DELETE CASCADE,
    contact_id BIGINT NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    contact_identity_id BIGINT REFERENCES contact_identities(id) ON DELETE SET NULL,
    display_id BIGINT NOT NULL,
    status SMALLINT NOT NULL DEFAULT 0,
    priority SMALLINT,
    assignee_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    assignee_team_id BIGINT REFERENCES teams(id) ON DELETE SET NULL,
    subject TEXT,
    additional_attributes JSONB NOT NULL DEFAULT '{}'::JSONB,
    custom_attributes JSONB NOT NULL DEFAULT '{}'::JSONB,
    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    first_reply_at TIMESTAMPTZ,
    waiting_since TIMESTAMPTZ,
    snoozed_until TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    contact_last_seen_at TIMESTAMPTZ,
    agent_last_seen_at TIMESTAMPTZ,
    assignee_last_seen_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_conversations_status CHECK (status IN (0, 1, 2, 3)),
    CONSTRAINT chk_conversations_priority CHECK (priority IS NULL OR priority IN (1, 2, 3))
);

CREATE UNIQUE INDEX uq_conversations_workspace_display_id ON conversations (workspace_id, display_id);
CREATE INDEX idx_conversations_list ON conversations (workspace_id, inbox_id, status, assignee_user_id, last_activity_at DESC);
CREATE INDEX idx_conversations_workspace_status_priority ON conversations (workspace_id, status, priority);

CREATE TABLE conversation_participants (
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX idx_conversation_participants_workspace_user ON conversation_participants (workspace_id, user_id);

CREATE TABLE conversation_assignments (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    assigned_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    assigned_team_id BIGINT REFERENCES teams(id) ON DELETE SET NULL,
    assigned_by_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_conversation_assignments_conversation_created ON conversation_assignments (conversation_id, created_at DESC);

CREATE TABLE messages (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    inbox_id BIGINT NOT NULL REFERENCES inboxes(id) ON DELETE CASCADE,
    conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    direction SMALLINT NOT NULL,
    message_type SMALLINT NOT NULL,
    status SMALLINT NOT NULL DEFAULT 0,
    private BOOLEAN NOT NULL DEFAULT FALSE,
    body TEXT,
    source_id TEXT,
    sender_type SMALLINT,
    sender_id BIGINT,
    content_attributes JSONB NOT NULL DEFAULT '{}'::JSONB,
    external_source_ids JSONB NOT NULL DEFAULT '{}'::JSONB,
    additional_attributes JSONB NOT NULL DEFAULT '{}'::JSONB,
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_messages_direction CHECK (direction IN (0, 1, 2)),
    CONSTRAINT chk_messages_message_type CHECK (message_type IN (0, 1, 2, 3)),
    CONSTRAINT chk_messages_status CHECK (status IN (0, 1, 2, 3, 4))
);

CREATE INDEX idx_messages_conversation_created ON messages (conversation_id, created_at);
CREATE INDEX idx_messages_workspace_inbox_created ON messages (workspace_id, inbox_id, created_at);
CREATE INDEX idx_messages_workspace_status_created ON messages (workspace_id, status, created_at);
CREATE UNIQUE INDEX uq_messages_idempotency_source
    ON messages (workspace_id, inbox_id, source_id)
    WHERE source_id IS NOT NULL AND source_id <> '';
CREATE INDEX idx_messages_body_trgm ON messages USING GIN (body gin_trgm_ops);

CREATE TABLE message_attachments (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    message_id BIGINT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    content_type VARCHAR(120),
    byte_size BIGINT,
    storage_provider VARCHAR(32),
    storage_key TEXT,
    external_url TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_message_attachments_message ON message_attachments (message_id);

CREATE TABLE conversation_labels (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    title VARCHAR(120) NOT NULL,
    description TEXT,
    color_token VARCHAR(64),
    show_on_sidebar BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX uq_conversation_labels_workspace_title
    ON conversation_labels (workspace_id, LOWER(title))
    WHERE deleted_at IS NULL;

CREATE TABLE conversation_label_links (
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    label_id BIGINT NOT NULL REFERENCES conversation_labels(id) ON DELETE CASCADE,
    conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (label_id, conversation_id)
);

CREATE INDEX idx_conversation_label_links_workspace_conversation
    ON conversation_label_links (workspace_id, conversation_id);

CREATE TABLE tags (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX uq_tags_workspace_name
    ON tags (workspace_id, LOWER(name))
    WHERE deleted_at IS NULL;

CREATE TABLE taggings (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    tag_id BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    resource_type VARCHAR(64) NOT NULL,
    resource_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX uq_taggings_resource ON taggings (tag_id, resource_type, resource_id);
CREATE INDEX idx_taggings_workspace_resource ON taggings (workspace_id, resource_type, resource_id);

CREATE TABLE conversation_notes (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    author_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_conversation_notes_conversation_created ON conversation_notes (conversation_id, created_at);

CREATE TABLE conversation_events (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    event_type VARCHAR(80) NOT NULL,
    actor_type SMALLINT,
    actor_id BIGINT,
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_conversation_events_conversation_created ON conversation_events (conversation_id, created_at DESC);
CREATE INDEX idx_conversation_events_workspace_event ON conversation_events (workspace_id, event_type, created_at DESC);

CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    actor_type SMALLINT,
    actor_id BIGINT,
    entity_type VARCHAR(80) NOT NULL,
    entity_id BIGINT,
    action VARCHAR(80) NOT NULL,
    changes JSONB NOT NULL DEFAULT '{}'::JSONB,
    request_id UUID,
    ip INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_workspace_created ON audit_logs (workspace_id, created_at DESC);
CREATE INDEX idx_audit_logs_entity ON audit_logs (workspace_id, entity_type, entity_id, created_at DESC);

CREATE TABLE webhook_deliveries (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    integration_webhook_id BIGINT NOT NULL REFERENCES integration_webhooks(id) ON DELETE CASCADE,
    event_name VARCHAR(120) NOT NULL,
    request_payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    response_status INTEGER,
    response_body TEXT,
    attempt SMALLINT NOT NULL DEFAULT 1,
    latency_ms INTEGER,
    delivered_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhook_deliveries_webhook_created ON webhook_deliveries (integration_webhook_id, created_at DESC);
CREATE INDEX idx_webhook_deliveries_workspace_retry ON webhook_deliveries (workspace_id, next_retry_at);

CREATE TABLE event_outbox (
    id BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    aggregate_type VARCHAR(80) NOT NULL,
    aggregate_id BIGINT,
    event_name VARCHAR(120) NOT NULL,
    event_version SMALLINT NOT NULL DEFAULT 1,
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    headers JSONB NOT NULL DEFAULT '{}'::JSONB,
    status SMALLINT NOT NULL DEFAULT 0,
    available_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at TIMESTAMPTZ,
    fail_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_event_outbox_status CHECK (status IN (0, 1, 2))
);

CREATE INDEX idx_event_outbox_pending ON event_outbox (status, available_at, id);
CREATE INDEX idx_event_outbox_workspace_event ON event_outbox (workspace_id, event_name, created_at DESC);

CREATE OR REPLACE FUNCTION set_conversation_display_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.display_id IS NULL OR NEW.display_id = 0 THEN
        INSERT INTO workspace_sequences (workspace_id, conversation_display_seq)
        VALUES (NEW.workspace_id, 1)
        ON CONFLICT (workspace_id)
        DO UPDATE SET
            conversation_display_seq = workspace_sequences.conversation_display_seq + 1,
            updated_at = NOW()
        RETURNING conversation_display_seq INTO NEW.display_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER conversations_set_display_id
BEFORE INSERT ON conversations
FOR EACH ROW
EXECUTE FUNCTION set_conversation_display_id();
