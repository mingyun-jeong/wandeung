-- 영상 화질 정보 저장 (720p, 1080p, 4K 등)
ALTER TABLE climbing_records
  ADD COLUMN video_quality TEXT;
