-- 전체 브랜드 레벨 순서 변경: Lv.1=가장 어려움 → Lv.1=가장 쉬움
-- 기존: level 1이 최고 난이도 → 변경: level 1이 최저 난이도

-- 서울볼더스: 9단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"white","v_min":"vBbb","v_max":"vBbb"},
  {"level":2,"color":"orange","v_min":"vBb","v_max":"vBb"},
  {"level":3,"color":"yellow","v_min":"v0","v_max":"vB"},
  {"level":4,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":5,"color":"blue","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"red","v_min":"v4","v_max":"v6"},
  {"level":7,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":8,"color":"gray","v_min":"v7","v_max":"v9"},
  {"level":9,"color":"brown","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '서울볼더스';

-- 비블럭: 9단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"white","v_min":"vBbb","v_max":"vBbb"},
  {"level":2,"color":"yellow","v_min":"vBb","v_max":"vBb"},
  {"level":3,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":4,"color":"pink","v_min":"v1","v_max":"v3"},
  {"level":5,"color":"skyBlue","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"green","v_min":"v4","v_max":"v6"},
  {"level":7,"color":"red","v_min":"v6","v_max":"v7"},
  {"level":8,"color":"navy","v_min":"v7","v_max":"v9"},
  {"level":9,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '비블럭';

-- 클라이밍파크: 9단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"yellow","v_min":"vBbb","v_max":"vBbb"},
  {"level":2,"color":"pink","v_min":"vBb","v_max":"vBb"},
  {"level":3,"color":"blue","v_min":"v0","v_max":"vB"},
  {"level":4,"color":"red","v_min":"v1","v_max":"v3"},
  {"level":5,"color":"purple","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"brown","v_min":"v4","v_max":"v6"},
  {"level":7,"color":"gray","v_min":"v6","v_max":"v7"},
  {"level":8,"color":"black","v_min":"v7","v_max":"v9"},
  {"level":9,"color":"white","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '클라이밍파크';

-- 오프더월: 10단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"red","v_min":"vBbb","v_max":"vBbb"},
  {"level":2,"color":"orange","v_min":"vBb","v_max":"vBb"},
  {"level":3,"color":"yellow","v_min":"v0","v_max":"vB"},
  {"level":4,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":5,"color":"blue","v_min":"v3","v_max":"v4"},
  {"level":6,"color":"navy","v_min":"v4","v_max":"v5"},
  {"level":7,"color":"purple","v_min":"v5","v_max":"v6"},
  {"level":8,"color":"gray","v_min":"v6","v_max":"v7"},
  {"level":9,"color":"brown","v_min":"v8","v_max":"v9"},
  {"level":10,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '오프더월';

-- 서울숲: 10단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"pink","v_min":"vBbb","v_max":"vBbb"},
  {"level":2,"color":"red","v_min":"vBb","v_max":"vBb"},
  {"level":3,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":4,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":5,"color":"green","v_min":"v3","v_max":"v4"},
  {"level":6,"color":"blue","v_min":"v4","v_max":"v5"},
  {"level":7,"color":"navy","v_min":"v5","v_max":"v6"},
  {"level":8,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":9,"color":"brown","v_min":"v8","v_max":"v9"},
  {"level":10,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '서울숲';

-- 캐치스톤: 10단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"white","v_min":"vBbbbb","v_max":"vBbbbb"},
  {"level":2,"color":"red","v_min":"vBbb","v_max":"vBbb"},
  {"level":3,"color":"orange","v_min":"vBb","v_max":"vBb"},
  {"level":4,"color":"yellow","v_min":"v0","v_max":"vB"},
  {"level":5,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":6,"color":"blue","v_min":"v3","v_max":"v5"},
  {"level":7,"color":"navy","v_min":"v4","v_max":"v6"},
  {"level":8,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":9,"color":"black","v_min":"v7","v_max":"v9"},
  {"level":10,"color":"rainbow","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '캐치스톤';

-- 피커스: 8단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"red","v_min":"vBb","v_max":"vBb"},
  {"level":2,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":3,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":4,"color":"green","v_min":"v3","v_max":"v5"},
  {"level":5,"color":"blue","v_min":"v4","v_max":"v6"},
  {"level":6,"color":"navy","v_min":"v6","v_max":"v7"},
  {"level":7,"color":"purple","v_min":"v7","v_max":"v9"},
  {"level":8,"color":"gray","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '피커스';

-- 더클라임: 11단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"white","v_min":"vBbb","v_max":"vBbb"},
  {"level":2,"color":"orange","v_min":"vBb","v_max":"vBb"},
  {"level":3,"color":"yellow","v_min":"v0","v_max":"vB"},
  {"level":4,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":5,"color":"blue","v_min":"v3","v_max":"v4"},
  {"level":6,"color":"red","v_min":"v4","v_max":"v5"},
  {"level":7,"color":"pink","v_min":"v5","v_max":"v6"},
  {"level":8,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":9,"color":"gray","v_min":"v7","v_max":"v8"},
  {"level":10,"color":"brown","v_min":"v8","v_max":"v9"},
  {"level":11,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '더클라임';

-- 더플라스틱: 8단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"red","v_min":"vBb","v_max":"vBb"},
  {"level":2,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":3,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":4,"color":"green","v_min":"v3","v_max":"v5"},
  {"level":5,"color":"skyBlue","v_min":"v4","v_max":"v6"},
  {"level":6,"color":"navy","v_min":"v6","v_max":"v7"},
  {"level":7,"color":"purple","v_min":"v7","v_max":"v9"},
  {"level":8,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '더플라스틱';

-- 에어즈락: 7단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"pink","v_min":"vBb","v_max":"vBb"},
  {"level":2,"color":"white","v_min":"v0","v_max":"vB"},
  {"level":3,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":4,"color":"blue","v_min":"v4","v_max":"v6"},
  {"level":5,"color":"green","v_min":"v6","v_max":"v7"},
  {"level":6,"color":"red","v_min":"v7","v_max":"v9"},
  {"level":7,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '에어즈락';

-- 알레: 8단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"yellow","v_min":"vBb","v_max":"vBb"},
  {"level":2,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":3,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":4,"color":"blue","v_min":"v3","v_max":"v5"},
  {"level":5,"color":"red","v_min":"v4","v_max":"v6"},
  {"level":6,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":7,"color":"white","v_min":"v7","v_max":"v9"},
  {"level":8,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '알레';

-- 훅클라이밍: 8단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"red","v_min":"vBb","v_max":"vBb"},
  {"level":2,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":3,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":4,"color":"green","v_min":"v3","v_max":"v5"},
  {"level":5,"color":"blue","v_min":"v4","v_max":"v6"},
  {"level":6,"color":"navy","v_min":"v6","v_max":"v7"},
  {"level":7,"color":"purple","v_min":"v7","v_max":"v9"},
  {"level":8,"color":"star","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '훅클라이밍';

-- 클라임어스: 9단계
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"red","v_min":"vBbb","v_max":"vBbb"},
  {"level":2,"color":"orange","v_min":"vBb","v_max":"vBb"},
  {"level":3,"color":"yellow","v_min":"v0","v_max":"vB"},
  {"level":4,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":5,"color":"skyBlue","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"navy","v_min":"v4","v_max":"v6"},
  {"level":7,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":8,"color":"white","v_min":"v7","v_max":"v9"},
  {"level":9,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '클라임어스';

-- 클라이밍짐 추가: 9단계
-- 빨강(초급) → 주황 → 노랑 → 초록 → 파랑 → 남색 → 보라 → 흰색 → 검정(최상위)
INSERT INTO gym_color_scales (brand_name, levels) VALUES
('클라이밍짐', '[
  {"level":1,"color":"red","v_min":"vBb","v_max":"vBb"},
  {"level":2,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":3,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":4,"color":"green","v_min":"v3","v_max":"v4"},
  {"level":5,"color":"blue","v_min":"v4","v_max":"v5"},
  {"level":6,"color":"navy","v_min":"v5","v_max":"v6"},
  {"level":7,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":8,"color":"white","v_min":"v7","v_max":"v9"},
  {"level":9,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb);
