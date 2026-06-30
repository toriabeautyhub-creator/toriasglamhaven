# Integration Plan — M-Pesa Payments & Pickup Mtaani

This is the roadmap for wiring in the **payment API** and **Pickup Mtaani API** you're
adding at the end of the week. Read this before you start so the pieces slot in cleanly.

---

## The key architecture decision: we need Edge Functions

Today everything runs safely in the public browser. But both these APIs use **secret
keys** that must **never** be in the public site, and M-Pesa must be able to **call your
system back** when a payment completes. Those two needs mean we add a small server layer:

> **Supabase Edge Functions** — free, secure mini-programs that run on Supabase's servers.
> They hold the secret keys and expose safe URLs the shop and the APIs can call.

Nothing about your current setup changes — we just add functions alongside it.

```
Customer pays  ──►  Edge Function (holds M-Pesa secret)  ──►  Safaricom Daraja
                                                                    │
Order flips to PAID  ◄──  Edge Function (callback)  ◄────────  "payment ok"
in your dashboard
```

---

## PART A — M-Pesa payments (Safaricom Daraja)

### What you'll get
- A **real STK push**: customer taps "Pay", gets the M-Pesa PIN prompt on their phone.
- Orders **auto-flip to "Paid"** with the **M-Pesa receipt number** stored — no manual checking.
- A payments record for reconciliation and refunds.

### What you need from Safaricom (Daraja portal — https://developer.safaricom.co.ke)
- **Consumer Key** + **Consumer Secret**
- **Business Shortcode** (Paybill `400200` / your store number) + **Passkey**
- Confirm whether you're on **Paybill** (you currently use Paybill 400200, A/c 1075861)

### Database additions (a migration I'll write)
- `orders.payment_status` (pending / paid / failed)
- `orders.mpesa_receipt`, `orders.mpesa_phone`, `orders.paid_at`
- a `payments` table (raw Daraja callbacks, for audit/reconciliation)

### Edge Functions I'll build
1. `mpesa-stkpush` — the shop calls this when the customer pays → it asks Daraja to send
   the PIN prompt. Holds the secret key.
2. `mpesa-callback` — Safaricom calls this when payment succeeds/fails → it marks the
   order paid and saves the receipt. (This URL is registered with Daraja.)

### Storefront change
- Replace the current **simulated** `stkPush()` in `index.html` (step 4 of checkout) with
  a real call to `mpesa-stkpush`, then show "Check your phone for the M-Pesa prompt".

### Dashboard change
- Orders show a **Payment** column (Paid ✓ / Pending) with the M-Pesa receipt.
- A small **Reconciliation** view: today's M-Pesa receipts vs. orders.

### What to have ready for me
- Daraja **Consumer Key, Consumer Secret, Shortcode, Passkey** (I'll store them as Supabase
  secrets — never in the public code).
- Whether you want **auto-paid** orders to also trigger a customer WhatsApp/SMS receipt.

---

## PART B — Pickup Mtaani API

### What you'll get
- **Live agent/route list** pulled from Pickup Mtaani (instead of the hardcoded list in
  `index.html`), so it's always current.
- **Auto-create a delivery** from an order with one click in the dashboard.
- **Parcel tracking**: status (booked → in transit → arrived → collected) shown on the
  order, and the customer auto-notified at each step.
- Accurate **delivery fees** from their API.

### What you need from Pickup Mtaani
- API credentials (key/token) and their **API docs** (endpoints for: list agents, create
  shipment, track shipment, fee lookup). Each provider differs — I'll map to whatever
  they give you.

### Database additions
- `orders.pm_shipment_id`, `orders.pm_status`, `orders.pm_tracking` (or a `shipments` table
  if they support multiple parcels per order).

### Edge Functions I'll build
1. `pm-agents` — fetches the live route/agent list (shop calls this to fill the dropdown).
2. `pm-create-shipment` — dashboard calls this to book a parcel for an order.
3. `pm-track` (or a scheduled sync) — updates parcel statuses, optionally notifies customers.

### Storefront change
- Replace the static `MTAANI_ROUTES` object with a live fetch from `pm-agents` (with the
  current list kept as a fallback if their API is down).

### Dashboard change
- On an order: **"Book Pickup Mtaani"** button → shows tracking number + live status.
- The **Packing** screen gains a "Booked / Not booked" indicator.

### What to have ready for me
- Pickup Mtaani **API credentials + documentation link**.
- Confirm: do you want delivery **fees auto-calculated** at checkout, or keep the current
  flat KSh 100 + "billed by rider" model?

---

## Suggested order of work (at the weekend)

1. **You:** get Daraja credentials + Pickup Mtaani credentials & docs.
2. **Me:** run the small DB migrations (payment + shipment fields).
3. **Me:** build & deploy the Edge Functions (I'll guide you to paste the secrets — they go
   in Supabase, never in GitHub).
4. **Me:** wire the storefront checkout (real STK push, live routes) + the dashboard
   (payment status, reconciliation, book/track shipment).
5. **Together:** a live test order end-to-end (real PIN prompt → auto-paid → booked parcel).

> ⚠️ **Security note:** when we get there, the API secret keys go into **Supabase → Edge
> Functions → Secrets**, *never* into `assets/config.js` or GitHub. The publishable keys we
> already use are fine to be public; these new ones are not.

---

When you have the credentials, just say "let's do the payment API" (or Pickup Mtaani) and
hand me the docs — I'll take it from there.
