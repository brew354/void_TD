# Void TD — Code Redemption Server

Cloudflare Worker + KV backend for managing redeemable codes.

## Setup

1. Install Wrangler: `npm install -g wrangler`
2. Authenticate: `wrangler login`
3. Create KV namespace: `wrangler kv namespace create CODES`
4. Copy the namespace ID into `wrangler.toml`
5. Set admin token: `wrangler secret put ADMIN_TOKEN`
6. Deploy: `wrangler deploy`
7. Update `CODE_SERVER_URL` in `Void_TD/Models/TowerSkins.gd` with your Worker URL

## API

### POST /redeem
Client sends `{ "code": "some-code" }`.

Responses:
- `{ "ok": true, "reward": "coins", "amount": 500 }`
- `{ "ok": true, "reward": "skin", "skin_key": "void", "towers": [0, 2, 4] }`
- `{ "ok": true, "reward": "purchase", "skin_key": "tesla_tower" }`
- `{ "ok": true, "reward": "start_wave", "wave": 5 }`
- `{ "ok": false, "error": "invalid" }`
- `{ "ok": false, "error": "max_uses", "limit": 100 }`

### POST /admin/create
Requires `Authorization: Bearer <ADMIN_TOKEN>` header.

```json
{
  "code": "savanfo",
  "reward": "coins",
  "max_uses": 0,
  "payload": { "amount": 800 }
}
```

Set `max_uses` to 0 for unlimited.

## Example: Create codes via curl

```bash
URL="https://void-td-codes.YOUR_SUBDOMAIN.workers.dev"
TOKEN="your-admin-token"

# 800 coins code
curl -X POST "$URL/admin/create" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"code":"savanfo","reward":"coins","max_uses":0,"payload":{"amount":800}}'

# Void skin code
curl -X POST "$URL/admin/create" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"code":"friendvoid","reward":"skin","max_uses":0,"payload":{"skin_key":"void","towers":[0,2,4]}}'
```
