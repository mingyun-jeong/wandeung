-- 구독 관리 테이블
CREATE TABLE user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  plan TEXT NOT NULL DEFAULT 'free',          -- 'free' | 'pro'
  status TEXT NOT NULL DEFAULT 'active',      -- 'active' | 'cancelled' | 'expired'
  platform TEXT NOT NULL DEFAULT 'android',   -- 향후 iOS 대비
  store_transaction_id TEXT,
  started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 사용자당 하나의 구독만 허용
CREATE UNIQUE INDEX idx_user_subscriptions_user_id ON user_subscriptions(user_id);

-- RLS 활성화
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

-- 자신의 구독만 읽기 가능
CREATE POLICY "Users can read own subscription"
  ON user_subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- 서버(Edge Function)에서만 INSERT/UPDATE 하므로 사용자 직접 쓰기 불가
-- service_role key 사용하는 Edge Function에서 관리
