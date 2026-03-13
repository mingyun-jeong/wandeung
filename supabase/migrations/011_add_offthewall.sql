-- 오프더월 추가: 10단계
-- 빨강(초급) → 주황 → 노랑 → 초록 → 파랑 → 남색 → 보라 → 회색 → 갈색 → 검정(최상위)
INSERT INTO gym_color_scales (brand_name, levels) VALUES
('오프더월', '[
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
]'::jsonb);
