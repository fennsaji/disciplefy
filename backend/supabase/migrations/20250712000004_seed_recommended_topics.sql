-- Seed script for foundational doctrines from Hebrews 6:1-2
-- Six foundational doctrines that every believer should understand

BEGIN;

-- Insert foundational doctrines as recommended topics
INSERT INTO recommended_topics (id, title, description, category, difficulty_level, estimated_duration, tags, display_order)
VALUES
  ('550e8400-e29b-41d4-a716-446655440001', 'Repentance from Dead Works', 'Turning away from sinful behaviors and trying to earn salvation through works, and turning to God in humility.', 'Foundational Doctrines', ARRAY['repentance', 'dead works', 'salvation', 'grace'], 1),
  ('550e8400-e29b-41d4-a716-446655440002', 'Faith Toward God', 'Trusting fully in God and His promises, especially the saving work of Jesus Christ.', 'Foundational Doctrines', ARRAY['faith', 'trust', 'jesus christ', 'promises'], 2),
  ('550e8400-e29b-41d4-a716-446655440003', 'Doctrine of Baptisms', 'Understanding various baptisms: water baptism, baptism of the Holy Spirit, and possibly ceremonial washings under the Law.', 'Foundational Doctrines', ARRAY['baptism', 'water baptism', 'holy spirit', 'spiritual washing'], 3),
  ('550e8400-e29b-41d4-a716-446655440004', 'Laying on of Hands', 'A symbol of impartation—used in healing, blessing, commissioning for ministry, or receiving the Holy Spirit.', 'Foundational Doctrines', ARRAY['laying on hands', 'impartation', 'healing', 'blessing', 'ministry'], 4),
  ('550e8400-e29b-41d4-a716-446655440005', 'Resurrection of the Dead', 'The belief that all people will be raised from the dead—believers to eternal life and unbelievers to judgment.', 'Foundational Doctrines', ARRAY['resurrection', 'eternal life', 'judgment', 'afterlife'], 5),
  ('550e8400-e29b-41d4-a716-446655440006', 'Eternal Judgment', 'The final judgment by God, where all will be held accountable and rewarded or condemned based on their response to Christ.', 'Foundational Doctrines', ARRAY['eternal judgment', 'accountability', 'final judgment', 'christ'], 6);

COMMIT;