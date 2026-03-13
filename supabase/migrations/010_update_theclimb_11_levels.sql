-- 더클라임 등급 체계 변경: 9단계 → 11단계
-- 변경 사항:
--   1) 최상위에 검정(black) 추가
--   2) 빨강과 보라 사이에 분홍(pink) 추가
-- 숫자와 색상을 함께 표시하는 방식으로 변경

UPDATE gym_color_scales
SET levels = '[
  {"level":1,"color":"black","v_min":"v10","v_max":"v10"},
  {"level":2,"color":"brown","v_min":"v8","v_max":"v9"},
  {"level":3,"color":"gray","v_min":"v7","v_max":"v8"},
  {"level":4,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":5,"color":"pink","v_min":"v5","v_max":"v6"},
  {"level":6,"color":"red","v_min":"v4","v_max":"v5"},
  {"level":7,"color":"blue","v_min":"v3","v_max":"v4"},
  {"level":8,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":9,"color":"yellow","v_min":"v0","v_max":"vB"},
  {"level":10,"color":"orange","v_min":"vBb","v_max":"vBb"},
  {"level":11,"color":"white","v_min":"vBbb","v_max":"vBbb"}
]'::jsonb
WHERE brand_name = '더클라임';

-- 서울숲클라이밍 추가: 10단계
-- 핑크(초급) → 빨강 → 주황 → 노랑 → 초록 → 파랑 → 남색 → 보라 → 갈색 → 검정(최상위)
INSERT INTO gym_color_scales (brand_name, levels) VALUES
('서울숲', '[
  {"level":1,"color":"black","v_min":"v10","v_max":"v10"},
  {"level":2,"color":"brown","v_min":"v8","v_max":"v9"},
  {"level":3,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":4,"color":"navy","v_min":"v5","v_max":"v6"},
  {"level":5,"color":"blue","v_min":"v4","v_max":"v5"},
  {"level":6,"color":"green","v_min":"v3","v_max":"v4"},
  {"level":7,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":8,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":9,"color":"red","v_min":"vBb","v_max":"vBb"},
  {"level":10,"color":"pink","v_min":"vBbb","v_max":"vBbb"}
]'::jsonb);
