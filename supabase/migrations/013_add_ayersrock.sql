-- 에어즈락 추가: 7단계
-- 핑크(초급) → 흰색 → 노랑 → 파랑 → 초록 → 빨강 → 검정(최상위)
INSERT INTO gym_color_scales (brand_name, levels) VALUES
('에어즈락', '[
  {"level":1,"color":"pink","v_min":"vBb","v_max":"vBb"},
  {"level":2,"color":"white","v_min":"v0","v_max":"vB"},
  {"level":3,"color":"yellow","v_min":"v1","v_max":"v3"},
  {"level":4,"color":"blue","v_min":"v4","v_max":"v6"},
  {"level":5,"color":"green","v_min":"v6","v_max":"v7"},
  {"level":6,"color":"red","v_min":"v7","v_max":"v9"},
  {"level":7,"color":"black","v_min":"v10","v_max":"v10"}
]'::jsonb);
