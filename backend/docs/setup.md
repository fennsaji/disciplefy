🛑 Step 1: Stop the Supabase Local Server

  supabase stop

  🔄 Step 2: Apply Pending Migrations and Changes

  # Reset and apply all migrations from scratch
  supabase db reset

  # Alternative: Apply only new migrations (if you don't want to reset)
  # supabase db push

  🚀 Step 3: Start Supabase Server with Project ID

  # Start with specific project ID and load environment variables
  supabase start

  📁 Step 4: Ensure Environment Files are Loaded

  # Verify your .env files exist and are properly configured
  ls -la .env*

  # If you need to link to remote project (optional)
  # supabase link --project-ref disciplefy-backend

  🔧 Step 5: Deploy Edge Functions

  # Deploy all functions to local environment
  supabase functions deploy --no-verify-jwt

  # Or deploy specific functions individually
  supabase functions deploy topics-recommended --no-verify-jwt
  supabase functions deploy study-generate --no-verify-jwt
  supabase functions deploy auth-session --no-verify-jwt
  supabase functions deploy feedback --no-verify-jwt

  ✅ Step 6: Verification Commands

  # Check if Supabase is running
  supabase status

  # Test database connection
  supabase db ping

  # List all available functions
  supabase functions list

  # Check function logs (optional)
  supabase functions logs

  # Verify specific endpoints are working
  curl -X GET "http://127.0.0.1:54321/functions/v1/topics-recommended"

  🔍 Additional Verification Steps

  # Check the database schema
  supabase db diff

  # Verify migrations are applied
  supabase migration list

  # Check Docker containers are running
  docker ps | grep supabase

  # Test API health
  curl -X GET "http://127.0.0.1:54321/rest/v1/" \
    -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5
  OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

  🐛 Troubleshooting Commands (if needed)

  # If functions fail to deploy
  supabase functions delete <function-name>
  supabase functions deploy <function-name> --no-verify-jwt

  # If database issues occur
  supabase db reset --linked=false

  # Clean Docker containers and restart
  supabase stop
  docker system prune -f
  supabase start --project-id disciplefy-backend

  📋 Expected Output for Success

  After running supabase status, you should see:
  - ✅ API URL: http://127.0.0.1:54321
  - ✅ GraphQL URL: http://127.0.0.1:54321/graphql/v1
  - ✅ DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
  - ✅ Studio URL: http://127.0.0.1:54323
  - ✅ Inbucket URL: http://127.0.0.1:54324
  - ✅ JWT secret: your-jwt-secret
  - ✅ anon key: your-anon-key
  - ✅ service_role key: your-service-role-key