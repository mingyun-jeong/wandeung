// 구독 영수증 서버사이드 검증 Edge Function (스텁)
//
// Google Play Developer API를 사용하여 구독 구매를 검증하고
// user_subscriptions 테이블을 업데이트합니다.
//
// 실제 구현 시:
// 1. Google Play Developer API 서비스 계정 키 설정
// 2. purchases.subscriptions.get 호출하여 구독 상태 확인
// 3. user_subscriptions 테이블 upsert

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { userId, purchaseToken, productId } = await req.json()

    if (!userId || !purchaseToken || !productId) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // TODO: Google Play Developer API로 purchaseToken 검증
    // const isValid = await verifyWithGooglePlay(purchaseToken, productId)

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const now = new Date()
    const expiresAt = new Date(now)
    if (productId === 'pro_yearly') {
      expiresAt.setFullYear(expiresAt.getFullYear() + 1)
    } else {
      expiresAt.setMonth(expiresAt.getMonth() + 1)
    }

    const { error } = await supabase
      .from('user_subscriptions')
      .upsert({
        user_id: userId,
        plan: 'pro',
        status: 'active',
        platform: 'android',
        store_transaction_id: purchaseToken,
        started_at: now.toISOString(),
        expires_at: expiresAt.toISOString(),
        updated_at: now.toISOString(),
      }, { onConflict: 'user_id' })

    if (error) throw error

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
