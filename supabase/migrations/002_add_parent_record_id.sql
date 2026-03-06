-- 내보내기 영상의 원본 기록 참조
ALTER TABLE climbing_records
  ADD COLUMN parent_record_id UUID REFERENCES climbing_records(id) ON DELETE CASCADE;

CREATE INDEX idx_records_parent ON climbing_records(parent_record_id);
