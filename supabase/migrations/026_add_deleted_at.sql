-- soft delete: deleted_at 컬럼 추가
ALTER TABLE climbing_records ADD COLUMN deleted_at TIMESTAMPTZ;

-- 삭제되지 않은 레코드만 조회하도록 RLS 정책 교체
DROP POLICY IF EXISTS "Users can CRUD own records" ON climbing_records;

CREATE POLICY "Users can CRUD own records"
  ON climbing_records FOR ALL
  USING (auth.uid() = user_id AND deleted_at IS NULL)
  WITH CHECK (auth.uid() = user_id);

-- 삭제된 레코드도 update 가능 (soft delete 실행용)
CREATE POLICY "Users can soft delete own records"
  ON climbing_records FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
