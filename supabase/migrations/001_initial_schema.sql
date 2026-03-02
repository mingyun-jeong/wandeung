-- 클라이밍장 테이블
CREATE TABLE climbing_gyms (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 등반 기록 테이블
CREATE TABLE climbing_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  gym_id UUID REFERENCES climbing_gyms(id),
  gym_name TEXT,
  grade TEXT NOT NULL,
  difficulty_color TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'completed',
  video_path TEXT,
  thumbnail_path TEXT,
  tags TEXT[] DEFAULT '{}',
  memo TEXT,
  recorded_at DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 인덱스
CREATE INDEX idx_records_user_date ON climbing_records(user_id, recorded_at);
CREATE INDEX idx_records_user_id ON climbing_records(user_id);

-- RLS 활성화
ALTER TABLE climbing_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE climbing_gyms ENABLE ROW LEVEL SECURITY;

-- RLS 정책: 자신의 기록만 CRUD
CREATE POLICY "Users can CRUD own records"
  ON climbing_records FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- RLS 정책: 클라이밍장은 모든 인증 사용자가 조회/생성 가능
CREATE POLICY "Authenticated users can read gyms"
  ON climbing_gyms FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert gyms"
  ON climbing_gyms FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = created_by);

-- Storage 버킷 정책 (Supabase 대시보드에서 climbing-videos 버킷 생성 후 적용)
-- CREATE POLICY "Users can upload own videos"
--   ON storage.objects FOR INSERT
--   TO authenticated
--   WITH CHECK (bucket_id = 'climbing-videos' AND auth.uid()::text = (storage.foldername(name))[1]);
--
-- CREATE POLICY "Users can read own videos"
--   ON storage.objects FOR SELECT
--   TO authenticated
--   USING (bucket_id = 'climbing-videos' AND auth.uid()::text = (storage.foldername(name))[1]);
--
-- CREATE POLICY "Users can delete own videos"
--   ON storage.objects FOR DELETE
--   TO authenticated
--   USING (bucket_id = 'climbing-videos' AND auth.uid()::text = (storage.foldername(name))[1]);
