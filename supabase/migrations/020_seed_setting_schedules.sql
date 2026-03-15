-- =============================================
-- 세팅일정 시드 데이터 (2026-03)
-- Google Places API 검색 결과 기반
-- climbing_gyms에 암장 등록 후 gym_id로 세팅일정 INSERT
-- =============================================

-- [1] 오프더월 클라이밍 이태원점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '오프더월 클라이밍(offthewall climbing)',
       '대한민국 서울특별시 용산구 이태원로 190 지하 2층',
       37.5343388, 126.9951502,
       'ChIJuSYEhyam76gRn-hLiile9s4', '오프더월'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJuSYEhyam76gRn-hLiile9s4'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJuSYEhyam76gRn-hLiile9s4'),
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

-- [2] 더클라임 강남점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 강남점 Theclimb Gangnam, Seoul',
       '대한민국 서울특별시 강남구 테헤란로8길 21 지하 1층',
       37.4975157, 127.0319786,
       'ChIJe6NQpHihfDURPqhWiAJrYTo', '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJe6NQpHihfDURPqhWiAJrYTo'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJe6NQpHihfDURPqhWiAJrYTo'),
  '2026-03',
  '[
    {"name": "섹터 3, 4", "dates": ["2026-03-04"]},
    {"name": "섹터 5, 6", "dates": ["2026-03-11"]},
    {"name": "섹터 7, 8", "dates": ["2026-03-18"]},
    {"name": "섹터 1, 2", "dates": ["2026-03-25"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [3] 더클라임 신사점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 신사점 Theclimb Sinsa Seoul',
       '대한민국 서울특별시 강남구 압구정로2길 6 B2',
       37.521096, 127.019134,
       'ChIJsQJsJEmjfDURRZ90Iy1lHFA', '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJsQJsJEmjfDURRZ90Iy1lHFA'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJsQJsJEmjfDURRZ90Iy1lHFA'),
  '2026-03',
  '[
    {"name": "가로수, 나로수", "dates": ["2026-03-12"]},
    {"name": "다로수, 세로수", "dates": ["2026-03-26"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [4] 더클라임 논현점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 논현점 Theclimb Nonhyeon, Seoul',
       '대한민국 서울특별시 강남구 강남대로 519 도충빌딩 지하 1층',
       37.50829180, 127.0222621,
       'ChIJb1dMa0WjfDURKgPvvQkslWk', '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJb1dMa0WjfDURKgPvvQkslWk'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJb1dMa0WjfDURKgPvvQkslWk'),
  '2026-03',
  '[
    {"name": "고개1", "dates": ["2026-03-09"]},
    {"name": "밭", "dates": ["2026-03-16"]},
    {"name": "고개2", "dates": ["2026-03-23"]},
    {"name": "논, 작은발", "dates": ["2026-03-30"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [5] 더클라임 양재점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 양재점',
       '대한민국 서울특별시 강남구 남부순환로 2615 지하 1층',
       37.4851386, 127.0358583,
       'ChIJmc6rKrmhfDUR5tMRnEqMLnM', '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJmc6rKrmhfDUR5tMRnEqMLnM'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJmc6rKrmhfDUR5tMRnEqMLnM'),
  '2026-03',
  '[
    {"name": "CAVE, SLAB, VERTICAL, PROW", "dates": ["2026-03-06"]},
    {"name": "FLAT", "dates": ["2026-03-13"]},
    {"name": "ARCH", "dates": ["2026-03-20"]},
    {"name": "DUNGEON", "dates": ["2026-03-27"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [6] 더클라임 연남점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 연남점, THECLIMB Yeonnam, Seoul',
       '대한민국 서울특별시 마포구 양화로 186 LC타워 3층',
       37.5576629, 126.9257955,
       'ChIJ38_UQVSZfDURCeO8Jt3CkA8', '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJ38_UQVSZfDURCeO8Jt3CkA8'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJ38_UQVSZfDURCeO8Jt3CkA8'),
  '2026-03',
  '[
    {"name": "연남 YEONNAM", "dates": ["2026-03-04", "2026-03-05", "2026-03-25", "2026-03-26"]},
    {"name": "신촌 SINCHON", "dates": ["2026-03-11", "2026-03-12"]},
    {"name": "뒷마루 TOITMARU", "dates": ["2026-03-18", "2026-03-19"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [7] 더클라임 B 홍대점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 B 홍대점 THECLIMB B HONGDAE, SEOUL',
       '대한민국 서울특별시 마포구 353-5 경남관광빌딩 2층',
       37.5546882, 126.9202997,
       'ChIJu7RvctuYfDUR9lNl0BPNsdA', '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJu7RvctuYfDUR9lNl0BPNsdA'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJu7RvctuYfDUR9lNl0BPNsdA'),
  '2026-03',
  '[
    {"name": "섹터 2", "dates": ["2026-03-12"]},
    {"name": "섹터 1", "dates": ["2026-03-19"]},
    {"name": "섹터 3", "dates": ["2026-03-24", "2026-03-31"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [8] 더클라임 문래점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 문래점 Theclimb Mullae, Seoul',
       '대한민국 서울특별시 영등포구 당산로 63',
       37.5206605, 126.8950132,
       'ChIJ-3CkKwCffDURACOSBvJhZfg', '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJ-3CkKwCffDURACOSBvJhZfg'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJ-3CkKwCffDURACOSBvJhZfg'),
  '2026-03',
  '[
    {"name": "집게, 망치", "dates": ["2026-03-05", "2026-03-06", "2026-03-07"]},
    {"name": "도가니", "dates": ["2026-03-12", "2026-03-13"]},
    {"name": "모루", "dates": ["2026-03-19", "2026-03-20"]},
    {"name": "강철", "dates": ["2026-03-26", "2026-03-27"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [9] 더클라임 신림점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 신림점- THECLIMB Sillim, SEOUL',
       '대한민국 서울특별시 관악구 신원로 35 5층',
       37.4821999, 126.928909,
       'ChIJlzybFSGffDUR2TtUFwp6xzo', '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJlzybFSGffDUR2TtUFwp6xzo'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJlzybFSGffDUR2TtUFwp6xzo'),
  '2026-03',
  '[
    {"name": "ENDURANCE", "dates": ["2026-03-03"]},
    {"name": "GALAXY, OVERHANG", "dates": ["2026-03-09", "2026-03-10"]},
    {"name": "ANDROMEDA", "dates": ["2026-03-16", "2026-03-17"]},
    {"name": "BALANCE", "dates": ["2026-03-23", "2026-03-24"]},
    {"name": "MILKYWAY", "dates": ["2026-03-30", "2026-03-31"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [10] 더클라임 사당점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 사당점',
       '대한민국 서울특별시 관악구 남현동 1061-19 B201호',
       37.4743761, 126.9814529,
       'ChIJu07pOdWhfDURkGRR3OrhAm8', '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJu07pOdWhfDURkGRR3OrhAm8'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJu07pOdWhfDURkGRR3OrhAm8'),
  '2026-03',
  '[
    {"name": "관악1", "dates": ["2026-03-03"]},
    {"name": "관악2", "dates": ["2026-03-10"]},
    {"name": "동작1", "dates": ["2026-03-17"]},
    {"name": "동작2", "dates": ["2026-03-24"]},
    {"name": "서초", "dates": ["2026-03-31"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [11] 더클라임 마곡점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 마곡점',
       '대한민국 서울특별시 강서구 마곡동 796-3 마곡사이언스타워 7층',
       37.5606786, 126.8337683,
       'ChIJCfsfrmWcfDURzhXWbjiJAP4', '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJCfsfrmWcfDURzhXWbjiJAP4'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJCfsfrmWcfDURzhXWbjiJAP4'),
  '2026-03',
  '[
    {"name": "섹터 3, 4", "dates": ["2026-03-10"]},
    {"name": "섹터 5, 6", "dates": ["2026-03-17"]},
    {"name": "섹터 7, 8", "dates": ["2026-03-24"]},
    {"name": "섹터 1, 2", "dates": ["2026-03-31"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [12] 더클라임 일산점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 일산점-THECLIMB ILSAN',
       '대한민국 경기도 고양시 중앙로 1160 5층',
       37.6507188, 126.7788853,
       'ChIJE42OYU-FfDURsDzaNjB0baY', '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJE42OYU-FfDURsDzaNjB0baY'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJE42OYU-FfDURsDzaNjB0baY'),
  '2026-03',
  '[
    {"name": "NEW WAVE, ISLAND B", "dates": ["2026-03-04"]},
    {"name": "ISLAND A, ENDURANCE", "dates": ["2026-03-11"]},
    {"name": "COMPETITION WALL", "dates": ["2026-03-18"]},
    {"name": "WHITE WALL", "dates": ["2026-03-25"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [13] 클라이밍파크 강남점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '클라이밍파크 강남점',
       '대한민국 서울특별시 강남구 강남대로 364',
       37.4955483, 127.0293412,
       'ChIJCSdCKAChfDUREjrNrw3hOkQ', '클라이밍파크'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJCSdCKAChfDUREjrNrw3hOkQ'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJCSdCKAChfDUREjrNrw3hOkQ'),
  '2026-03',
  '[
    {"name": "1섹터", "dates": ["2026-03-05"]},
    {"name": "2섹터", "dates": ["2026-03-12"]},
    {"name": "3섹터", "dates": ["2026-03-19"]},
    {"name": "4섹터", "dates": ["2026-03-26"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [14] 클라이밍파크 성수점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '클라이밍파크 성수점',
       '대한민국 서울특별시 성동구 연무장13길 7',
       37.5423046, 127.0580841,
       'ChIJKTpFLaylfDURVXNw2amCnoY', '클라이밍파크'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJKTpFLaylfDURVXNw2amCnoY'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJKTpFLaylfDURVXNw2amCnoY'),
  '2026-03',
  '[
    {"name": "2층", "dates": ["2026-03-09"]},
    {"name": "1층", "dates": ["2026-03-16"]},
    {"name": "3층", "dates": ["2026-03-23"]},
    {"name": "B1", "dates": ["2026-03-30"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [15] 클라이밍파크 종로점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '클라이밍파크 종로점',
       '대한민국 서울특별시 종로구 종로 199 한일빌딩 지하 2층',
       37.5713462, 126.999806,
       'ChIJnUBXwd-jfDURP7y6zkFH8zM', '클라이밍파크'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJnUBXwd-jfDURP7y6zkFH8zM'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJnUBXwd-jfDURP7y6zkFH8zM'),
  '2026-03',
  '[
    {"name": "4섹터", "dates": ["2026-03-03", "2026-03-31"]},
    {"name": "1섹터", "dates": ["2026-03-10"]},
    {"name": "2섹터", "dates": ["2026-03-17"]},
    {"name": "3섹터", "dates": ["2026-03-24"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [16] 클라이밍파크 한티점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '클라이밍파크 한티점',
       '대한민국 서울특별시 강남구 선릉로 324 SH타워 지하 3층',
       37.4984995, 127.0520476,
       'ChIJ1QLywd6lfDURO8jxl4zvEkk', '클라이밍파크'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJ1QLywd6lfDURO8jxl4zvEkk'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJ1QLywd6lfDURO8jxl4zvEkk'),
  '2026-03',
  '[
    {"name": "메인벽", "dates": ["2026-03-13"]},
    {"name": "루프슬랩", "dates": ["2026-03-27"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [17] 클라이밍파크 신논현점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '클라이밍파크 신논현점',
       '대한민국 서울특별시 강남구 강남대로 468 지하 3층',
       37.5041634, 127.0251043,
       'ChIJk29tmcejfDURaiHxyhZPgCc', '클라이밍파크'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJk29tmcejfDURaiHxyhZPgCc'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJk29tmcejfDURaiHxyhZPgCc'),
  '2026-03',
  '[
    {"name": "A섹터", "dates": ["2026-03-06"]},
    {"name": "B섹터", "dates": ["2026-03-20"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [18] 에어즈락 위례점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '에어즈락 클라이밍',
       '대한민국 서울특별시 송파구 위례광장로 188 아이온스퀘어 12층',
       37.4811546, 127.1424435,
       'ChIJexiREO2vfDURlZXeXQdaIJI', '에어즈락'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJexiREO2vfDURlZXeXQdaIJI'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJexiREO2vfDURlZXeXQdaIJI'),
  '2026-03',
  '[
    {"name": "2 Sector", "dates": ["2026-03-06"]},
    {"name": "3 Sector", "dates": ["2026-03-13"]},
    {"name": "4 Sector", "dates": ["2026-03-20"]},
    {"name": "1 Sector", "dates": ["2026-03-27"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [19] 에어즈락 범계점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '에어즈락 클라이밍 범계점',
       '대한민국 경기도 안양시 동안구 시민대로 161 201호',
       37.3904849, 126.9491681,
       'ChIJcx0jhWdhezURxXbIryMNkMM', '에어즈락'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJcx0jhWdhezURxXbIryMNkMM'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJcx0jhWdhezURxXbIryMNkMM'),
  '2026-03',
  '[
    {"name": "Quokka", "dates": ["2026-03-06"]},
    {"name": "Dingo", "dates": ["2026-03-13"]},
    {"name": "Wombat", "dates": ["2026-03-20"]},
    {"name": "Wallaby", "dates": ["2026-03-27"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [20] 알레클라이밍 강동점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '알레클라이밍 강동점(Allez _CLIMB_gangdong)',
       '대한민국 서울특별시 강동구 천호대로177길 39 거산유팰리스 2차 지하 2층',
       37.5363177, 127.1378236,
       'ChIJxUaibfexfDURD74a4hlar3Q', '알레'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJxUaibfexfDURD74a4hlar3Q'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJxUaibfexfDURD74a4hlar3Q'),
  '2026-03',
  '[
    {"name": "1섹터", "dates": ["2026-03-04", "2026-03-30"]},
    {"name": "2섹터", "dates": ["2026-03-09"]},
    {"name": "3섹터", "dates": ["2026-03-16"]},
    {"name": "4섹터", "dates": ["2026-03-23"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [21] 알레클라이밍 혜화점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '알레클라이밍 혜화점',
       '대한민국 서울특별시 종로구 창경궁로34길 18-5 토가빌딩 B2층',
       37.5840841, 127.0007501,
       'ChIJk8ItHUWjfDUR0ZbM1wlX9aQ', '알레'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJk8ItHUWjfDUR0ZbM1wlX9aQ'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJk8ItHUWjfDUR0ZbM1wlX9aQ'),
  '2026-03',
  '[
    {"name": "3섹터", "dates": ["2026-03-05", "2026-03-25"]},
    {"name": "1섹터", "dates": ["2026-03-09"]},
    {"name": "2섹터", "dates": ["2026-03-18"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();

-- [22] 알레클라이밍 영등포점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '알레클라이밍(ALLEZ CLIMBING)',
       '대한민국 서울특별시 영등포구 스위트빌 B01호',
       37.5215708, 126.9028745,
       'ChIJ-7bJyyuffDURFxYxuT4mFoU', '알레'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJ-7bJyyuffDURFxYxuT4mFoU'
);

INSERT INTO gym_setting_schedules (gym_id, year_month, sectors, status)
VALUES (
  (SELECT id FROM climbing_gyms WHERE google_place_id = 'ChIJ-7bJyyuffDURFxYxuT4mFoU'),
  '2026-03',
  '[
    {"name": "영등포", "dates": ["2026-03-10", "2026-03-11", "2026-03-12"]}
  ]'::jsonb,
  'approved'
)
ON CONFLICT (gym_id, year_month) DO UPDATE
SET sectors = EXCLUDED.sectors, updated_at = now();
