-- 10개 주요 클라이밍 브랜드 색상표 시드 데이터
-- levels: Hard(Lv.1) → Easy(Lv.N) 순서
-- V-scale 매핑 기준:
--   Lv.1  → V10+  (선수)
--   Lv.2  → V7~V9 (쌉고수)
--   Lv.3  → V6~V7 (쌉고수 진입)
--   Lv.4  → V4~V6 (고수/중고수)
--   Lv.5  → V3~V5 (중고수 진입)
--   Lv.6  → V1~V3 (중수/숙련)
--   Lv.7  → V0~Vb (입문/초보)
--   Lv.8  → Vbb   (입문)
--   Lv.9  → Vbbb  (입문)
--   Lv.10 → Vbbbbb(펭수)

INSERT INTO gym_color_scales (brand_name, levels) VALUES

-- 더클라임: 갈색,회색,보라,빨강,파랑,초록,노랑,주황,흰색
('더클라임', '[
  {"level":1,"color":"brown","v_min":"v10","v_max":"v10"},
  {"level":2,"color":"gray","v_min":"v7","v_max":"v9"},
  {"level":3,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":4,"color":"red","v_min":"v4","v_max":"v6"},
  {"level":5,"color":"blue","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":7,"color":"yellow","v_min":"v0","v_max":"vB"},
  {"level":8,"color":"orange","v_min":"vBb","v_max":"vBb"},
  {"level":9,"color":"white","v_min":"vBbb","v_max":"vBbb"}
]'::jsonb),

-- 클라이밍파크: 흰색,검정,회색,갈색,보라,빨강,파랑,분홍,노랑
('클라이밍파크', '[
  {"level":1,"color":"white","v_min":"v10","v_max":"v10"},
  {"level":2,"color":"black","v_min":"v7","v_max":"v9"},
  {"level":3,"color":"gray","v_min":"v6","v_max":"v7"},
  {"level":4,"color":"brown","v_min":"v4","v_max":"v6"},
  {"level":5,"color":"purple","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"red","v_min":"v1","v_max":"v3"},
  {"level":7,"color":"blue","v_min":"v0","v_max":"vB"},
  {"level":8,"color":"pink","v_min":"vBb","v_max":"vBb"},
  {"level":9,"color":"yellow","v_min":"vBbb","v_max":"vBbb"}
]'::jsonb),

-- 더플라스틱: 검정,보라,남색,하늘,초록,노랑,주황,빨강
('더플라스틱', '[
  {"level":1,"color":"black","v_min":"v10","v_max":"v10"},
  {"level":2,"color":"purple","v_min":"v7","v_max":"v9"},
  {"level":3,"color":"navy","v_min":"v6","v_max":"v7"},
  {"level":4,"color":"skyBlue","v_min":"v4","v_max":"v6"},
  {"level":5,"color":"green","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":7,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":8,"color":"red","v_min":"vBb","v_max":"vBb"}
]'::jsonb),

-- 클라임어스: 검정,흰색,보라,남색,하늘,초록,노랑,주황,빨강
('클라임어스', '[
  {"level":1,"color":"black","v_min":"v10","v_max":"v10"},
  {"level":2,"color":"white","v_min":"v7","v_max":"v9"},
  {"level":3,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":4,"color":"navy","v_min":"v4","v_max":"v6"},
  {"level":5,"color":"skyBlue","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":7,"color":"yellow","v_min":"v0","v_max":"vB"},
  {"level":8,"color":"orange","v_min":"vBb","v_max":"vBb"},
  {"level":9,"color":"red","v_min":"vBbb","v_max":"vBbb"}
]'::jsonb),

-- 훅클라이밍: 별,보라,남색,파랑,초록,노랑,주황,빨강
('훅클라이밍', '[
  {"level":1,"color":"star","v_min":"v10","v_max":"v10"},
  {"level":2,"color":"purple","v_min":"v7","v_max":"v9"},
  {"level":3,"color":"navy","v_min":"v6","v_max":"v7"},
  {"level":4,"color":"blue","v_min":"v4","v_max":"v6"},
  {"level":5,"color":"green","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":7,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":8,"color":"red","v_min":"vBb","v_max":"vBb"}
]'::jsonb),

-- 피커스: 회색,보라,남색,파랑,초록,노랑,주황,빨강
('피커스', '[
  {"level":1,"color":"gray","v_min":"v10","v_max":"v10"},
  {"level":2,"color":"purple","v_min":"v7","v_max":"v9"},
  {"level":3,"color":"navy","v_min":"v6","v_max":"v7"},
  {"level":4,"color":"blue","v_min":"v4","v_max":"v6"},
  {"level":5,"color":"green","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":7,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":8,"color":"red","v_min":"vBb","v_max":"vBb"}
]'::jsonb),

-- 비블럭: 검정,남색,빨강,초록,하늘,분홍,주황,노랑,흰색
('비블럭', '[
  {"level":1,"color":"black","v_min":"v10","v_max":"v10"},
  {"level":2,"color":"navy","v_min":"v7","v_max":"v9"},
  {"level":3,"color":"red","v_min":"v6","v_max":"v7"},
  {"level":4,"color":"green","v_min":"v4","v_max":"v6"},
  {"level":5,"color":"skyBlue","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"pink","v_min":"v1","v_max":"v3"},
  {"level":7,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":8,"color":"yellow","v_min":"vBb","v_max":"vBb"},
  {"level":9,"color":"white","v_min":"vBbb","v_max":"vBbb"}
]'::jsonb),

-- 캐치스톤: 무지개,검정,보라,남색,파랑,초록,노랑,주황,빨강,흰색
('캐치스톤', '[
  {"level":1,"color":"rainbow","v_min":"v10","v_max":"v10"},
  {"level":2,"color":"black","v_min":"v7","v_max":"v9"},
  {"level":3,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":4,"color":"navy","v_min":"v4","v_max":"v6"},
  {"level":5,"color":"blue","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":7,"color":"yellow","v_min":"v0","v_max":"vB"},
  {"level":8,"color":"orange","v_min":"vBb","v_max":"vBb"},
  {"level":9,"color":"red","v_min":"vBbb","v_max":"vBbb"},
  {"level":10,"color":"white","v_min":"vBbbbb","v_max":"vBbbbb"}
]'::jsonb),

-- 서울볼더스: 갈색,회색,보라,빨강,파랑,초록,노랑,주황,흰색
('서울볼더스', '[
  {"level":1,"color":"brown","v_min":"v10","v_max":"v10"},
  {"level":2,"color":"gray","v_min":"v7","v_max":"v9"},
  {"level":3,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":4,"color":"red","v_min":"v4","v_max":"v6"},
  {"level":5,"color":"blue","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":7,"color":"yellow","v_min":"v0","v_max":"vB"},
  {"level":8,"color":"orange","v_min":"vBb","v_max":"vBb"},
  {"level":9,"color":"white","v_min":"vBbb","v_max":"vBbb"}
]'::jsonb);

-- 브랜드명 자동매칭을 위한 패턴 매핑
-- (앱에서 Google Places 이름에서 브랜드를 추출할 때 사용)
-- 예: "더클라임 강남점" → brand_name = "더클라임"
COMMENT ON TABLE gym_color_scales IS '암장 브랜드별 난이도 색상표. brand_name은 Google Places 암장명에서 자동 매칭됨.';
