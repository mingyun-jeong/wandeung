-- 세팅일정 조회 성능 개선 인덱스
-- weeklySettingSchedulesProvider / settingSchedulesProvider 쿼리:
--   .eq('year_month', ym).eq('status', 'approved')
--   .inFilter('gym_id', [...])

-- 1. year_month + status 복합 인덱스 (전체 암장 조회용)
CREATE INDEX idx_setting_schedules_ym_status
  ON gym_setting_schedules (year_month, status);

-- 2. status + gym_id + year_month 복합 인덱스 (즐겨찾기 암장 필터 조회용)
CREATE INDEX idx_setting_schedules_status_gym_ym
  ON gym_setting_schedules (status, gym_id, year_month);
