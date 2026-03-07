-- climbing_gyms 테이블에 Google Place ID 컬럼 추가
ALTER TABLE climbing_gyms ADD COLUMN google_place_id TEXT;

-- Google Place ID로 중복 방지 (같은 장소는 하나만)
CREATE UNIQUE INDEX idx_gyms_google_place_id ON climbing_gyms(google_place_id)
  WHERE google_place_id IS NOT NULL;

-- climbing_records에서 gym_name 컬럼 제거 (climbing_gyms JOIN으로 대체)
ALTER TABLE climbing_records DROP COLUMN IF EXISTS gym_name;
