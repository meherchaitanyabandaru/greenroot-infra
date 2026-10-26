#!/usr/bin/env python3
"""Create GreenRoot dev data through the public API only — no SQL.

Every row goes through the same business rules as the apps: sign-up, nursery
approval (which creates the trial subscription), manager and driver invites,
plants picked from the World Flora Online names, top items, a quotation that
becomes an order, loading, a driver's trip, payment, a cancelled order, the
local market (ad, enquiry, reply, report). Each step is checked; the script
stops at the first rule that does not hold.

Run on a fresh database:
    scripts/reset-dbs.sh                                   # schema + master data + admin (flushes Redis)
    (cd ../greenroot-api && go run ./cmd/botanicalnames load)
    (cd ../greenroot-api && APP_ENV=local go run ./cmd/api) &           # SMS/email mock mode: OTP 123456
    python3 scripts/dev-data/seed_dev_data.py [--api http://localhost:8080/api/v1]

Logins afterwards (OTP 123456): 9000000000 admin, 9100000000 owner (Priya Green
Nursery), 9200000000 manager, 9300000000 buyer, 9400000000 driver,
9500000000 second owner (Lakshmi Plants).
"""
import argparse
import base64
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument("--api", default="http://localhost:8080/api/v1", help="API base URL")
API = parser.parse_args().api.rstrip("/")
_count = [0]


def call(method, path, token=None, body=None, expect=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            status, out = r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read()
        status, out = e.code, (json.loads(raw) if raw else {})
    if expect is not None:
        step(f"{method} {path} → {status}", status in (expect if isinstance(expect, tuple) else (expect,)), out)
    return status, out


# A 1x1 PNG standing in for the camera selfie the market requires to sell or
# start a chat.
SELFIE_PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")


def selfie(token, who):
    boundary = "seed-selfie-boundary"
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="avatar"; filename="selfie.png"\r\n'
            "Content-Type: image/png\r\n\r\n").encode() + SELFIE_PNG + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(API + "/users/me/avatar", data=body, method="POST")
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            step(f"{who} takes a profile selfie", resp.status == 200)
    except urllib.error.HTTPError as e:
        step(f"{who} takes a profile selfie (is MinIO running?)", False, e.read()[:200])


def step(label, ok, detail=None):
    if not ok:
        print(f"FAIL  {label}\n      {json.dumps(detail)[:500]}")
        sys.exit(1)
    _count[0] += 1
    print(f"ok    {label}")


_refresh = {}


def login(mobile):
    # The API allows 10 OTP checks per IP per 15 minutes, so each user logs in once.
    call("POST", "/auth/send-otp", body={"mobile": mobile}, expect=200)
    _, body = call("POST", "/auth/verify-otp", body={"mobile": mobile, "otp": "123456"}, expect=200)
    _refresh[mobile] = body["refresh_token"]
    return body["access_token"]


def refresh(mobile):
    """New access token carrying the user's current roles (after approval or an invite)."""
    _, body = call("POST", "/auth/refresh-token", body={"refresh_token": _refresh[mobile]}, expect=200)
    _refresh[mobile] = body.get("refresh_token", _refresh[mobile])
    return body["access_token"]


def profile(token, first, last, activity):
    call("PUT", "/users/me", token, {"first_name": first, "last_name": last}, expect=200)
    call("POST", "/users/me/onboarding", token, {"initial_activity": activity}, expect=(200, 201))


print("── People and nursery (sign-up through the API) ──")
admin = login("9000000000")
owner = login("9100000000")
profile(owner, "Priya", "Owner", "OWNER")
_, n = call("POST", "/nurseries", owner, {
    "name": "Priya Green Nursery", "mobile": "9100000000", "description": "Fruit and shade trees, Hyderabad",
    "address_line1": "Plot 12, Nursery Road", "city": "Hyderabad", "state": "Telangana", "country": "India", "postal_code": "500032",
    # Coordinates: the Local Market only lists ads within 100 km of the viewer.
    "latitude": 17.4401, "longitude": 78.3489,
}, expect=201)
nursery_id = n["nursery"]["id"]
step("new nursery waits for approval (PENDING)", n["nursery"]["status"] == "PENDING", n)
call("POST", "/top-items", owner, {"nursery_id": nursery_id, "plant_id": 1, "size_id": 2}, expect=(402, 403))
call("PUT", f"/nurseries/{nursery_id}/status", admin, {"status": "APPROVED"}, expect=200)
owner = refresh("9100000000")  # token now carries NURSERY_OWNER
_, subs = call("GET", "/subscriptions/me", owner, expect=200)
step("approval created the owner's trial subscription", "TRIAL" in json.dumps(subs).upper(), subs)

manager = login("9200000000")
profile(manager, "Gumastha", "Manager", "MANAGER")
_, inv = call("POST", "/invites", owner, {"invite_type": "MANAGER_INVITE", "nursery_id": nursery_id, "target_mobile": "9200000000", "target_name": "Gumastha Manager"}, expect=(200, 201))
call("POST", f"/invites/{inv['invite']['invite_uuid']}/accept", manager, {}, expect=200)
manager = refresh("9200000000")

buyer = login("9300000000")
profile(buyer, "Ravi", "Buyer", "CUSTOMER")
_, me = call("GET", "/users/me", buyer, expect=200)
_, addr = call("POST", f"/users/{me['user']['id']}/addresses", buyer, {
    "address_type": "DELIVERY", "contact_name": "Ravi Buyer", "contact_mobile": "9300000000",
    "address_line1": "Flat 4B, Lake View Apartments", "city": "Hyderabad", "state": "Telangana", "country": "India", "postal_code": "500081",
    "latitude": 17.4435, "longitude": 78.3772,
}, expect=(200, 201))

driver = login("9400000000")
profile(driver, "Raju", "Driver", "DRIVER")

print("\n── Plants: pick from 16.6 lakh names; nothing typed by hand ──")
picks = [("mango", "Mangifera indica", None), ("neem", "Azadirachta indica", None),
         ("cumini", "Syzygium cumini", "Jamun (Neredu)"), ("zapota", "Manilkara zapota", "Sapota (Chikoo)"),
         ("guajava", "Psidium guajava", None), ("granatum", "Punica granatum", "Pomegranate"),
         ("tamarindus indica", "Tamarindus indica", "Tamarind")]
plant_ids = {}
for query, sci, english in picks:
    _, res = call("GET", "/plants/lookup?" + urllib.parse.urlencode({"q": query}), owner, expect=200)
    match = next((r for r in res["results"] if (r.get("plant") or r.get("name"))["scientific_name"] == sci), None)
    step(f"lookup '{query}' offers {sci}", match is not None, res["results"][:3])
    if match.get("plant"):
        plant = match["plant"]
    else:
        _, body = call("POST", "/plants/resolve", owner, {"wfo_id": match["name"]["wfo_id"]}, expect=200)
        plant = body["plant"]
    plant_ids[sci] = plant["id"]
    if english and not plant.get("common_name"):
        call("PUT", f"/plants/{plant['id']}", admin, {"scientific_name": plant["scientific_name"], "common_name": english, "plant_type": "TREE", "light_requirement": "FULL_SUN", "water_requirement": "MODERATE"}, expect=200)

_, body = call("POST", "/plants/resolve", owner, {"wfo_id": "wfo-0000957011"}, expect=200)  # Eugenia cumini (old name)
step("old name Eugenia cumini → the same Jamun plant", body["plant"]["id"] == plant_ids["Syzygium cumini"], body)
_, body = call("GET", "/plants/lookup?" + urllib.parse.urlencode({"q": "jamun"}), buyer, expect=200)
step("English name 'jamun' now finds Syzygium cumini", body["results"] and body["results"][0]["plant"]["id"] == plant_ids["Syzygium cumini"], body["results"][:1])

print("\n── Top items (the nursery's showcase, not stock) ──")
_, sizes = call("GET", "/plants/sizes", expect=200)
size = {s["size_code"]: s["id"] for s in sizes["sizes"]}
for i, (sci, pid) in enumerate(plant_ids.items()):
    call("POST", "/top-items", owner if i % 2 == 0 else manager,
         {"nursery_id": nursery_id, "plant_id": pid, "size_id": size["SAPLING"], "unit_price": 80 + 20 * i,
          "quality_notes": "Grafted, healthy roots" if sci == "Mangifera indica" else None}, expect=201)
_, top = call("GET", f"/nurseries/{nursery_id}/top-items", buyer, expect=200)
step("the nursery shows its 7 top items in order", [t["display_order"] for t in top["top_items"]] == list(range(7)), top)

print("\n── Trading ──")
_, me = call("GET", "/users/me", manager, expect=200); manager_id = me["user"]["id"]
_, nurseries = call("GET", "/nurseries/owned", owner, expect=200)
nursery_id = (nurseries.get("nursery") or nurseries.get("nurseries", [{}])[0])["id"]
_, plants = call("GET", "/plants?per_page=100", expect=200)
pid = {p["scientific_name"]: p["id"] for p in plants["plants"]}

delivery = {"contact_name": "Ravi Buyer", "contact_mobile": "9300000000", "address_line1": "Flat 4B, Lake View Apartments",
            "city": "Hyderabad", "state": "Telangana", "postal_code": "500081", "country": "India"}

print("── Quotation → order (customer flow) ──")
_, q = call("POST", "/quotations", owner, {
    "quotation_type": "CUSTOMER", "nursery_id": nursery_id, "recipient_name": "Ravi Buyer", "recipient_mobile": "9300000000",
    "notes": "Fruit trees for the new apartment garden",
    "items": [{"plant_id": pid["Mangifera indica"], "quantity": 10, "unit_price": 350, "total_price": 3500},
              {"plant_id": pid["Syzygium cumini"], "quantity": 5, "unit_price": 280, "total_price": 1400},
              {"plant_id": pid["Manilkara zapota"], "quantity": 4, "unit_price": 300, "total_price": 1200}],
}, expect=201)
qid = q["quotation"]["id"]
step("quotation starts as CUSTOMER_DRAFT", q["quotation"]["status"] == "CUSTOMER_DRAFT", q["quotation"])
call("GET", f"/quotations/{qid}", buyer, expect=403)  # buyer cannot see a draft
call("POST", f"/quotations/{qid}/assign-manager", owner, {"manager_user_id": manager_id}, expect=200)
_, q = call("POST", f"/quotations/{qid}/send", manager, expect=200)
step("manager sends it → CUSTOMER_SENT", q["quotation"]["status"] == "CUSTOMER_SENT", q)
call("POST", f"/quotations/{qid}/convert-to-order", owner, expect=409)  # not accepted yet
_, q = call("POST", f"/quotations/{qid}/buyer-accept", buyer, expect=200)
step("buyer accepts → CUSTOMER_ACCEPTED", q["quotation"]["status"] == "CUSTOMER_ACCEPTED", q)
_, q = call("POST", f"/quotations/{qid}/convert-to-order", manager, expect=200)
order_id = q["quotation"]["converted_order_id"]
call("POST", f"/quotations/{qid}/convert-to-order", owner, expect=409)  # only once

_, q2 = call("POST", "/quotations", owner, {"quotation_type": "CUSTOMER", "nursery_id": nursery_id, "recipient_name": "Ravi Buyer",
             "recipient_mobile": "9300000000", "items": [{"plant_id": pid["Punica granatum"], "quantity": 20, "unit_price": 150, "total_price": 3000}]}, expect=201)
call("POST", f"/quotations/{q2['quotation']['id']}/send", owner, expect=200)
_, r = call("POST", f"/quotations/{q2['quotation']['id']}/buyer-reject", buyer, {"reason": "Price too high"}, expect=200)
step("second quotation rejected by buyer → CUSTOMER_REJECTED", r["quotation"]["status"] == "CUSTOMER_REJECTED", r)

print("\n── Order → loading (partial) ──")
_, o = call("GET", f"/orders/{order_id}", buyer, expect=200)
step("converted order is PENDING and visible to the buyer", o["order"]["order_status"] == "PENDING", o["order"]["order_status"])
call("POST", f"/orders/{order_id}/confirm", buyer, expect=403)
# The order starts with the buyer's saved default address; staff may still edit it.
step("converted order carries the buyer's saved delivery address",
     (o["order"].get("delivery_snapshot") or {}).get("contact_name") == "Ravi Buyer", o["order"].get("delivery_snapshot"))
call("PUT", f"/orders/{order_id}/delivery", buyer, delivery, expect=403)
call("PUT", f"/orders/{order_id}/delivery", manager, delivery, expect=200)
_, o = call("POST", f"/orders/{order_id}/confirm", manager, expect=200)
step("order CONFIRMED", o["order"]["order_status"] == "CONFIRMED", o["order"]["order_status"])
_, o = call("POST", f"/orders/{order_id}/start-loading", manager, expect=200)
item = o["order"]["items"][0]
call("PUT", f"/orders/{order_id}/items/{item['id']}/loaded-quantity", buyer, {"loaded_quantity": 8}, expect=403)
call("PUT", f"/orders/{order_id}/items/{item['id']}/loaded-quantity", manager, {"loaded_quantity": 8}, expect=200)
_, o = call("POST", f"/orders/{order_id}/complete-loading", manager, expect=200)
step("short load → PARTIALLY_FULFILLED", o["order"]["order_status"] == "PARTIALLY_FULFILLED", o["order"]["order_status"])
call("POST", f"/orders/{order_id}/cancel", owner, {"reason": "too late"}, expect=409)  # cannot cancel once loaded

print("\n── Dispatch with an independent driver ──")
_, inv = call("POST", "/invites", owner, {"invite_type": "DRIVER_INVITE", "nursery_id": nursery_id, "target_mobile": "9400000000", "target_name": "Raju Driver"}, expect=(200, 201))
call("POST", f"/invites/{inv['invite']['invite_uuid']}/accept", driver, {}, expect=200)
status, app = call("POST", "/drivers/apply", driver, {"licence_number": "TS0920230001234", "vehicle_number": "TS09UB1234", "vehicle_type": "MINI_TRUCK"}, expect=(200, 201, 409))
_, me = call("GET", "/users/me", driver, expect=200)
call("POST", f"/drivers/{app.get('driver', {}).get('id', 0) or 0}/approve", admin, {"driver_user_id": me["user"]["id"]}, expect=(200, 201))
driver = refresh("9400000000")  # token now carries the DRIVER role
_, me = call("GET", "/users/me", driver, expect=200)
step("approved driver has DRIVER and no longer BUYER", "DRIVER" in json.dumps(me) and '"BUYER"' not in json.dumps(me.get("user", {}).get("roles", [])), me.get("user", {}).get("roles"))
_, d = call("POST", "/dispatches", owner, {"order_id": order_id, "notes": "Morning delivery"}, expect=201)
did, trip = d["dispatch"]["id"], "TRIP-" + d["dispatch"]["trip_uuid"]  # the nursery's QR
call("POST", f"/dispatches/{did}/accept", buyer, {"trip_code": trip}, expect=403)
_, d = call("POST", f"/dispatches/{did}/accept", driver, {"trip_code": trip}, expect=200)
step("driver accepts the trip → ACCEPTED", d["dispatch"]["dispatch_status"] == "ACCEPTED", d["dispatch"]["dispatch_status"])
call("PUT", f"/dispatches/{did}/status", owner, {"dispatch_status": "DISPATCHED"}, expect=200)
call("PUT", f"/dispatches/{did}/status", driver, {"dispatch_status": "IN_TRANSIT"}, expect=200)
call("POST", "/tracking", driver, {"dispatch_id": did, "latitude": 17.44, "longitude": 78.38}, expect=(200, 201, 400))
# Delivery needs the customer: the driver enters the code the buyer sees in their app.
_, bd = call("GET", f"/dispatches/{did}", buyer, expect=200)
_, d = call("POST", f"/dispatches/{did}/deliver", driver, {"code": bd["dispatch"].get("delivery_code", "")}, expect=200)
step("driver delivers with the customer's code → DELIVERED", d["dispatch"]["dispatch_status"] == "DELIVERED", d["dispatch"]["dispatch_status"])
_, o = call("GET", f"/orders/{order_id}", buyer, expect=200)
if o["order"]["order_status"] != "COMPLETED":
    _, o = call("PUT", f"/orders/{order_id}/status", owner, {"order_status": "COMPLETED"}, expect=200)
step("order COMPLETED", o["order"]["order_status"] == "COMPLETED", o["order"]["order_status"])
call("POST", f"/orders/{order_id}/cancel", admin, {"reason": "terminal"}, expect=409)

print("\n── Payment ──")
_, p = call("POST", "/payments/manual", owner, {"payment_for": "ORDER", "order_id": order_id, "amount": o["order"].get("total_amount", 4200),
            "payment_method": "UPI", "transaction_reference": "UPI-DEV-0001", "payment_status": "SUCCESS"}, expect=(200, 201))

print("\n── Buyer cancels a pending order ──")
_, o2 = call("POST", "/orders", owner, {"seller_nursery_id": nursery_id, "buyer_name": "Ravi Buyer", "buyer_mobile": "9300000000", "delivery": delivery,
             "items": [{"plant_id": pid["Tamarindus indica"], "quantity": 3, "unit_price": 400, "total_price": 1200}]}, expect=201)
_, c = call("POST", f"/orders/{o2['order']['id']}/cancel", buyer, {"reason": "No longer needed"}, expect=200)
step("buyer cancels own PENDING order", c["order"]["order_status"] == "CANCELLED", c["order"]["order_status"])

print("\n── Local market (nursery to nursery) ──")
second = login("9500000000")
profile(second, "Lakshmi", "Owner", "OWNER")
_, n2 = call("POST", "/nurseries", second, {"name": "Lakshmi Plants", "mobile": "9500000000", "city": "Vijayawada", "state": "Andhra Pradesh",
             "country": "India", "address_line1": "NH 16, Kanuru", "latitude": 16.5062, "longitude": 80.6480}, expect=201)
call("PUT", f"/nurseries/{n2['nursery']['id']}/status", admin, {"status": "APPROVED"}, expect=200)
second = refresh("9500000000")
selfie(owner, "owner")
selfie(second, "second owner")
_, ad = call("POST", "/market/ads", owner, {"plant_name": "Syzygium cumini (Jamun) saplings", "title": "Surplus Jamun saplings, 2 ft",
              "description": "Healthy grafted saplings", "quantity": 200, "price_per_unit": 120, "price_unit": "PER_PLANT", "photos": []}, expect=201)
adid = ad["ad"]["id"]
call("GET", "/market/ads", buyer, expect=403)  # market is nursery-to-nursery
call("POST", f"/market/ads/{adid}/publish", owner, expect=200)
call("POST", f"/market/ads/{adid}/enquiries", owner, {"message": "self"}, expect=400)
_, enq = call("POST", f"/market/ads/{adid}/enquiries", second, {"message": "Need 100 saplings next week. Price for bulk?", "quantity": 100}, expect=201)
eid = (enq.get("enquiry") or {}).get("id")
call("POST", f"/market/enquiries/{eid}/reply", owner, {"body": "Rs 110 each for 100. Can deliver Monday."}, expect=(200, 201))


print("\n── Report for the admin moderation queue ──")
call("POST", f"/market/ads/{adid}/report", second, {"reason": "WRONG_PLANT", "notes": "Photo shows guava saplings, not jamun"}, expect=200)

print(f"\n{_count[0]} steps passed — dev data ready")
