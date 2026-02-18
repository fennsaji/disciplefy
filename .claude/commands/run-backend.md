---
description: Start Backend (Supabase) Only
---

Start the Supabase backend server.

Run the following command in the background:

```bash
cd /Users/fennsaji/Documents/Projects/Fenn/bible-study-app/backend && sh scripts/run_local_server.sh
```

This will:
- Stop existing Supabase containers
- Reset the database (destroy all data)
- Apply all migrations
- Start Supabase services

**Access Points:**
- API: http://127.0.0.1:54321
- Studio: http://127.0.0.1:54323
- Database: postgresql://postgres:postgres@127.0.0.1:54322/postgres
- Mailpit: http://127.0.0.1:54324
