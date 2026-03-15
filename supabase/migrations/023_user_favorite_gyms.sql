-- 사용자별 암장 즐겨찾기
CREATE TABLE user_favorite_gyms (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  gym_id UUID REFERENCES climbing_gyms(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, gym_id)
);

CREATE INDEX idx_user_favorite_gyms_user ON user_favorite_gyms(user_id);

-- RLS
ALTER TABLE user_favorite_gyms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own favorites"
  ON user_favorite_gyms FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own favorites"
  ON user_favorite_gyms FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own favorites"
  ON user_favorite_gyms FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
