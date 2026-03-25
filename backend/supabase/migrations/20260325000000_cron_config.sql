CREATE TABLE cron_config (
  name        TEXT PRIMARY KEY,
  enabled     BOOLEAN NOT NULL DEFAULT true,
  schedule    TEXT NOT NULL,
  label       TEXT NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO cron_config (name, schedule, label) VALUES
  ('blog_generation', '0 0 0 * * *',   'Daily at 5:30 AM IST (midnight UTC)'),
  ('blog_retry',      '0 0 */4 * * *', 'Every 4 hours');

CREATE OR REPLACE FUNCTION update_cron_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cron_config_updated_at
  BEFORE UPDATE ON cron_config
  FOR EACH ROW EXECUTE FUNCTION update_cron_config_updated_at();

ALTER TABLE cron_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY cron_config_service_write ON cron_config
  FOR ALL TO service_role USING (true) WITH CHECK (true);
