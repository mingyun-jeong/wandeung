-- =============================================
-- google_place_id가 누락된 암장 정리
--
-- 문제: 020에서 긴 이름으로 google_place_id 포함하여 삽입된 암장이
-- 021에서 짧은 이름으로 중복 삽입됨 (google_place_id 없이)
-- 해결: 중복 행 삭제 + 신규 암장 google_place_id 업데이트
-- =============================================

-- [1] 020과 021에서 이름이 달라 중복된 행 삭제
-- (google_place_id가 있는 020 행은 유지, 없는 021 행 삭제)

DELETE FROM climbing_gyms
WHERE name = '더클라임 B 홍대점'
  AND google_place_id IS NULL
  AND EXISTS (SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJu7RvctuYfDUR9lNl0BPNsdA');

DELETE FROM climbing_gyms
WHERE name = '더클라임 문래점'
  AND google_place_id IS NULL
  AND EXISTS (SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJ-3CkKwCffDURACOSBvJhZfg');

DELETE FROM climbing_gyms
WHERE name = '더클라임 신림점'
  AND google_place_id IS NULL
  AND EXISTS (SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJlzybFSGffDUR2TtUFwp6xzo');

DELETE FROM climbing_gyms
WHERE name = '더클라임 일산점'
  AND google_place_id IS NULL
  AND EXISTS (SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJE42OYU-FfDURsDzaNjB0baY');

-- [2] google_place_id 업데이트 (Google Places API 조회 결과)

-- 더클라임 (이름 동일 — 중복 없음, 020에서 이미 google_place_id 있을 수 있음)
UPDATE climbing_gyms SET google_place_id = 'ChIJu07pOdWhfDURkGRR3OrhAm8'
WHERE name = '더클라임 사당점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJCfsfrmWcfDURzhXWbjiJAP4'
WHERE name = '더클라임 마곡점' AND google_place_id IS NULL;

-- 클라이밍파크 (이름 동일)
UPDATE climbing_gyms SET google_place_id = 'ChIJCSdCKAChfDUREjrNrw3hOkQ'
WHERE name = '클라이밍파크 강남점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJKTpFLaylfDURVXNw2amCnoY'
WHERE name = '클라이밍파크 성수점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJnUBXwd-jfDURP7y6zkFH8zM'
WHERE name = '클라이밍파크 종로점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJ1QLywd6lfDURO8jxl4zvEkk'
WHERE name = '클라이밍파크 한티점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJk29tmcejfDURaiHxyhZPgCc'
WHERE name = '클라이밍파크 신논현점' AND google_place_id IS NULL;

-- 서울숲클라이밍
UPDATE climbing_gyms SET google_place_id = 'ChIJZ92I4r-lfDURuDUSDFeIhyU'
WHERE name = '서울숲클라이밍 잠실점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJU8jjDACjfDURqfDftifPyxw'
WHERE name = '서울숲클라이밍 종로점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJzYEVF4yffDUR9Cwe9XU_IXU'
WHERE name = '서울숲클라이밍 구로점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJc0q7p72ffDURq9cl581OnKI'
WHERE name = '서울숲클라이밍 영등포점' AND google_place_id IS NULL;

-- 서울볼더스
UPDATE climbing_gyms SET google_place_id = 'ChIJsUTUiJSffDURK08L22EHe7g'
WHERE name = '서울볼더스 선유점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJewO25x6ffDURXUX1mOIGhNo'
WHERE name = '서울볼더스 목동점' AND google_place_id IS NULL;

-- 비블럭
UPDATE climbing_gyms SET google_place_id = 'ChIJCbNzxuijfDURnsWzQ-9r46s'
WHERE name = '비블럭 강남점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJGYhUQbl3ezUROBcJ_iPKTs0'
WHERE name = '비블럭 송도점' AND google_place_id IS NULL;

-- 캐치스톤
UPDATE climbing_gyms SET google_place_id = 'ChIJndsjVAB9ezURj2UHzyEb9MY'
WHERE name = '캐치스톤 부천점' AND google_place_id IS NULL;

-- 피커스
UPDATE climbing_gyms SET google_place_id = 'ChIJId-O3VSjfDURQ3C91JlxF9g'
WHERE name = '피커스 종로점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJrQe0_EmZfDUR_kbfSZ2aGhY'
WHERE name = '피커스 신촌점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJUaQqsd6ffDURfqHUI2XG-9w'
WHERE name = '피커스 구로점' AND google_place_id IS NULL;

-- 더플라스틱
UPDATE climbing_gyms SET google_place_id = 'ChIJU76YReWffDUR_DdETK_yM8E'
WHERE name = '더플라스틱 염창점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJB2MTUF-ffDURRmw2_cHH8WY'
WHERE name = '더플라스틱 문래점' AND google_place_id IS NULL;

-- 에어즈락
UPDATE climbing_gyms SET google_place_id = 'ChIJexiREO2vfDURlZXeXQdaIJI'
WHERE name = '에어즈락 위례점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJcx0jhWdhezURxXbIryMNkMM',
       address = COALESCE(NULLIF(address, ''), '경기도 안양시 동안구 시민대로 161 201호')
WHERE name = '에어즈락 범계점' AND google_place_id IS NULL;

-- 알레클라임
UPDATE climbing_gyms SET google_place_id = 'ChIJ-7bJyyuffDURFxYxuT4mFoU'
WHERE name = '알레클라임 영등포점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJxUaibfexfDURD74a4hlar3Q'
WHERE name = '알레클라임 강동점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJk8ItHUWjfDUR0ZbM1wlX9aQ'
WHERE name = '알레클라임 혜화점' AND google_place_id IS NULL;

-- 훅클라이밍
UPDATE climbing_gyms SET google_place_id = 'ChIJv36LOBWjfDURv2T6nuanzKU'
WHERE name = '훅클라이밍 왕십리점' AND google_place_id IS NULL;

-- 클라임어스
UPDATE climbing_gyms SET google_place_id = 'ChIJcTAJ4ICofDURmW_ZEWi_6DE'
WHERE name = '클라임어스 모란점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJIQ6gRQCxfDURZA5GUISg9o4',
       address = COALESCE(NULLIF(address, ''), '경기도 하남시 미사강변동로 81 13층')
WHERE name = '클라임어스 미사점' AND google_place_id IS NULL;

-- 손상원클라이밍짐
UPDATE climbing_gyms SET google_place_id = 'ChIJwyKBdQCjfDURey5pWuvt6LM'
WHERE name = '손상원클라이밍짐 을지로점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJVR0AxnahfDURHEA83XNxa2o'
WHERE name = '손상원클라이밍짐 강남점' AND google_place_id IS NULL;

UPDATE climbing_gyms SET google_place_id = 'ChIJMdf_GZSnfDURkedBb0OTkkI'
WHERE name = '손상원클라이밍짐 판교점' AND google_place_id IS NULL;

-- =============================================
-- 서울숲클라이밍 뚝섬점: Google Maps에 등록되지 않음 (Place ID 없음)
-- TODO: 뚝섬점이 Google Maps에 등록되면 추후 업데이트
-- =============================================
