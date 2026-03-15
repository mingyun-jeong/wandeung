-- 클라우드 업로드 OFF 상태에서 저장된 레코드를 구분하기 위한 플래그
ALTER TABLE climbing_records
ADD COLUMN local_only boolean NOT NULL DEFAULT false;
