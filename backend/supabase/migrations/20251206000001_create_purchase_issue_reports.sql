-- Migration: Create Purchase Issue Reports System
-- Description: Table and storage for users to report purchase/payment issues

-- ============================================================================
-- Table: purchase_issue_reports
-- ============================================================================
CREATE TABLE IF NOT EXISTS purchase_issue_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- User info
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_email TEXT NOT NULL,
  
  -- Purchase reference
  purchase_id UUID NOT NULL,
  payment_id TEXT NOT NULL,
  order_id TEXT NOT NULL,
  token_amount INT NOT NULL,
  cost_rupees DECIMAL(10,2) NOT NULL,
  purchased_at TIMESTAMPTZ NOT NULL,
  
  -- Issue details
  issue_type TEXT NOT NULL CHECK (issue_type IN (
    'wrong_amount',
    'payment_failed', 
    'tokens_not_credited',
    'duplicate_charge',
    'refund_request',
    'other'
  )),
  description TEXT NOT NULL,
  screenshot_urls TEXT[] DEFAULT '{}',
  
  -- Status tracking
  status TEXT DEFAULT 'pending' CHECK (status IN (
    'pending',
    'in_review',
    'resolved',
    'closed'
  )),
  admin_notes TEXT,
  resolved_by UUID REFERENCES auth.users(id),
  resolved_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- Indexes
-- ============================================================================
CREATE INDEX idx_purchase_issue_reports_user_id ON purchase_issue_reports(user_id);
CREATE INDEX idx_purchase_issue_reports_status ON purchase_issue_reports(status);
CREATE INDEX idx_purchase_issue_reports_created_at ON purchase_issue_reports(created_at DESC);
CREATE INDEX idx_purchase_issue_reports_purchase_id ON purchase_issue_reports(purchase_id);

-- ============================================================================
-- RLS Policies
-- ============================================================================
ALTER TABLE purchase_issue_reports ENABLE ROW LEVEL SECURITY;

-- Users can view their own reports
CREATE POLICY "Users can view own purchase issue reports"
  ON purchase_issue_reports
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can create reports for their own purchases
CREATE POLICY "Users can create purchase issue reports"
  ON purchase_issue_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Admins can view all reports
CREATE POLICY "Admins can view all purchase issue reports"
  ON purchase_issue_reports
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Admins can update reports (status, notes, resolution)
CREATE POLICY "Admins can update purchase issue reports"
  ON purchase_issue_reports
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- ============================================================================
-- Updated At Trigger
-- ============================================================================
CREATE OR REPLACE FUNCTION update_purchase_issue_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_purchase_issue_reports_updated_at
  BEFORE UPDATE ON purchase_issue_reports
  FOR EACH ROW
  EXECUTE FUNCTION update_purchase_issue_reports_updated_at();

-- ============================================================================
-- Storage Bucket for Screenshots
-- ============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'issue-screenshots',
  'issue-screenshots',
  false,
  5242880, -- 5MB max file size
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for issue screenshots
CREATE POLICY "Users can upload issue screenshots"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'issue-screenshots' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can view own issue screenshots"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'issue-screenshots' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Admins can view all issue screenshots"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'issue-screenshots' AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- ============================================================================
-- Comments
-- ============================================================================
COMMENT ON TABLE purchase_issue_reports IS 'Stores user-reported issues with token purchases';
COMMENT ON COLUMN purchase_issue_reports.issue_type IS 'Type of issue: wrong_amount, payment_failed, tokens_not_credited, duplicate_charge, refund_request, other';
COMMENT ON COLUMN purchase_issue_reports.status IS 'Report status: pending (new), in_review (being investigated), resolved (fixed), closed (no action needed)';
COMMENT ON COLUMN purchase_issue_reports.screenshot_urls IS 'Array of storage URLs for uploaded screenshot evidence';
