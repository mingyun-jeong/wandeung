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

    // multipart/form-data에서 이미지 추출
    const formData = await req.formData();
    const imageFile = formData.get("image") as File;
    if (!imageFile) {
      return Response.json(
        { error: "이미지가 필요합니다" },
        { status: 400, headers: corsHeaders },
      );
    }

    const imageBytes = await imageFile.arrayBuffer();
    const base64Image = btoa(
      String.fromCharCode(...new Uint8Array(imageBytes)),
    );

    // GPT-4o mini Vision API 호출
    const openaiApiKey = Deno.env.get("OPENAI_API_KEY");
    if (!openaiApiKey) {
      return Response.json(
        { error: "OpenAI API 키가 설정되지 않았습니다" },
        { status: 500, headers: corsHeaders },
      );
    }

    const gptResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${openaiApiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: `실내 클라이밍장 세팅 일정 이미지를 분석하는 AI입니다.
반드시 아래 JSON 형식으로만 응답하세요.

{
  "gym_name": "암장명 (지점 포함)",
  "gym_brand": "브랜드명 (없으면 null)",
  "year_month": "YYYY-MM",
  "sectors": [
    {"name": "섹터명", "dates": ["YYYY-MM-DD", ...]}
  ]
}

- 이미지에서 암장 이름, 월, 섹터별 세팅 날짜를 추출하세요
- 색상으로 구분된 섹터는 색상-섹터 매칭을 시도하세요
- 확실하지 않은 정보는 빈 값으로 남겨주세요`,
          },
          {
            role: "user",
            content: [
              {
                type: "image_url",
                image_url: {
                  url: `data:image/jpeg;base64,${base64Image}`,
                },
              },
              {
                type: "text",
                text: "이 이미지에서 클라이밍장 세팅 일정을 추출해주세요.",
              },
            ],
          },
        ],
        max_tokens: 1000,
        temperature: 0.1,
      }),
    });

    if (!gptResponse.ok) {
      const errorBody = await gptResponse.text();
      console.error("GPT API error:", errorBody);
      return Response.json(
        { error: "AI 분석에 실패했습니다" },
        { status: 500, headers: corsHeaders },
      );
    }

    const gptData = await gptResponse.json();
    const content = gptData.choices?.[0]?.message?.content ?? "";

    // JSON 파싱 (코드블록 제거)
    const jsonStr = content.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim();
    const parsed = JSON.parse(jsonStr);

    return Response.json(parsed, { headers: corsHeaders });
  } catch (e) {
    console.error("Error:", e);
    return Response.json(
      { error: `파싱 실패: ${e.message}` },
      { status: 500, headers: corsHeaders },
    );
  }
});
