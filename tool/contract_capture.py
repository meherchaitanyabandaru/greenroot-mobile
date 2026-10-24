"""Capture real API responses as contract-test fixtures.

The app parses API JSON by hand, so a renamed or removed field shows up as a
blank on screen, not as an error. test/contract/ parses these real responses
with the app's own models and checks the fields screens rely on.

Read-only: GET requests as the dev cast (OTP 123456). Run against a local API
with the dev data loaded (greenroot-infra seed + the e2e cast), then commit the
changed fixtures together with the model change that needs them:

    python3 -I tool/contract_capture.py [http://localhost:8080]
"""
import json
import os
import subprocess
import sys
import urllib.request

API = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080") + "/api/v1"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "test", "contract", "fixtures")

OWNER, BUYER, SELLER2 = "7010000001", "7010000002", "7010000011"


def call(method, path, token=None, body=None):
    req = urllib.request.Request(
        API + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Content-Type": "application/json", **({"Authorization": "Bearer " + token} if token else {})},
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read() or b"null")


def login(mobile):
    # Local dev only: rate limits would otherwise trip on repeated runs.
    subprocess.run(["sh", "-c", "redis-cli --scan --pattern 'rl:*' | xargs redis-cli del >/dev/null 2>&1"])
    call("POST", "/auth/send-otp", body={"mobile": mobile})
    return call("POST", "/auth/verify-otp", body={"mobile": mobile, "otp": "123456"})["access_token"]


DROP = {"provider_signature", "raw_response"}  # never needed by the app; keep out of git


def clean(value):
    """Fixtures must not depend on this machine or carry payment proofs."""
    if isinstance(value, dict):
        return {k: clean(v) for k, v in value.items() if k not in DROP}
    if isinstance(value, list):
        return [clean(v) for v in value]
    if isinstance(value, str) and value.startswith("http://") and ":9000/" in value:
        return "https://files.example.com/" + value.split(":9000/", 1)[1]
    return value


def save(name, data):
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        json.dump(clean(data), f, indent=2, sort_keys=True, ensure_ascii=False)
        f.write("\n")
    print("saved", name)


def first(items, pred=lambda _: True):
    found = next((x for x in items if pred(x)), None)
    if found is None:
        sys.exit("dev data is missing a record this capture needs; see the docstring")
    return found


def main():
    os.makedirs(OUT, exist_ok=True)
    owner, buyer, seller2 = login(OWNER), login(BUYER), login(SELLER2)

    me = call("GET", "/users/me", buyer)
    save("users_me", me)
    save("workspaces_owner", call("GET", "/me/workspaces", owner))
    save("workspaces_buyer", call("GET", "/me/workspaces", buyer))
    save("users_me_owner", call("GET", "/users/me", owner))

    quotations = call("GET", "/quotations?per_page=5", owner)
    save("quotations_list", quotations)
    save("quotation_detail", call("GET", f"/quotations/{first(quotations['quotations'])['id']}", owner))

    orders = call("GET", "/orders?per_page=10", owner)
    save("orders_list", orders)
    done = first(orders["orders"], lambda o: o["order_status"] == "COMPLETED")
    save("order_detail", call("GET", f"/orders/{done['id']}", owner))

    trips = call("GET", "/dispatches?buying=true&per_page=10", buyer)
    save("dispatches_buyer_list", trips)
    on_way = first(trips["dispatches"], lambda d: d["dispatch_status"] in ("DISPATCHED", "IN_TRANSIT"))
    delivered = first(trips["dispatches"], lambda d: d["dispatch_status"] == "DELIVERED")
    save("dispatch_buyer_on_the_way", call("GET", f"/dispatches/{on_way['id']}", buyer))
    save("dispatch_seller_delivered", call("GET", f"/dispatches/{delivered['id']}", owner))

    subs = call("GET", "/subscriptions/me", owner)
    save("subscriptions_me", subs)
    save("subscription_plans", call("GET", "/subscription-plans", owner))
    save("subscription_payments", call("GET", f"/subscriptions/{first(subs['subscriptions'])['id']}/payments", owner))

    # Near the dev cast's Guava ad (pinned in Rajahmundry by the emulator's GPS).
    ads = call("GET", "/market/ads?near_lat=17.00050&near_lon=81.80400&radius_km=100", seller2)
    save("market_ads", ads)
    save("market_ad_detail", call("GET", f"/market/ads/{first(ads['ads'])['id']}", seller2))
    save("market_enquiries", call("GET", "/market/enquiries?direction=received&per_page=10", owner))

    save("notifications", call("GET", "/notifications?per_page=10", buyer))
    save("addresses", call("GET", f"/users/{me['user']['id']}/addresses", buyer))
    save("nursery_detail", call("GET", "/nurseries/1", owner))


if __name__ == "__main__":
    main()
