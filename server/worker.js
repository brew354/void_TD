/**
 * Void TD — Code Redemption Worker
 *
 * KV schema: each key is a code string, value is JSON:
 *   { reward, max_uses, uses, ...payload }
 *
 * POST /redeem  { code }
 * → { ok: true,  reward, ...payload }
 * → { ok: false, error: "invalid" | "max_uses" | "already_redeemed", limit? }
 */

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return corsResponse(new Response(null, { status: 204 }));
    }

    const url = new URL(request.url);

    if (url.pathname === "/redeem" && request.method === "POST") {
      return corsResponse(await handleRedeem(request, env));
    }

    if (url.pathname === "/admin/create" && request.method === "POST") {
      return corsResponse(await handleAdminCreate(request, env));
    }

    return corsResponse(new Response(JSON.stringify({ ok: false, error: "not_found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    }));
  },
};

async function handleRedeem(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ ok: false, error: "invalid" }, 400);
  }

  const code = (body.code || "").trim().toLowerCase();
  if (!code) {
    return jsonResponse({ ok: false, error: "invalid" }, 400);
  }

  const raw = await env.CODES.get(code);
  if (!raw) {
    return jsonResponse({ ok: false, error: "invalid" });
  }

  const data = JSON.parse(raw);

  if (data.max_uses > 0 && data.uses >= data.max_uses) {
    return jsonResponse({ ok: false, error: "max_uses", limit: data.max_uses });
  }

  data.uses = (data.uses || 0) + 1;
  await env.CODES.put(code, JSON.stringify(data));

  const { max_uses, uses, ...payload } = data;
  return jsonResponse({ ok: true, ...payload });
}

async function handleAdminCreate(request, env) {
  const authHeader = request.headers.get("Authorization") || "";
  if (authHeader !== `Bearer ${env.ADMIN_TOKEN}`) {
    return jsonResponse({ ok: false, error: "unauthorized" }, 401);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ ok: false, error: "bad_request" }, 400);
  }

  const code = (body.code || "").trim().toLowerCase();
  if (!code || !body.reward) {
    return jsonResponse({ ok: false, error: "missing code or reward" }, 400);
  }

  const entry = {
    reward: body.reward,
    max_uses: body.max_uses || 0,
    uses: 0,
    ...body.payload,
  };

  await env.CODES.put(code, JSON.stringify(entry));
  return jsonResponse({ ok: true, code, entry });
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function corsResponse(response) {
  const headers = new Headers(response.headers);
  headers.set("Access-Control-Allow-Origin", "*");
  headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  return new Response(response.body, {
    status: response.status,
    headers,
  });
}
