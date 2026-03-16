-- 영상 파일 크기 컬럼 추가 (용량 추적용, 바이트 단위)
ALTER TABLE climbing_records ADD COLUMN file_size_bytes BIGINT;
