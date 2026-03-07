-- climbing_records.gym_id 인덱스 추가 (JOIN 및 NOT NULL 필터 성능 개선)
CREATE INDEX idx_records_gym_id ON climbing_records(gym_id);
