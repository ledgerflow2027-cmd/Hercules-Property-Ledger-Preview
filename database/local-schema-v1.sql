-- Hercules Property Ledger — local SQLite schema
-- Version 1.0.0. Run inside the app's private database directory.
-- The encryption key must be held in iOS Keychain / Android Keystore via a native secure-storage plugin.
-- Never store PINs, biometric templates, or encryption keys in this database.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS app_meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT OR IGNORE INTO app_meta(key, value) VALUES ('schema_version', '1');

CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value_json TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS properties (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  property_type TEXT,
  country_code TEXT,
  currency_code TEXT NOT NULL DEFAULT 'AED',
  address TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  legacy_json TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tenants (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  legacy_json TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS property_tenancies (
  id TEXT PRIMARY KEY,
  property_id TEXT NOT NULL REFERENCES properties(id),
  tenant_id TEXT NOT NULL REFERENCES tenants(id),
  start_date TEXT,
  end_date TEXT,
  rent_minor INTEGER NOT NULL DEFAULT 0 CHECK (rent_minor >= 0),
  currency_code TEXT NOT NULL DEFAULT 'AED',
  status TEXT NOT NULL DEFAULT 'active',
  legacy_json TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vendors (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  category TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  legacy_json TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  account_type TEXT NOT NULL CHECK (account_type IN ('asset','liability','equity','income','expense')),
  parent_id TEXT REFERENCES accounts(id),
  currency_code TEXT,
  is_system INTEGER NOT NULL DEFAULT 0 CHECK (is_system IN (0,1)),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  legacy_json TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS accounting_periods (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','locked')),
  CHECK (start_date <= end_date),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS journal_entries (
  id TEXT PRIMARY KEY,
  journal_number TEXT NOT NULL UNIQUE,
  entry_date TEXT NOT NULL,
  description TEXT NOT NULL,
  source_type TEXT,
  source_id TEXT,
  currency_code TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','posted','reversed')),
  reversal_of_id TEXT REFERENCES journal_entries(id),
  posted_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS journal_lines (
  id TEXT PRIMARY KEY,
  journal_id TEXT NOT NULL REFERENCES journal_entries(id) ON DELETE RESTRICT,
  line_number INTEGER NOT NULL,
  account_id TEXT NOT NULL REFERENCES accounts(id),
  description TEXT,
  debit_minor INTEGER NOT NULL DEFAULT 0 CHECK (debit_minor >= 0),
  credit_minor INTEGER NOT NULL DEFAULT 0 CHECK (credit_minor >= 0),
  property_id TEXT REFERENCES properties(id),
  tenant_id TEXT REFERENCES tenants(id),
  vendor_id TEXT REFERENCES vendors(id),
  CHECK ((debit_minor > 0 AND credit_minor = 0) OR (credit_minor > 0 AND debit_minor = 0)),
  UNIQUE(journal_id, line_number)
);

CREATE TABLE IF NOT EXISTS rent_invoices (
  id TEXT PRIMARY KEY,
  invoice_number TEXT NOT NULL UNIQUE,
  property_id TEXT NOT NULL REFERENCES properties(id),
  tenant_id TEXT NOT NULL REFERENCES tenants(id),
  invoice_date TEXT NOT NULL,
  due_date TEXT NOT NULL,
  currency_code TEXT NOT NULL,
  total_minor INTEGER NOT NULL CHECK (total_minor >= 0),
  status TEXT NOT NULL DEFAULT 'draft',
  legacy_json TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS receipts (
  id TEXT PRIMARY KEY,
  receipt_number TEXT NOT NULL UNIQUE,
  property_id TEXT REFERENCES properties(id),
  tenant_id TEXT REFERENCES tenants(id),
  receipt_date TEXT NOT NULL,
  currency_code TEXT NOT NULL,
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
  payment_method TEXT,
  reference TEXT,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'draft',
  journal_id TEXT REFERENCES journal_entries(id),
  legacy_json TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS receipt_allocations (
  id TEXT PRIMARY KEY,
  receipt_id TEXT NOT NULL REFERENCES receipts(id) ON DELETE RESTRICT,
  invoice_id TEXT NOT NULL REFERENCES rent_invoices(id) ON DELETE RESTRICT,
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
  UNIQUE(receipt_id, invoice_id)
);

CREATE TABLE IF NOT EXISTS vendor_bills (
  id TEXT PRIMARY KEY,
  bill_number TEXT NOT NULL,
  vendor_id TEXT NOT NULL REFERENCES vendors(id),
  property_id TEXT REFERENCES properties(id),
  bill_date TEXT NOT NULL,
  due_date TEXT,
  currency_code TEXT NOT NULL,
  total_minor INTEGER NOT NULL CHECK (total_minor >= 0),
  status TEXT NOT NULL DEFAULT 'draft',
  legacy_json TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS payments (
  id TEXT PRIMARY KEY,
  payment_number TEXT NOT NULL UNIQUE,
  vendor_id TEXT REFERENCES vendors(id),
  property_id TEXT REFERENCES properties(id),
  payment_date TEXT NOT NULL,
  currency_code TEXT NOT NULL,
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
  payment_method TEXT,
  reference TEXT,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'draft',
  journal_id TEXT REFERENCES journal_entries(id),
  legacy_json TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS payment_allocations (
  id TEXT PRIMARY KEY,
  payment_id TEXT NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
  bill_id TEXT NOT NULL REFERENCES vendor_bills(id) ON DELETE RESTRICT,
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
  UNIQUE(payment_id, bill_id)
);

CREATE TABLE IF NOT EXISTS stored_documents (
  id TEXT PRIMARY KEY,
  owner_type TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  mime_type TEXT,
  relative_path TEXT NOT NULL,
  byte_size INTEGER NOT NULL DEFAULT 0 CHECK (byte_size >= 0),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit_log (
  id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  event_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  details_json TEXT
);

CREATE INDEX IF NOT EXISTS idx_tenancies_property ON property_tenancies(property_id, status);
CREATE INDEX IF NOT EXISTS idx_tenancies_tenant ON property_tenancies(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_journal_date_status ON journal_entries(entry_date, status);
CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON journal_lines(account_id, journal_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_property ON journal_lines(property_id, journal_id);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_date ON rent_invoices(tenant_id, invoice_date);
CREATE INDEX IF NOT EXISTS idx_receipts_property_date ON receipts(property_id, receipt_date);
CREATE INDEX IF NOT EXISTS idx_bills_vendor_date ON vendor_bills(vendor_id, bill_date);
CREATE INDEX IF NOT EXISTS idx_payments_vendor_date ON payments(vendor_id, payment_date);
CREATE INDEX IF NOT EXISTS idx_documents_owner ON stored_documents(owner_type, owner_id);

-- A posted journal is immutable. Corrections must use a reversing journal.
CREATE TRIGGER IF NOT EXISTS prevent_update_posted_journal
BEFORE UPDATE ON journal_entries
WHEN OLD.status IN ('posted','reversed')
BEGIN
  SELECT RAISE(ABORT, 'Posted or reversed journals are immutable; create a reversal.');
END;

CREATE TRIGGER IF NOT EXISTS prevent_delete_posted_journal
BEFORE DELETE ON journal_entries
WHEN OLD.status IN ('posted','reversed')
BEGIN
  SELECT RAISE(ABORT, 'Posted or reversed journals cannot be deleted.');
END;

CREATE TRIGGER IF NOT EXISTS prevent_insert_line_into_posted_journal
BEFORE INSERT ON journal_lines
WHEN (SELECT status FROM journal_entries WHERE id = NEW.journal_id) IN ('posted','reversed')
BEGIN
  SELECT RAISE(ABORT, 'Cannot add lines to a posted or reversed journal.');
END;

CREATE TRIGGER IF NOT EXISTS prevent_update_line_in_posted_journal
BEFORE UPDATE ON journal_lines
WHEN (SELECT status FROM journal_entries WHERE id = OLD.journal_id) IN ('posted','reversed')
BEGIN
  SELECT RAISE(ABORT, 'Cannot change lines in a posted or reversed journal.');
END;

CREATE TRIGGER IF NOT EXISTS prevent_delete_line_in_posted_journal
BEFORE DELETE ON journal_lines
WHEN (SELECT status FROM journal_entries WHERE id = OLD.journal_id) IN ('posted','reversed')
BEGIN
  SELECT RAISE(ABORT, 'Cannot delete lines from a posted or reversed journal.');
END;

CREATE TRIGGER IF NOT EXISTS prevent_posting_in_locked_period
BEFORE UPDATE OF status ON journal_entries
WHEN NEW.status = 'posted'
 AND EXISTS (
   SELECT 1 FROM accounting_periods p
   WHERE p.status = 'locked'
     AND NEW.entry_date BETWEEN p.start_date AND p.end_date
 )
BEGIN
  SELECT RAISE(ABORT, 'Cannot post into a locked accounting period.');
END;
