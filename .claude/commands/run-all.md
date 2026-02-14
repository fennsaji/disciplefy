# Run All Services

Start backend, admin web, and frontend (without database reset).

## Usage
```
/run-all
```

## What it does
1. **Backend**: Starts Supabase Edge Functions on port 54321 (no reset)
2. **Admin Web**: Starts Next.js admin dashboard on port 3001
3. **Frontend**: Starts Flutter web app on port 3000

All services run in the background. Use `/tasks` to check their status.

## Instructions

Run all three services in parallel as background tasks:

1. **Backend (no reset)**:
   - Directory: `backend`
   - Command: `sh scripts/run_local_server.sh`
   - Run in background: Yes
   - Description: "Start backend"

2. **Admin Web**:
   - Directory: `admin-web`
   - Command: `npm run dev`
   - Run in background: Yes
   - Description: "Start admin web"

3. **Frontend**:
   - Directory: `frontend`
   - Command: `sh scripts/run-web-local.sh`
   - Run in background: Yes
   - Description: "Start frontend web"

After starting all services, inform the user:
- Backend ready on http://localhost:54321
- Admin web ready on http://localhost:3001
- Frontend ready on http://localhost:3000
- Use `/tasks` to monitor all running services
