-- =============================================
-- 전체 암장 시드 데이터
-- 웹 검색 기반 주소/좌표 (2026-03-15)
-- WHERE NOT EXISTS로 중복 방지
-- (google_place_id가 있으면 해당 값으로, 없으면 name으로 체크)
-- =============================================

-- =========== 더클라임 ===========

-- 더클라임 강남점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 강남점',
       '서울특별시 강남구 테헤란로8길 21 지하 1층',
       37.4975157, 127.0319786,
       'ChIJe6NQpHihfDURPqhWiAJrYTo',
       '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJe6NQpHihfDURPqhWiAJrYTo'
);

-- 더클라임 신사점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 신사점',
       '서울특별시 강남구 압구정로2길 6 B2',
       37.521096, 127.019134,
       'ChIJsQJsJEmjfDURRZ90Iy1lHFA',
       '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJsQJsJEmjfDURRZ90Iy1lHFA'
);

-- 더클라임 논현점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 논현점',
       '서울특별시 강남구 강남대로 519 도충빌딩 지하 1층',
       37.50829180, 127.0222621,
       'ChIJb1dMa0WjfDURKgPvvQkslWk',
       '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJb1dMa0WjfDURKgPvvQkslWk'
);

-- 더클라임 양재점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 양재점',
       '서울특별시 강남구 남부순환로 2615 지하 1층',
       37.4851386, 127.0358583,
       'ChIJmc6rKrmhfDUR5tMRnEqMLnM',
       '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJmc6rKrmhfDUR5tMRnEqMLnM'
);

-- 더클라임 연남점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '더클라임 연남점',
       '서울특별시 마포구 양화로 186 LC타워 3층',
       37.5576629, 126.9257955,
       'ChIJ38_UQVSZfDURCeO8Jt3CkA8',
       '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJ38_UQVSZfDURCeO8Jt3CkA8'
);

-- 더클라임 B 홍대점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '더클라임 B 홍대점',
       '서울특별시 마포구 양화로 125 경남관광빌딩 2층',
       37.554709, 126.920273,
       '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '더클라임 B 홍대점'
);

-- 더클라임 문래점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '더클라임 문래점',
       '서울특별시 영등포구 당산로 63',
       37.520567, 126.895005,
       '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '더클라임 문래점'
);

-- 더클라임 신림점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '더클라임 신림점',
       '서울특별시 관악구 신원로 35',
       37.482309, 126.929019,
       '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '더클라임 신림점'
);

-- 더클라임 사당점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '더클라임 사당점',
       '서울특별시 관악구 과천대로 939',
       37.474479, 126.981480,
       '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '더클라임 사당점'
);

-- 더클라임 마곡점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '더클라임 마곡점',
       '서울특별시 강서구 마곡동로 62',
       37.560555, 126.833891,
       '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '더클라임 마곡점'
);

-- 더클라임 일산점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '더클라임 일산점',
       '경기도 고양시 일산동구 중앙로 1160',
       37.650846, 126.778813,
       '더클라임'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '더클라임 일산점'
);

-- =========== 클라이밍파크 ===========

-- 클라이밍파크 강남점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '클라이밍파크 강남점',
       '서울특별시 강남구 강남대로 364 지하 1층',
       37.495538, 127.029196,
       '클라이밍파크'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '클라이밍파크 강남점'
);

-- 클라이밍파크 종로점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '클라이밍파크 종로점',
       '서울특별시 종로구 종로 199-1 한일빌딩 지하 2층',
       37.571106, 126.999909,
       '클라이밍파크'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '클라이밍파크 종로점'
);

-- 클라이밍파크 한티점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '클라이밍파크 한티점',
       '서울특별시 강남구 선릉로 324 SH타워 지하 3층',
       37.498528, 127.052088,
       '클라이밍파크'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '클라이밍파크 한티점'
);

-- 클라이밍파크 성수점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '클라이밍파크 성수점',
       '서울특별시 성동구 연무장13길 7 매니아빌딩',
       37.542307, 127.058068,
       '클라이밍파크'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '클라이밍파크 성수점'
);

-- =========== 서울숲클라이밍 ===========

-- 서울숲클라이밍 뚝섬점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '서울숲클라이밍 뚝섬점',
       '서울특별시 성동구 성수일로 19 유한타워 B2층',
       37.542325, 127.048594,
       '서울숲'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '서울숲클라이밍 뚝섬점'
);

-- 서울숲클라이밍 잠실점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '서울숲클라이밍 잠실점',
       '서울특별시 송파구 백제고분로7길 49',
       37.51103, 127.084156,
       '서울숲'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '서울숲클라이밍 잠실점'
);

-- 서울숲클라이밍 종로점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '서울숲클라이밍 종로점',
       '서울특별시 종로구 수표로 96 지하 1층',
       37.569705, 126.990024,
       '서울숲'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '서울숲클라이밍 종로점'
);

-- 서울숲클라이밍 구로점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '서울숲클라이밍 구로점',
       '서울특별시 구로구 디지털로 300 지하 1층',
       37.484925, 126.896532,
       '서울숲'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '서울숲클라이밍 구로점'
);

-- 서울숲클라이밍 영등포점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '서울숲클라이밍 영등포점',
       '서울특별시 영등포구 문래로 164 B동 1층',
       37.517735, 126.900243,
       '서울숲'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '서울숲클라이밍 영등포점'
);

-- =========== 서울볼더스 ===========

-- 서울볼더스 선유점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '서울볼더스 선유점',
       '서울특별시 영등포구 양평로28마길 7 3층',
       37.542035, 126.891070,
       '서울볼더스'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '서울볼더스 선유점'
);

-- 서울볼더스 목동점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '서울볼더스 목동점',
       '서울특별시 양천구 신목로 53',
       37.520608, 126.872366,
       '서울볼더스'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '서울볼더스 목동점'
);

-- =========== 비블럭 ===========

-- 비블럭 강남점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '비블럭 강남점',
       '서울특별시 강남구 논현로 563 언주타워 지하 1층',
       37.506331, 127.034068,
       '비블럭'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '비블럭 강남점'
);

-- 비블럭 송도점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '비블럭 송도점',
       '인천광역시 연수구 송도과학로16번길 13-39',
       37.380080, 126.663799,
       '비블럭'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '비블럭 송도점'
);

-- =========== 오프더월 ===========

-- 오프더월 이태원점
INSERT INTO climbing_gyms (name, address, latitude, longitude, google_place_id, brand_name)
SELECT '오프더월 이태원점',
       '서울특별시 용산구 이태원로 190 지하 2층',
       37.5343388, 126.9951502,
       'ChIJuSYEhyam76gRn-hLiile9s4',
       '오프더월'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE google_place_id = 'ChIJuSYEhyam76gRn-hLiile9s4'
);

-- =========== 캐치스톤 ===========

-- 캐치스톤 부천점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '캐치스톤 부천점',
       '경기도 부천시 원미구 부천로 11 해태쇼핑 18층',
       37.485671, 126.782232,
       '캐치스톤'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '캐치스톤 부천점'
);

-- =========== 피커스 ===========

-- 피커스 종로점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '피커스 종로점',
       '서울특별시 종로구 돈화문로5가길 1 CGV피카디리1958 지하 4층',
       37.570911, 126.991397,
       '피커스'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '피커스 종로점'
);

-- 피커스 신촌점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '피커스 신촌점',
       '서울특별시 서대문구 신촌로 129 CGV신촌아트레온 11층',
       37.556562, 126.940232,
       '피커스'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '피커스 신촌점'
);

-- 피커스 구로점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '피커스 구로점',
       '서울특별시 구로구 구로중앙로 152 NC신구로점 6층',
       37.501157, 126.882770,
       '피커스'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '피커스 구로점'
);

-- =========== 더플라스틱 ===========

-- 더플라스틱 염창점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '더플라스틱 염창점',
       '서울특별시 강서구 공항대로81길 27 1층',
       37.548503, 126.876192,
       '더플라스틱'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '더플라스틱 염창점'
);

-- 더플라스틱 문래점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '더플라스틱 문래점',
       '서울특별시 영등포구 도림로 423 1층',
       37.513631, 126.895704,
       '더플라스틱'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '더플라스틱 문래점'
);

-- =========== 에어즈락 ===========

-- 에어즈락 위례점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '에어즈락 위례점',
       '서울특별시 송파구 위례광장로 188 아이온스퀘어 12층',
       37.4784, 127.1430,
       '에어즈락'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '에어즈락 위례점'
);

-- 에어즈락 범계점 (주소 미확인 — 수동 확인 필요)
INSERT INTO climbing_gyms (name, brand_name)
SELECT '에어즈락 범계점', '에어즈락'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '에어즈락 범계점'
);

-- =========== 알레클라임 ===========

-- 알레클라임 영등포점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '알레클라임 영등포점',
       '서울특별시 영등포구 영등포동6가 스위트빌 B01호',
       37.5157, 126.9053,
       '알레'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '알레클라임 영등포점'
);

-- 알레클라임 강동점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '알레클라임 강동점',
       '서울특별시 강동구 천호대로177길 39 거산유팰리스2차 B2층',
       37.5347, 127.1443,
       '알레'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '알레클라임 강동점'
);

-- 알레클라임 혜화점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '알레클라임 혜화점',
       '서울특별시 종로구 창경궁로34길 18-5 동숭갤러리 B2층',
       37.5816, 127.0018,
       '알레'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '알레클라임 혜화점'
);

-- =========== 훅클라이밍 ===========

-- 훅클라이밍 왕십리점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '훅클라이밍 왕십리점',
       '서울특별시 성동구 행당동 140 2층',
       37.5614, 127.0368,
       '훅클라이밍'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '훅클라이밍 왕십리점'
);

-- =========== 클라임어스 ===========

-- 클라임어스 모란점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '클라임어스 모란점',
       '경기도 성남시 중원구 모란역 부근',
       37.4325, 127.0129,
       '클라임어스'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '클라임어스 모란점'
);

-- 클라임어스 미사점 (주소 미확인 — 수동 확인 필요)
INSERT INTO climbing_gyms (name, brand_name)
SELECT '클라임어스 미사점', '클라임어스'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '클라임어스 미사점'
);

-- =========== 손상원클라이밍짐 ===========

-- 손상원클라이밍짐 을지로점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '손상원클라이밍짐 을지로점',
       '서울특별시 중구 남대문로 125 IM금융센터 B1층',
       37.5700, 126.9808,
       '손상원'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '손상원클라이밍짐 을지로점'
);

-- 손상원클라이밍짐 강남점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '손상원클라이밍짐 강남점',
       '서울특별시 서초구 강남대로 331 B1층',
       37.4960, 127.0276,
       '손상원'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '손상원클라이밍짐 강남점'
);

-- 손상원클라이밍짐 판교점
INSERT INTO climbing_gyms (name, address, latitude, longitude, brand_name)
SELECT '손상원클라이밍짐 판교점',
       '경기도 성남시 분당구 대왕판교로 670 유스페이스2 B동 B1층',
       37.4022, 127.1085,
       '손상원'
WHERE NOT EXISTS (
  SELECT 1 FROM climbing_gyms WHERE name = '손상원클라이밍짐 판교점'
);
