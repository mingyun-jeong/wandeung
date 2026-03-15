-- gym_setting_schedules 테이블을 gym_name/gym_brand 에서 gym_id 기반으로 변경
-- 기존 데이터가 없으므로 테이블 재생성

DROP TABLE IF EXISTS setting_schedule_contributors;
DROP TABLE IF EXISTS gym_setting_schedules;

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

ALTER TABLE gym_setting_schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gym_setting_schedules_select"
  ON gym_setting_schedules FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "gym_setting_schedules_insert"
  ON gym_setting_schedules FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = submitted_by);

CREATE POLICY "gym_setting_schedules_update"
  ON gym_setting_schedules FOR UPDATE
  TO authenticated
  USING (auth.uid() = submitted_by);

CREATE POLICY "gym_setting_schedules_delete"
  ON gym_setting_schedules FOR DELETE
  TO authenticated
  USING (auth.uid() = submitted_by);

CREATE TABLE setting_schedule_contributors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  schedule_id UUID NOT NULL REFERENCES gym_setting_schedules ON DELETE CASCADE,
  contributed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, schedule_id)
);

ALTER TABLE setting_schedule_contributors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "setting_schedule_contributors_select"
  ON setting_schedule_contributors FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "setting_schedule_contributors_insert"
  ON setting_schedule_contributors FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);
