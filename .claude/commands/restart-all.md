# Restart All Services

Restart backend, admin web, and frontend in parallel.

## Usage
```
/restart-all
```

## What it does
1. **Backend**: Resets database and starts Supabase Edge Functions on port 54321
2. **Admin Web**: Starts Next.js admin dashboard on port 3001
3. **Frontend**: Starts Flutter web app on port 3000

All services run in the background. Use `/tasks` to check their status.

## Instructions

Run all three services in parallel as background tasks:

1. **Backend (with database reset)**:
   - Directory: `backend`
   - Command: `sh scripts/run_local_server.sh --reset`
   - Run in background: Yes
   - Description: "Restart backend with database reset"

2. **Admin Web**:
   - Directory: `admin-web`
   - Command: `npm run dev`
   - Run in background: Yes
   - Description: "Restart admin web"

3. **Frontend**:
   - Directory: `frontend`
   - Command: `sh scripts/run-web-local.sh`
   - Run in background: Yes
   - Description: "Restart frontend web"

After starting all services, inform the user:
- Backend will be ready on http://localhost:54321
- Admin web will be ready on http://localhost:3001
- Frontend will be ready on http://localhost:3000
- Use `/tasks` to monitor all running services

Monitor logs from all three services and report any errors.
