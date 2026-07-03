-- C2: Remove client INSERT/UPDATE access on pending_token_purchases.
-- Rows are created and updated server-side via the service-role client inside Edge Functions.
-- Authenticated clients had INSERT+UPDATE which allowed them to set arbitrary token_amount
-- before confirming payment, enabling the "pay ₹1 for 10,000 tokens" exploit.

DROP POLICY IF EXISTS "Users can insert own pending purchases" ON public.pending_token_purchases;
DROP POLICY IF EXISTS "Users can update own pending purchases" ON public.pending_token_purchases;

REVOKE INSERT, UPDATE ON public.pending_token_purchases FROM authenticated;
