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

    const { user_ids } = await req.json();
    if (!user_ids || !Array.isArray(user_ids) || user_ids.length === 0) {
      return Response.json({}, { headers: corsHeaders });
    }

    // Service role로 auth.users 조회
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: { users }, error: listError } =
      await supabaseAdmin.auth.admin.listUsers();

    if (listError) {
      console.error("List users error:", listError);
      return Response.json({}, { headers: corsHeaders });
    }

    // user_id → email 맵 생성
    const emailMap: Record<string, string> = {};
    const userIdSet = new Set(user_ids);
    for (const u of users) {
      if (userIdSet.has(u.id) && u.email) {
        emailMap[u.id] = u.email;
      }
    }

    return Response.json(emailMap, { headers: corsHeaders });
  } catch (e) {
    console.error("Error:", e);
    return Response.json(
      { error: `조회 실패: ${e.message}` },
      { status: 500, headers: corsHeaders },
    );
  }
});
