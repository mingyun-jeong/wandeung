-- 앱 설정 테이블 (서버에서 동적으로 관리)
CREATE TABLE app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: 모든 인증 사용자 읽기 가능
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can read app_config"
  ON app_config FOR SELECT
  TO authenticated
  USING (true);

-- 기본값 삽입
INSERT INTO app_config (key, value) VALUES
  ('free_storage_limit_bytes', '524288000'::jsonb);  -- 500 MB
