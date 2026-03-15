-- 세팅일정 테이블: 암장별 월간 세팅 일정
CREATE TABLE gym_setting_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL REFERENCES climbing_gyms ON DELETE CASCADE,
  year_month TEXT NOT NULL,
  sectors JSONB NOT NULL,
  source_image_url TEXT,
  submitted_by UUID REFERENCES auth.users,
  status TEXT NOT NULL DEFAULT 'approved',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(gym_id, year_month)
);

-- RLS 활성화
ALTER TABLE gym_setting_schedules ENABLE ROW LEVEL SECURITY;

-- 조회: 인증된 사용자 전체
CREATE POLICY "gym_setting_schedules_select"
  ON gym_setting_schedules FOR SELECT
  TO authenticated
  USING (true);

-- 등록: 인증된 사용자
CREATE POLICY "gym_setting_schedules_insert"
  ON gym_setting_schedules FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = submitted_by);

-- 수정: 본인만
CREATE POLICY "gym_setting_schedules_update"
  ON gym_setting_schedules FOR UPDATE
  TO authenticated
  USING (auth.uid() = submitted_by);

-- 삭제: 본인만
CREATE POLICY "gym_setting_schedules_delete"
  ON gym_setting_schedules FOR DELETE
  TO authenticated
  USING (auth.uid() = submitted_by);

-- 기여자 추적 테이블
CREATE TABLE setting_schedule_contributors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  schedule_id UUID NOT NULL REFERENCES gym_setting_schedules ON DELETE CASCADE,
  contributed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, schedule_id)
);

-- RLS 활성화
ALTER TABLE setting_schedule_contributors ENABLE ROW LEVEL SECURITY;

-- 조회: 인증된 사용자 전체
CREATE POLICY "setting_schedule_contributors_select"
  ON setting_schedule_contributors FOR SELECT
  TO authenticated
  USING (true);

-- 등록: 본인만
CREATE POLICY "setting_schedule_contributors_insert"
  ON setting_schedule_contributors FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);
