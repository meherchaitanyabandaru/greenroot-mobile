#!/usr/bin/env bash
# Bootstraps live test data for QR scenario testing.
# Requires the API running at http://localhost:8080 with the dev seed loaded.
# Writes codes to scripts/test_qr_values.env

set -euo pipefail
BASE="http://localhost:8080/api/v1"
ENV_OUT="$(dirname "$0")/test_qr_values.env"

echo "==> Checking API health..."
curl -sf http://localhost:8080/health > /dev/null || { echo "ERROR: API not running at localhost:8080"; exit 1; }
echo "   API is healthy"

# ── JWT helpers ───────────────────────────────────────────────────────────────

login() {
  local phone="$1"
  curl -sf -X POST "$BASE/auth/send-otp" -H "Content-Type: application/json" -d "{\"mobile\":\"$phone\"}" > /dev/null
  curl -sf -X POST "$BASE/auth/verify-otp" -H "Content-Type: application/json" \
    -d "{\"mobile\":\"$phone\",\"otp\":\"123456\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])"
}

get_json() {
  curl -sf "$BASE/$1" -H "Authorization: Bearer $2"
}

post_json() {
  curl -sf -X POST "$BASE/$1" -H "Authorization: Bearer $2" -H "Content-Type: application/json" -d "$3"
}

# ── Login ─────────────────────────────────────────────────────────────────────

echo "==> Logging in..."
OWNER_JWT=$(login "9100000000")
MANAGER_JWT=$(login "9200000000")
BUYER_JWT=$(login "9300000000")
DRIVER_JWT=$(login "9400000000")
echo "   All logins OK"

# Get nursery ID (owner's nursery)
OWNER_NURSERY_ID=$(get_json "nurseries/owned" "$OWNER_JWT" | python3 -c "import sys,json; print(json.load(sys.stdin)['nursery']['id'])")
echo "   Owner nursery ID: $OWNER_NURSERY_ID"

# Get buyer user ID
BUYER_USER_ID=$(get_json "users/me" "$BUYER_JWT" | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['id'])")
echo "   Buyer user ID: $BUYER_USER_ID"

# Get a valid plant ID
PLANT_ID=$(get_json "plants" "$OWNER_JWT" | python3 -c "import sys,json; print(json.load(sys.stdin)['plants'][0]['id'])")
echo "   Plant ID: $PLANT_ID"

# ── Invite scenarios ──────────────────────────────────────────────────────────

echo ""
echo "==> Creating MANAGER_INVITE (for accepted → expired scenario)..."
RESP=$(post_json "invites" "$OWNER_JWT" "{\"invite_type\":\"MANAGER_INVITE\",\"nursery_id\":$OWNER_NURSERY_ID,\"target_mobile\":\"9500000099\"}")
MANAGER_INVITE_UUID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['invite']['invite_uuid'])")
echo "   UUID: $MANAGER_INVITE_UUID"

echo "==> Accepting that invite as manager (makes it 'already used')..."
post_json "invites/$MANAGER_INVITE_UUID/accept" "$MANAGER_JWT" '{}' > /dev/null 2>&1 || true
ACCEPTED_INVITE_UUID="$MANAGER_INVITE_UUID"
echo "   Accepted invite UUID: $ACCEPTED_INVITE_UUID"

echo "==> Creating fresh MANAGER_INVITE (valid, PENDING)..."
RESP=$(post_json "invites" "$OWNER_JWT" "{\"invite_type\":\"MANAGER_INVITE\",\"nursery_id\":$OWNER_NURSERY_ID,\"target_mobile\":\"9700000099\"}")
VALID_MANAGER_INVITE_UUID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['invite']['invite_uuid'])")
echo "   Fresh manager UUID: $VALID_MANAGER_INVITE_UUID"

echo "==> Creating CUSTOMER_INVITE (valid, PENDING)..."
RESP=$(post_json "invites" "$OWNER_JWT" "{\"invite_type\":\"CUSTOMER_INVITE\",\"nursery_id\":$OWNER_NURSERY_ID,\"target_mobile\":\"9600000099\"}")
VALID_CUSTOMER_INVITE_UUID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['invite']['invite_uuid'])")
echo "   Customer UUID: $VALID_CUSTOMER_INVITE_UUID"

echo "==> Creating WRONG-TARGET invite (sent to 9800000099, scanned by buyer 9300000000)..."
RESP=$(post_json "invites" "$OWNER_JWT" "{\"invite_type\":\"MANAGER_INVITE\",\"nursery_id\":$OWNER_NURSERY_ID,\"target_mobile\":\"9800000099\"}")
WRONG_TARGET_INVITE_UUID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['invite']['invite_uuid'])")
echo "   Wrong-target UUID: $WRONG_TARGET_INVITE_UUID"

# ── Dispatch scenarios ────────────────────────────────────────────────────────

echo ""
echo "==> Creating order + dispatch (for already-accepted scenario)..."
ORDER_BODY="{\"seller_nursery_id\":$OWNER_NURSERY_ID,\"buyer_user_id\":$BUYER_USER_ID}"
ORDER_ID=$(post_json "orders" "$OWNER_JWT" "$ORDER_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['order']['id'])")
echo "   Order ID: $ORDER_ID"
RESP=$(post_json "dispatches" "$OWNER_JWT" "{\"order_id\":$ORDER_ID}")
ALREADY_ACCEPTED_CODE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['dispatch']['dispatch_code'])")
DISPATCH_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['dispatch']['id'])")
echo "   Dispatch code: $ALREADY_ACCEPTED_CODE"

echo "==> Driver accepts dispatch to make it already-accepted..."
# If already accepted from a prior run, this will 403 — that's fine, we just need it non-PENDING
ACCEPT_RESP=$(curl -s -X POST "$BASE/dispatches/$DISPATCH_ID/accept" \
  -H "Authorization: Bearer $DRIVER_JWT" \
  -H "Content-Type: application/json" -d '{}')
ACCEPT_STATUS=$(echo "$ACCEPT_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('dispatch',{}).get('status',d.get('error',{}).get('code','unknown')))" 2>/dev/null || echo "done")
echo "   Accept result: $ACCEPT_STATUS"

echo "==> Creating second order + dispatch (valid, PENDING)..."
ORDER_ID2=$(post_json "orders" "$OWNER_JWT" "$ORDER_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['order']['id'])")
RESP2=$(post_json "dispatches" "$OWNER_JWT" "{\"order_id\":$ORDER_ID2}")
VALID_DISPATCH_CODE=$(echo "$RESP2" | python3 -c "import sys,json; print(json.load(sys.stdin)['dispatch']['dispatch_code'])")
echo "   Valid dispatch code: $VALID_DISPATCH_CODE"

# ── Quotation verify token ────────────────────────────────────────────────────

echo ""
echo "==> Creating quotation + verify token..."
QUO_BODY="{\"nursery_id\":$OWNER_NURSERY_ID,\"recipient_mobile\":\"9300000000\",\"items\":[{\"plant_id\":$PLANT_ID,\"quantity\":2,\"unit_price\":100,\"total_price\":200}]}"
QUO_ID=$(post_json "quotations" "$OWNER_JWT" "$QUO_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['quotation']['id'])")
echo "   Quotation ID: $QUO_ID"
TOKEN_RESP=$(post_json "quotations/$QUO_ID/verify-token" "$OWNER_JWT" '{}')
VALID_VERIFY_TOKEN=$(echo "$TOKEN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
echo "   Token: ${VALID_VERIFY_TOKEN:0:16}..."

# QR encodes the raw 64-hex token — no URL wrapping
VERIFY_URL="$VALID_VERIFY_TOKEN"

# ── Write env file ────────────────────────────────────────────────────────────

cat > "$ENV_OUT" <<EOF
# Generated by setup_qr_test_data.sh — $(date)

# Invite QR scenarios
VALID_MANAGER_INVITE_UUID=$VALID_MANAGER_INVITE_UUID
VALID_CUSTOMER_INVITE_UUID=$VALID_CUSTOMER_INVITE_UUID
ACCEPTED_INVITE_UUID=$ACCEPTED_INVITE_UUID
WRONG_TARGET_INVITE_UUID=$WRONG_TARGET_INVITE_UUID
NONEXISTENT_UUID=00000000-0000-0000-0000-000000000000

# Dispatch/trip code scenarios
VALID_DISPATCH_CODE=$VALID_DISPATCH_CODE
ALREADY_ACCEPTED_CODE=$ALREADY_ACCEPTED_CODE
NONEXISTENT_CODE=DSP-00000000-9999

# Quotation verify scenarios
VALID_VERIFY_TOKEN=$VALID_VERIFY_TOKEN
INVALID_VERIFY_TOKEN=deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
VERIFY_URL=$VERIFY_URL

# Foreign QR
FOREIGN_QR=https://amazon.com/product/12345
EOF

echo ""
echo "==> Done. Values written to: $ENV_OUT"
cat "$ENV_OUT"
