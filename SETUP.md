# Toria's Glam Haven — Backend & Dashboard Setup

This guide turns on your management system. No coding needed — you'll create two
free accounts, copy a few keys into one file, and you're live.

**Time:** about 30–40 minutes, once.
**Cost:** KSh 0 (free tiers are plenty for now).

You'll set up:
1. **Supabase** — your database + dashboard login (orders, stock, subscribers, analytics).
2. **EmailJS** — emails you when an order or sign-up comes in *(optional — you can skip and add later)*.

---

## What you have now

| File | What it is |
|------|------------|
| `index.html` | Your shop (unchanged design, now talks to the backend) |
| `admin/index.html` | **Your private dashboard** — open this to manage everything |
| `assets/config.js` | The one file you edit with your keys |
| `supabase/schema.sql` | The database setup (you paste this in once) |

---

## PART 1 — Supabase (required)

### 1.1 Create the project
1. Go to **https://supabase.com** → **Start your project** → sign in with Google/GitHub.
2. Click **New project**.
   - **Name:** `torias-glam-haven`
   - **Database Password:** click *Generate*, then **save it somewhere safe** (a notebook is fine).
   - **Region:** choose the closest — **`Central EU (Frankfurt)`** is a good pick for Kenya.
3. Click **Create new project** and wait ~2 minutes for it to finish setting up.

### 1.2 Create the database tables
1. In the left menu click **SQL Editor** → **New query**.
2. Open the file `supabase/schema.sql` (in this project), copy **everything** in it.
3. Paste it into the query box and click **Run** (bottom right).
4. You should see **“Success. No rows returned.”** ✅ That built all your tables, security, and loaded your 28 products + 2 starter codes.

### 1.3 Get your keys
1. Left menu → **Project Settings** (the gear) → **API**.
2. Copy these two values:
   - **Project URL** (looks like `https://abcd1234.supabase.co`)
   - **anon public** key (a long string under *Project API keys*)

### 1.4 Create your login
This is the email + password you'll use to open the dashboard.
1. Left menu → **Authentication** → **Users** → **Add user** → **Create new user**.
2. Enter your email (e.g. `toriabeautyhub@gmail.com`) and a strong password. **Save the password.**
3. Tick **Auto Confirm User** (so you can log in right away) → **Create user**.

### 1.5 Put the keys into your site
1. Open `assets/config.js`.
2. Replace the two placeholders:
   ```js
   SUPABASE_URL:      "https://abcd1234.supabase.co",   // your Project URL
   SUPABASE_ANON_KEY: "eyJhbGci...your-long-key...",     // your anon public key
   ```
3. Save the file.

**✅ Test it:** open `admin/index.html` in your browser, log in with the email/password
from step 1.4. You should see your dashboard with all 28 products under **Stock** and
**Catalogue**. Place a test order on your shop — it appears under **Orders** instantly.

---

## PART 2 — EmailJS (optional — emails on new orders/sign-ups)

Your orders and sign-ups are **always saved to the dashboard** even without this.
EmailJS just pings your inbox so you don't have to keep the dashboard open.

### 2.1 Create the account & connect Gmail
1. Go to **https://www.emailjs.com** → sign up (free).
2. **Email Services** → **Add New Service** → choose **Gmail** → connect
   `toriabeautyhub@gmail.com` → note the **Service ID** (e.g. `service_ab12cd`).

### 2.2 Create two templates
**Email Services → Email Templates → Create New Template.**

**Template A — New order.** Set the *To Email* field to `{{to_email}}` and paste this as the body:
```
New order {{order_no}} 🛍️

Customer: {{customer_name}} ({{customer_phone}})
Delivery: {{delivery}}
Gift: {{gift}}
Discount: {{discount}}

Items:
{{items}}

TOTAL: {{total}}
```
Save it and note the **Template ID** (e.g. `template_order1`).

**Template B — New sign-up.** *To Email* = `{{to_email}}`, body:
```
New Glam Circle sign-up 🎉
Email: {{subscriber_email}}
```
Save and note its **Template ID** (e.g. `template_signup1`).

### 2.3 Get your Public Key
**Account → General → Public Key** — copy it.

### 2.4 Put them into config
Open `assets/config.js` and fill in:
```js
EMAILJS_PUBLIC_KEY:         "your_public_key",
EMAILJS_SERVICE_ID:         "service_ab12cd",
EMAILJS_ORDER_TEMPLATE_ID:  "template_order1",
EMAILJS_SIGNUP_TEMPLATE_ID: "template_signup1",
```
Save. Done — place a test order and check your inbox. 📧

---

## PART 3 — Go live (publish to Vercel)

Your site already deploys from this GitHub repo. Just commit and push the new files:
```
git add .
git commit -m "Add management dashboard and backend"
git push
```
Vercel rebuilds automatically. Your shop stays at **toriasglam.co.ke**; your dashboard
is at **toriasglam.co.ke/admin/**.

> 🔒 **Keep the dashboard private:** the `/admin/` page is hidden from Google, and nobody
> can get in without your Supabase login. Don't share the password. (Want extra safety?
> Bookmark it and never link to it publicly — which we already avoid.)

---

## How you'll use it day to day

| Task | Where |
|------|-------|
| See new orders & mark them paid/packed/delivered | **Orders** |
| Update stock counts / hide a sold-out piece | **Stock** |
| Add a new product with a photo | **Catalogue → + New product** |
| Run a promo & see how often a code is used | **Discounts** |
| Email your subscriber list (export CSV) | **Subscribers → Export** |
| See best sellers & what isn't moving | **Analytics** |

---

## Frequently asked

**Will my shop break if Supabase is down?**
No. The shop falls back to its built-in product list and still takes orders via WhatsApp.

**Are my keys safe to publish?**
Yes — the `anon` key is public by design. Your data is protected by the security rules
in `schema.sql` (visitors can only place orders; only your login can read/manage data).

**Can I change an original product's description/photo?**
Yes — open it in **Catalogue → Edit** and upload a photo / edit the text; the dashboard
version then takes over on the shop.

**How do I add a staff member?**
Add another user in Supabase → Authentication → Users (step 1.4). They log in the same way.

---

Questions or stuck on a step? Tell me which step number and I'll walk you through it.
