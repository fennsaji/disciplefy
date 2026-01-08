-- Migration: Add 'sermon' mode to all study_mode CHECK constraints
-- Created: 2026-01-07
-- Description: Updates CHECK constraints across multiple tables to include the new 'sermon' study mode

-- ============================================================================
-- 1. Update study_guides table study_mode constraint
-- ============================================================================

-- Drop existing constraint
ALTER TABLE public.study_guides
DROP CONSTRAINT IF EXISTS study_guides_study_mode_check;

-- Add updated constraint with 'sermon'
ALTER TABLE public.study_guides
ADD CONSTRAINT study_guides_study_mode_check
CHECK (study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon'));

-- ============================================================================
-- 2. Update user_reflections table study_mode constraint (if table exists)
-- ============================================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_reflections') THEN
        -- Drop existing constraint
        ALTER TABLE public.user_reflections
        DROP CONSTRAINT IF EXISTS user_reflections_study_mode_check;

        -- Add updated constraint with 'sermon'
        ALTER TABLE public.user_reflections
        ADD CONSTRAINT user_reflections_study_mode_check
        CHECK (study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon'));

        RAISE NOTICE 'Updated user_reflections study_mode constraint';
    ELSE
        RAISE NOTICE 'Skipping user_reflections - table does not exist';
    END IF;
END $$;

-- ============================================================================
-- 3. Update user_profiles default_study_mode constraint
-- ============================================================================

-- Drop existing constraint
ALTER TABLE public.user_profiles
DROP CONSTRAINT IF EXISTS user_profiles_default_study_mode_check;

-- Add updated constraint with 'sermon' and 'recommended'
ALTER TABLE public.user_profiles
ADD CONSTRAINT user_profiles_default_study_mode_check
CHECK (default_study_mode IS NULL OR default_study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon', 'recommended'));

-- ============================================================================
-- 4. Update user_profiles learning_path_study_mode constraint (if column exists)
-- ============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_profiles' AND column_name = 'learning_path_study_mode'
    ) THEN
        -- Drop existing constraint
        ALTER TABLE public.user_profiles
        DROP CONSTRAINT IF EXISTS user_profiles_learning_path_study_mode_check;

        -- Add updated constraint with 'sermon'
        ALTER TABLE public.user_profiles
        ADD CONSTRAINT user_profiles_learning_path_study_mode_check
        CHECK (learning_path_study_mode IN ('ask', 'recommended', 'quick', 'standard', 'deep', 'lectio', 'sermon'));

        RAISE NOTICE 'Updated user_profiles learning_path_study_mode constraint';
    ELSE
        RAISE NOTICE 'Skipping learning_path_study_mode - column does not exist in user_profiles';
    END IF;
END $$;

-- ============================================================================
-- 5. Update user_personalization default_study_mode constraint (if exists)
-- ============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_personalization' AND column_name = 'default_study_mode'
    ) THEN
        -- Drop existing constraint
        ALTER TABLE public.user_personalization
        DROP CONSTRAINT IF EXISTS user_personalization_default_study_mode_check;

        -- Add updated constraint with 'sermon'
        ALTER TABLE public.user_personalization
        ADD CONSTRAINT user_personalization_default_study_mode_check
        CHECK (default_study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon'));

        RAISE NOTICE 'Updated user_personalization default_study_mode constraint';
    ELSE
        RAISE NOTICE 'Skipping user_personalization default_study_mode - column does not exist';
    END IF;
END $$;

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
DECLARE
    constraint_count INTEGER;
BEGIN
    -- Count updated constraints
    SELECT COUNT(*) INTO constraint_count
    FROM information_schema.constraint_column_usage
    WHERE constraint_name IN (
        'study_guides_study_mode_check',
        'user_reflections_study_mode_check',
        'user_profiles_default_study_mode_check',
        'user_profiles_learning_path_study_mode_check',
        'user_personalization_default_study_mode_check'
    );

    IF constraint_count < 4 THEN
        RAISE WARNING 'Expected at least 4 study_mode constraints, found %', constraint_count;
    ELSE
        RAISE NOTICE 'Successfully updated % study_mode constraints to include sermon mode', constraint_count;
    END IF;
END $$;

-- Add comments to created constraints
DO $$
BEGIN
    -- study_guides constraint comment
    EXECUTE 'COMMENT ON CONSTRAINT study_guides_study_mode_check ON public.study_guides IS ' ||
            quote_literal('Validates study_mode is one of: quick, standard, deep, lectio, sermon');

    -- user_reflections constraint comment (if it was created)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'user_reflections_study_mode_check'
        AND table_name = 'user_reflections'
    ) THEN
        EXECUTE 'COMMENT ON CONSTRAINT user_reflections_study_mode_check ON public.user_reflections IS ' ||
                quote_literal('Validates study_mode is one of: quick, standard, deep, lectio, sermon');
    END IF;

    -- user_profiles default_study_mode constraint comment
    EXECUTE 'COMMENT ON CONSTRAINT user_profiles_default_study_mode_check ON public.user_profiles IS ' ||
            quote_literal('Validates default_study_mode is NULL or one of: quick, standard, deep, lectio, sermon, recommended');

    -- user_profiles learning_path_study_mode constraint comment (if it was created)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'user_profiles_learning_path_study_mode_check'
        AND table_name = 'user_profiles'
    ) THEN
        EXECUTE 'COMMENT ON CONSTRAINT user_profiles_learning_path_study_mode_check ON public.user_profiles IS ' ||
                quote_literal('Validates learning_path_study_mode is one of: ask, recommended, quick, standard, deep, lectio, sermon');
    END IF;
END $$;
