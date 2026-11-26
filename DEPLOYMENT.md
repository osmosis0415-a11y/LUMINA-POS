# Deploy Lumina POS

1. In repository Settings → Pages, choose Deploy from a branch, main, /(root), then Save.
2. Open the Pages URL displayed by GitHub.
3. Create a separate Supabase project; run supabase.sql in SQL Editor.
4. Create a staff user in Authentication → Users. Insert the user's UUID into public.pos_staff as described in the SQL.
5. Edit config.json with the Supabase project URL (no trailing slash) and legacy anon/public key. Never publish a service-role key or password.
6. Open POS → QR Orders, sign in, publish the menu, and download individual table QR codes. Test each code on a second phone.
7. Accept a test order, check kitchen queue and table cart, settle the bill and verify reports.

MVP limitations: single cashier device owns local billing data; browser storage can be lost; export backups regularly. Acceptance and local persistence are not atomic across network failures. QR inbox polls every 15 seconds; staff may need to sign in again after token expiry. Published inventory is a snapshot; republish after changes. QR codes depend on a CDN-loaded library; treat table links as bearer tokens. No payment processing, ingredient-level inventory, customer tracking, waiter requests, or tax-compliance certification. Do not use for production without testing, authentication hardening, abuse prevention and transactional shared storage.
