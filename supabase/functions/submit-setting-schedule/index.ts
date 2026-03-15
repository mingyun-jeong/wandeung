import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    // 인증 확인
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return Response.json(
        { error: "인증이 필요합니다" },
        { status: 401, headers: corsHeaders },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return Response.json(
        { error: "인증 실패" },
        { status: 401, headers: corsHeaders },
      );
    }

    const body = await req.json();
    const { gym_id, year_month, sectors, source_image_base64 } = body;

    if (!gym_id || !year_month || !sectors) {
      return Response.json(
        { error: "gym_id, year_month, sectors는 필수입니다" },
        { status: 400, headers: corsHeaders },
      );
    }

    // Service role 클라이언트 (Storage 업로드 + RLS 우회 upsert용)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 이미지 Storage 업로드
    let sourceImageUrl: string | null = null;
    if (source_image_base64) {
      const binaryStr = atob(source_image_base64);
      const bytes = new Uint8Array(binaryStr.length);
      for (let i = 0; i < binaryStr.length; i++) {
        bytes[i] = binaryStr.charCodeAt(i);
      }

      const filePath = `setting-schedules/${user.id}/${Date.now()}.jpg`;
      const { error: uploadError } = await supabaseAdmin.storage
        .from("climbing-videos")
        .upload(filePath, bytes, {
          contentType: "image/jpeg",
          upsert: true,
        });

      if (!uploadError) {
        sourceImageUrl = filePath;
      }
    }

    // DB upsert (같은 gym_id + year_month이면 업데이트)
    const record = {
      gym_id,
      year_month,
      sectors,
      submitted_by: user.id,
      status: "approved",
      updated_at: new Date().toISOString(),
      ...(sourceImageUrl && { source_image_url: sourceImageUrl }),
    };

    const { data, error: upsertError } = await supabaseAdmin
      .from("gym_setting_schedules")
      .upsert(record, { onConflict: "gym_id,year_month" })
      .select()
      .single();

    if (upsertError) {
      console.error("Upsert error:", upsertError);
      return Response.json(
        { error: `저장 실패: ${upsertError.message}` },
        { status: 500, headers: corsHeaders },
      );
    }

    // 기여자 기록
    await supabaseAdmin
      .from("setting_schedule_contributors")
      .upsert(
        { user_id: user.id, schedule_id: data.id },
        { onConflict: "user_id,schedule_id" },
      );

    return Response.json(data, { headers: corsHeaders });
  } catch (e) {
    console.error("Error:", e);
    return Response.json(
      { error: `등록 실패: ${e.message}` },
      { status: 500, headers: corsHeaders },
    );
  }
});
