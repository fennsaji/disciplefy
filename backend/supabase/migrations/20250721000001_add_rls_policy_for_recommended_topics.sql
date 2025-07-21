-- Add RLS policy to prevent anonymous writes to recommended_topics

CREATE POLICY "Deny anonymous writes to recommended topics" ON recommended_topics
FOR ALL
USING (false)
WITH CHECK (false);
