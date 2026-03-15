-- 오프더월 클라이밍 이태원점 2026-03 세팅일정 등록
-- Google Places API 검색 결과 기반
WITH gym AS (
  INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
  VALUES (
    '오프더월 클라이밍(offthewall climbing)',
    '대한민국 서울특별시 용산구 이태원로 190 지하 2층',
    37.5343388,
    126.9951502,
    'ChIJuSYEhyam76gRn-hLiile9s4',
    '오프더월'
  )
  ON CONFLICT (google_place_id) DO UPDATE
  SET name = EXCLUDED.name
  RETURNING id
),
gym_id AS (
  SELECT id FROM gym
  UNION ALL
  SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJuSYEhyam76gRn-hLiile9s4'
  LIMIT 1
)
INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM gym_id),
  '2026-03',
  '[
    {"name": "SECTOR A", "dates": ["2026-03-10"]},
    {"name": "SECTOR B", "dates": ["2026-03-17"]},
    {"name": "SECTOR C", "dates": ["2026-03-24"]},
    {"name": "SECTOR D", "dates": ["2026-03-31"]},
    {"name": "ENDURANCE WALL", "dates": []}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();
