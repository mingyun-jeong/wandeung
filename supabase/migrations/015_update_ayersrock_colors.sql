-- 에어즈락 난이도 변경: 8단계
-- 빨강(초급) → 주황 → 노랑 → 초록 → 파랑 → 남색 → 보라 → 검정(최상위)
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"red","v_min":"vBb","v_max":"vBb"},
  {"level":2,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":3,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":4,"color":"green","v_min":"v3","v_max":"v5"},
  {"level":5,"color":"blue","v_min":"v4","v_max":"v6"},
  {"level":6,"color":"navy","v_min":"v6","v_max":"v7"},
  {"level":7,"color":"purple","v_min":"v7","v_max":"v9"},
  {"level":8,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '에어즈락';

-- 서울볼더스 난이도 변경: 8단계
-- 빨강(초급) → 주황 → 노랑 → 초록 → 파랑 → 남색 → 보라 → 검정(최상위)
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"red","v_min":"vBb","v_max":"vBb"},
  {"level":2,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":3,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":4,"color":"green","v_min":"v3","v_max":"v5"},
  {"level":5,"color":"blue","v_min":"v4","v_max":"v6"},
  {"level":6,"color":"navy","v_min":"v6","v_max":"v7"},
  {"level":7,"color":"purple","v_min":"v7","v_max":"v9"},
  {"level":8,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '서울볼더스';

-- 비블럭 난이도 변경: 10단계
-- 흰색(초급) → 노랑 → 주황 → 분홍 → 하늘 → 회색 → 초록 → 빨강 → 남색 → 검정(최상위)
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"white","v_min":"vBbb","v_max":"vBbb"},
  {"level":2,"color":"yellow","v_min":"vBb","v_max":"vBb"},
  {"level":3,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":4,"color":"pink","v_min":"v1","v_max":"v2"},
  {"level":5,"color":"skyBlue","v_min":"v2","v_max":"v3"},
  {"level":6,"color":"gray","v_min":"v3","v_max":"v4"},
  {"level":7,"color":"green","v_min":"v4","v_max":"v5"},
  {"level":8,"color":"red","v_min":"v5","v_max":"v7"},
  {"level":9,"color":"navy","v_min":"v7","v_max":"v9"},
  {"level":10,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '비블럭';

-- 캐치스톤 난이도 변경: 10단계
-- 흰색(초급) → 노랑 → 주황 → 초록 → 파랑 → 빨강 → 보라 → 회색 → 갈색 → 검정(최상위)
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"white","v_min":"vBbb","v_max":"vBbb"},
  {"level":2,"color":"yellow","v_min":"vBb","v_max":"vBb"},
  {"level":3,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":4,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":5,"color":"blue","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"red","v_min":"v4","v_max":"v6"},
  {"level":7,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":8,"color":"gray","v_min":"v7","v_max":"v8"},
  {"level":9,"color":"brown","v_min":"v8","v_max":"v9"},
  {"level":10,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '캐치스톤';

-- 피커스 난이도 변경: 9단계
-- 빨강(초급) → 주황 → 노랑 → 초록 → 파랑 → 남색 → 보라 → 회색 → 검정(최상위)
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"red","v_min":"vBb","v_max":"vBb"},
  {"level":2,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":3,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":4,"color":"green","v_min":"v3","v_max":"v5"},
  {"level":5,"color":"blue","v_min":"v4","v_max":"v6"},
  {"level":6,"color":"navy","v_min":"v6","v_max":"v7"},
  {"level":7,"color":"purple","v_min":"v7","v_max":"v8"},
  {"level":8,"color":"gray","v_min":"v8","v_max":"v9"},
  {"level":9,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb
WHERE brand_name = '피커스';

-- 더플라스틱 난이도 변경: 8단계
-- 흰색(입문) → 노랑(초급) → 주황 → 초록(중급) → 파랑 → 빨강 → 보라(고급) → 검정(최상급)
UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"white","v_min":"vBbb","v_max":"vBbb"},
  {"level":2,"color":"yellow","v_min":"vBb","v_max":"vBb"},
  {"level":3,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":4,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":5,"color":"blue","v_min":"v3","v_max":"v5"},
  {"level":6,"color":"red","v_min":"v4","v_max":"v6"},
  {"level":7,"color":"purple","v_min":"v5","v_max":"v6"},
  {"level":8,"color":"black","v_min":"v7","v_max":"v10"}
]'::jsonb
WHERE brand_name = '더플라스틱';
