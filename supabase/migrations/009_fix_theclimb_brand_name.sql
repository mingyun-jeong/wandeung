-- 008 시드에서 더클라임 brand_name에 SQL 주석이 포함된 버그 수정
UPDATE gym_color_scales
SET brand_name = '더클라임'
WHERE brand_name LIKE '%--%더클라임%';
