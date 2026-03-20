import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  // GET: 삭제 요청 폼 페이지
  if (req.method === "GET") {
    return new Response(HTML_PAGE, {
      headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
    });
  }

  // POST: 삭제 처리
  if (req.method === "POST") {
    try {
      const { email } = await req.json();
      if (!email) {
        return Response.json(
          { error: "이메일을 입력해주세요." },
          { status: 400, headers: corsHeaders },
        );
      }

      const supabaseAdmin = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      );

      // 이메일로 사용자 조회
      const { data: { users }, error: listError } =
        await supabaseAdmin.auth.admin.listUsers();
      if (listError) throw listError;

      const user = users.find((u) => u.email === email);
      if (!user) {
        return Response.json(
          { error: "해당 이메일로 등록된 계정을 찾을 수 없습니다." },
          { status: 404, headers: corsHeaders },
        );
      }

      const userId = user.id;

      // 스토리지 영상 삭제
      try {
        const { data: files } = await supabaseAdmin.storage
          .from("climbing-videos")
          .list(userId);
        if (files && files.length > 0) {
          const paths = files.map((f) => `${userId}/${f.name}`);
          await supabaseAdmin.storage.from("climbing-videos").remove(paths);
        }
      } catch (_) {
        // 스토리지 삭제 실패해도 계속 진행
      }

      // 등반 기록 삭제
      await supabaseAdmin
        .from("climbing_records")
        .delete()
        .eq("user_id", userId);

      // 사용자가 생성한 암장 삭제
      await supabaseAdmin
        .from("climbing_gyms")
        .delete()
        .eq("created_by", userId);

      // auth 계정 삭제
      const { error: deleteError } =
        await supabaseAdmin.auth.admin.deleteUser(userId);
      if (deleteError) throw deleteError;

      return Response.json(
        { message: "계정이 성공적으로 삭제되었습니다." },
        { headers: corsHeaders },
      );
    } catch (e) {
      return Response.json(
        { error: `계정 삭제 실패: ${e.message}` },
        { status: 500, headers: corsHeaders },
      );
    }
  }

  return new Response("Method not allowed", { status: 405, headers: corsHeaders });
});

const HTML_PAGE = `<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>리클림 - 계정 삭제</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: #f5f5f5;
      color: #1a1a1a;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .container {
      background: white;
      border-radius: 16px;
      padding: 40px 32px;
      max-width: 420px;
      width: 100%;
      box-shadow: 0 2px 12px rgba(0,0,0,0.08);
    }
    h1 {
      font-size: 24px;
      font-weight: 800;
      margin-bottom: 8px;
    }
    .subtitle {
      color: #666;
      font-size: 14px;
      margin-bottom: 28px;
      line-height: 1.5;
    }
    .warning {
      background: #fef2f2;
      border: 1px solid #fecaca;
      border-radius: 10px;
      padding: 14px 16px;
      margin-bottom: 24px;
      font-size: 13px;
      color: #991b1b;
      line-height: 1.5;
    }
    label {
      font-size: 14px;
      font-weight: 600;
      display: block;
      margin-bottom: 6px;
    }
    input[type="email"] {
      width: 100%;
      padding: 12px 14px;
      border: 1px solid #ddd;
      border-radius: 10px;
      font-size: 15px;
      outline: none;
      transition: border-color 0.2s;
    }
    input[type="email"]:focus { border-color: #0d9488; }
    button {
      width: 100%;
      padding: 14px;
      background: #dc2626;
      color: white;
      border: none;
      border-radius: 10px;
      font-size: 15px;
      font-weight: 600;
      cursor: pointer;
      margin-top: 20px;
      transition: background 0.2s;
    }
    button:hover { background: #b91c1c; }
    button:disabled { background: #999; cursor: not-allowed; }
    .result {
      margin-top: 16px;
      padding: 12px 14px;
      border-radius: 10px;
      font-size: 14px;
      display: none;
    }
    .result.success { background: #f0fdf4; color: #166534; display: block; }
    .result.error { background: #fef2f2; color: #991b1b; display: block; }
  </style>
</head>
<body>
  <div class="container">
    <h1>리클림 계정 삭제</h1>
    <p class="subtitle">리클림 앱에서 사용하신 계정의 삭제를 요청합니다.</p>
    <div class="warning">
      ⚠️ 계정을 삭제하면 모든 등반 기록, 영상, 데이터가 영구적으로 삭제되며 복구할 수 없습니다.
    </div>
    <label for="email">가입한 Google 이메일</label>
    <input type="email" id="email" placeholder="example@gmail.com" />
    <button id="deleteBtn" onclick="handleDelete()">계정 삭제 요청</button>
    <div id="result" class="result"></div>
  </div>
  <script>
    async function handleDelete() {
      const email = document.getElementById('email').value.trim();
      const btn = document.getElementById('deleteBtn');
      const result = document.getElementById('result');

      if (!email) {
        result.className = 'result error';
        result.textContent = '이메일을 입력해주세요.';
        return;
      }

      if (!confirm('정말로 계정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.')) return;

      btn.disabled = true;
      btn.textContent = '처리 중...';
      result.style.display = 'none';

      try {
        const res = await fetch(window.location.href, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email }),
        });
        const data = await res.json();

        if (res.ok) {
          result.className = 'result success';
          result.textContent = data.message;
        } else {
          result.className = 'result error';
          result.textContent = data.error;
        }
      } catch (e) {
        result.className = 'result error';
        result.textContent = '요청 처리 중 오류가 발생했습니다.';
      } finally {
        btn.disabled = false;
        btn.textContent = '계정 삭제 요청';
      }
    }
  </script>
</body>
</html>`;
