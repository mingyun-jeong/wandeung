-- 암장 브랜드별 난이도 색상표 테이블
CREATE TABLE gym_color_scales (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  brand_name TEXT NOT NULL UNIQUE,
  levels JSONB NOT NULL,  -- [{level, color, v_min, v_max}, ...] (Hard→Easy 순)
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS 활성화
ALTER TABLE gym_color_scales ENABLE ROW LEVEL SECURITY;

-- RLS 정책: 인증 사용자 읽기 전용
CREATE POLICY "Authenticated users can read gym color scales"
  ON gym_color_scales FOR SELECT
  TO authenticated
  USING (true);

-- climbing_gyms에 브랜드 연결 컬럼 추가
ALTER TABLE climbing_gyms ADD COLUMN brand_name TEXT;
