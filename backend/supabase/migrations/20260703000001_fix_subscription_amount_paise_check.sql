-- Allow amount_paise = 0 for fully-comped (100% promo) subscriptions.
-- Previously CHECK (amount_paise > 0) caused every free activation to 500.
ALTER TABLE subscriptions
  DROP CONSTRAINT IF EXISTS subscriptions_amount_paise_check;

ALTER TABLE subscriptions
  ADD CONSTRAINT subscriptions_amount_paise_check CHECK (amount_paise >= 0);
