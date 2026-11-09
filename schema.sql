PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS businesses (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  opening_hours TEXT DEFAULT '',
  address TEXT DEFAULT '',
  instructions TEXT DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO businesses
(id, name, description, opening_hours, address, instructions)
VALUES (
  'default',
  'Negócio de demonstração',
  'Atendimento comercial e suporte inicial pelo WhatsApp.',
  'Horários ainda não cadastrados.',
  'Endereço ainda não cadastrado.',
  'Atenda com cordialidade. Use apenas informações cadastradas. Não invente preços nem prometa agendamentos.'
);

CREATE TABLE IF NOT EXISTS knowledge_base (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  business_id TEXT NOT NULL DEFAULT 'default',
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (business_id) REFERENCES businesses(id)
);

CREATE INDEX IF NOT EXISTS idx_knowledge_business_active
ON knowledge_base (business_id, active, priority);

CREATE TABLE IF NOT EXISTS contacts (
  phone TEXT PRIMARY KEY,
  display_name TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS conversations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phone TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_conversations_phone_status
ON conversations (phone, status, id DESC);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_id INTEGER NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  external_id TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (conversation_id) REFERENCES conversations(id)
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id
ON messages (conversation_id, id DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_external_id
ON messages (external_id) WHERE external_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phone TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS handoffs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phone TEXT NOT NULL,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  resolved_at TEXT
);

CREATE TABLE IF NOT EXISTS processed_events (
  event_id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO knowledge_base
(business_id, title, content, priority)
SELECT
  'default',
  'Apresentação',
  'Somos um negócio de demonstração. Esta informação deve ser substituída pelos dados reais da empresa.',
  10
WHERE NOT EXISTS (
  SELECT 1 FROM knowledge_base
  WHERE business_id = 'default'
  AND title = 'Apresentação'
);
