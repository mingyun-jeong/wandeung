import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const R2_ENDPOINT = Deno.env.get("R2_ENDPOINT")!;
const R2_ACCESS_KEY_ID = Deno.env.get("R2_ACCESS_KEY_ID")!;
const R2_SECRET_ACCESS_KEY = Deno.env.get("R2_SECRET_ACCESS_KEY")!;
const R2_BUCKET_NAME = Deno.env.get("R2_BUCKET_NAME")!;
const R2_HOST = new URL(R2_ENDPOINT).host;
const R2_REGION = "auto";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
};

const encoder = new TextEncoder();

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return Response.json(
      { error: "Unauthorized" },
      { status: 401, headers: corsHeaders },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();
  if (authError || !user) {
    return Response.json(
      { error: "Unauthorized" },
      { status: 401, headers: corsHeaders },
    );
  }

  try {
    const { action, objectKey, prefix, contentType } = await req.json();

    // 보안: 사용자는 자신의 경로만 접근 가능
    if (objectKey && !objectKey.includes(user.id)) {
      return Response.json(
        { error: "Forbidden" },
        { status: 403, headers: corsHeaders },
      );
    }
    if (prefix && !prefix.includes(user.id)) {
      return Response.json(
        { error: "Forbidden" },
        { status: 403, headers: corsHeaders },
      );
    }

    switch (action) {
      case "presign-upload": {
        const url = await generatePresignedUrl(
          objectKey,
          "PUT",
          600,
          contentType,
        );
        return Response.json({ url }, { headers: corsHeaders });
      }

      case "presign-download": {
        const url = await generatePresignedUrl(objectKey, "GET", 3600);
        return Response.json({ url }, { headers: corsHeaders });
      }

      case "delete": {
        await s3Request("DELETE", objectKey);
        return Response.json({ ok: true }, { headers: corsHeaders });
      }

      case "delete-all": {
        const keys = await listObjects(prefix);
        for (const key of keys) {
          await s3Request("DELETE", key);
        }
        return Response.json(
          { ok: true, deleted: keys.length },
          { headers: corsHeaders },
        );
      }

      default:
        return Response.json(
          { error: `Unknown action: ${action}` },
          { status: 400, headers: corsHeaders },
        );
    }
  } catch (e) {
    return Response.json(
      { error: e.message },
      { status: 500, headers: corsHeaders },
    );
  }
});

// --- Presigned URL 생성 ---

async function generatePresignedUrl(
  objectKey: string,
  method: string,
  expireSeconds: number,
  contentType?: string,
): Promise<string> {
  const now = new Date();
  const dateStamp = fmtDateStamp(now);
  const amzDate = fmtAmzDate(now);
  const credential = `${R2_ACCESS_KEY_ID}/${dateStamp}/${R2_REGION}/s3/aws4_request`;

  const encodedKey = objectKey
    .split("/")
    .map((s) => encodeURIComponent(s))
    .join("/");
  const path = `/${R2_BUCKET_NAME}/${encodedKey}`;

  const signedHeaders =
    method === "PUT" && contentType ? "content-type;host" : "host";

  const params: Record<string, string> = {
    "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
    "X-Amz-Credential": credential,
    "X-Amz-Date": amzDate,
    "X-Amz-Expires": expireSeconds.toString(),
    "X-Amz-SignedHeaders": signedHeaders,
  };

  const sortedQuery = Object.entries(params)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join("&");

  const canonicalHeaders =
    method === "PUT" && contentType
      ? `content-type:${contentType}\nhost:${R2_HOST}\n`
      : `host:${R2_HOST}\n`;

  const canonicalRequest = [
    method,
    path,
    sortedQuery,
    canonicalHeaders,
    signedHeaders,
    "UNSIGNED-PAYLOAD",
  ].join("\n");

  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    `${dateStamp}/${R2_REGION}/s3/aws4_request`,
    await sha256Hex(canonicalRequest),
  ].join("\n");

  const signingKey = await getSignatureKey(dateStamp);
  const signature = toHex(
    await hmacSign(signingKey, encoder.encode(stringToSign)),
  );

  return `https://${R2_HOST}${path}?${sortedQuery}&X-Amz-Signature=${signature}`;
}

// --- S3v4 signed request (DELETE / LIST) ---

async function s3Request(method: string, objectKey: string): Promise<string> {
  const now = new Date();
  const dateStamp = fmtDateStamp(now);
  const amzDate = fmtAmzDate(now);

  const encodedKey = objectKey
    .split("/")
    .map((s) => encodeURIComponent(s))
    .join("/");
  const path = `/${R2_BUCKET_NAME}/${encodedKey}`;
  const url = `https://${R2_HOST}${path}`;
  const emptyHash = await sha256Hex("");

  const headers: Record<string, string> = {
    host: R2_HOST,
    "x-amz-content-sha256": emptyHash,
    "x-amz-date": amzDate,
  };

  const signedHeaderKeys = Object.keys(headers).sort().join(";");
  const canonicalHeaders =
    Object.entries(headers)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `${k}:${v}`)
      .join("\n") + "\n";

  const canonicalRequest = [
    method,
    path,
    "",
    canonicalHeaders,
    signedHeaderKeys,
    emptyHash,
  ].join("\n");

  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    `${dateStamp}/${R2_REGION}/s3/aws4_request`,
    await sha256Hex(canonicalRequest),
  ].join("\n");

  const signingKey = await getSignatureKey(dateStamp);
  const signature = toHex(
    await hmacSign(signingKey, encoder.encode(stringToSign)),
  );

  headers[
    "Authorization"
  ] = `AWS4-HMAC-SHA256 Credential=${R2_ACCESS_KEY_ID}/${dateStamp}/${R2_REGION}/s3/aws4_request, SignedHeaders=${signedHeaderKeys}, Signature=${signature}`;

  const res = await fetch(url, { method, headers });
  return await res.text();
}

async function listObjects(prefix: string): Promise<string[]> {
  const now = new Date();
  const dateStamp = fmtDateStamp(now);
  const amzDate = fmtAmzDate(now);

  const qs = `list-type=2&prefix=${encodeURIComponent(prefix)}`;
  const path = `/${R2_BUCKET_NAME}/`;
  const url = `https://${R2_HOST}${path}?${qs}`;
  const emptyHash = await sha256Hex("");

  const headers: Record<string, string> = {
    host: R2_HOST,
    "x-amz-content-sha256": emptyHash,
    "x-amz-date": amzDate,
  };

  const signedHeaderKeys = Object.keys(headers).sort().join(";");
  const canonicalHeaders =
    Object.entries(headers)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `${k}:${v}`)
      .join("\n") + "\n";

  const canonicalRequest = [
    "GET",
    path,
    qs,
    canonicalHeaders,
    signedHeaderKeys,
    emptyHash,
  ].join("\n");

  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    `${dateStamp}/${R2_REGION}/s3/aws4_request`,
    await sha256Hex(canonicalRequest),
  ].join("\n");

  const signingKey = await getSignatureKey(dateStamp);
  const signature = toHex(
    await hmacSign(signingKey, encoder.encode(stringToSign)),
  );

  headers[
    "Authorization"
  ] = `AWS4-HMAC-SHA256 Credential=${R2_ACCESS_KEY_ID}/${dateStamp}/${R2_REGION}/s3/aws4_request, SignedHeaders=${signedHeaderKeys}, Signature=${signature}`;

  const res = await fetch(url, { method: "GET", headers });
  const body = await res.text();

  const keys: string[] = [];
  const regex = /<Key>(.*?)<\/Key>/g;
  let match;
  while ((match = regex.exec(body)) !== null) {
    keys.push(match[1]);
  }
  return keys;
}

// --- Web Crypto helpers ---

async function hmacSign(
  key: ArrayBuffer,
  data: Uint8Array,
): Promise<ArrayBuffer> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return await crypto.subtle.sign("HMAC", cryptoKey, data);
}

async function getSignatureKey(dateStamp: string): Promise<ArrayBuffer> {
  const kDate = await hmacSign(
    encoder.encode(`AWS4${R2_SECRET_ACCESS_KEY}`),
    encoder.encode(dateStamp),
  );
  const kRegion = await hmacSign(kDate, encoder.encode(R2_REGION));
  const kService = await hmacSign(kRegion, encoder.encode("s3"));
  return await hmacSign(kService, encoder.encode("aws4_request"));
}

async function sha256Hex(data: string): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", encoder.encode(data));
  return toHex(hash);
}

function toHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function fmtAmzDate(d: Date): string {
  return d.toISOString().replace(/[-:]/g, "").replace(/\.\d+Z$/, "Z");
}

function fmtDateStamp(d: Date): string {
  return d.toISOString().slice(0, 10).replace(/-/g, "");
}
