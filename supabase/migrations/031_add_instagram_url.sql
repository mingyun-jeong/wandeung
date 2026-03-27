-- climbing_gyms 테이블에 인스타그램 URL 컬럼 추가
ALTER TABLE climbing_gyms ADD COLUMN IF NOT EXISTS instagram_url TEXT;
