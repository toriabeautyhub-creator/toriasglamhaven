/* ============================================================================
   TORIA'S GLAM HAVEN — Configuration
   ----------------------------------------------------------------------------
   This is the ONLY file you edit to connect everything. Paste the 4 values
   below (you'll get them while following SETUP.md), save, and you're live.
   These keys are PUBLIC by design and safe to ship — your data is protected
   by the security rules in supabase/schema.sql.
   ============================================================================ */
window.TGH_CONFIG = {

  /* ---- Supabase (your database + dashboard login) ----------------------- */
  /* Supabase dashboard → Project Settings → API */
  SUPABASE_URL:      "https://hcndtcxcclpzazxwybgq.supabase.co",
  SUPABASE_ANON_KEY: "sb_publishable_rtmSd-oEhc9hXG_lqpFwAA_UGc6Dvkm",

  /* ---- EmailJS (emails you on new orders & sign-ups) -------------------- */
  /* Get these from emailjs.com. Leave as-is to skip email for now —
     orders & sign-ups are ALWAYS saved to your dashboard regardless. */
  EMAILJS_PUBLIC_KEY:        "",   // EmailJS → Account → General → Public Key
  EMAILJS_SERVICE_ID:        "",   // EmailJS → Email Services
  EMAILJS_ORDER_TEMPLATE_ID: "",   // template for new-order emails
  EMAILJS_SIGNUP_TEMPLATE_ID:"",   // template for new-signup emails

  /* ---- Where notifications go ------------------------------------------- */
  NOTIFY_EMAIL: "toriabeautyhub@gmail.com"
};
