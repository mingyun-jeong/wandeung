-- 알레 클라이밍 추가: 8단계
-- 노랑(입문) → 주황 → 초록 → 파랑 → 빨강 → 보라 → 흰색 → 검정(최상위)
INSERT INTO gym_color_scales (brand_name, levels) VALUES
('알레', '[
  {"level":1,"color":"yellow","v_min":"vBb","v_max":"vBb"},
  {"level":2,"color":"orange","v_min":"v0","v_max":"vB"},
  {"level":3,"color":"green","v_min":"v1","v_max":"v3"},
  {"level":4,"color":"blue","v_min":"v3","v_max":"v5"},
  {"level":5,"color":"red","v_min":"v4","v_max":"v6"},
  {"level":6,"color":"purple","v_min":"v6","v_max":"v7"},
  {"level":7,"color":"white","v_min":"v7","v_max":"v9"},
  {"level":8,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb);
