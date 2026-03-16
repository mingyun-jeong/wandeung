// 6개월 TTL 클린업 Edge Function (스텁)
//
// Cron 또는 수동 호출로 실행하여
// created_at 기준 6개월 경과한 레코드의 R2 오브젝트를 삭제하고
// video_path, thumbnail_path를 null 처리합니다.
//
// DB 레코드 자체는 유지 (기록/통계 보존)

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (_req) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // 6개월 전 날짜 계산
    const sixMonthsAgo = new Date()
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6)

    // 만료된 레코드 조회 (video_path가 있는 것만)
    const { data: expiredRecords, error: fetchError } = await supabase
      .from('climbing_records')
      .select('id, user_id, video_path, thumbnail_path')
      .lt('created_at', sixMonthsAgo.toISOString())
      .not('video_path', 'is', null)
      .not('video_path', 'like', '/%') // 로컬 경로 제외

    if (fetchError) throw fetchError

    let cleaned = 0
    for (const record of expiredRecords || []) {
      // TODO: R2 API로 실제 파일 삭제
      // await deleteFromR2(record.video_path)
      // await deleteFromR2(record.thumbnail_path)

      // DB에서 경로 null 처리
      const { error } = await supabase
        .from('climbing_records')
        .update({
          video_path: null,
          thumbnail_path: null,
          file_size_bytes: null,
        })
        .eq('id', record.id)

      if (!error) cleaned++
    }

    return new Response(
      JSON.stringify({ cleaned, total: expiredRecords?.length || 0 }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
