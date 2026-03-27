# Disciplefy Admin Panel

A comprehensive Next.js 14 admin dashboard for managing learning paths, study topics, generating AI-powered study guides, and monitoring LLM costs, subscriptions, and promotional campaigns for the Disciplefy Bible Study application.

## Features

### 🎓 Learning Paths Management
- Create and organize structured learning journeys
- Drag-and-drop topic organization with position markers
- Multi-language support (English, Hindi, Malayalam)
- Visual customization with icons and colors
- Milestone tracking and automatic XP calculation
- Reorder paths with visual feedback

### 📚 Study Topics Library
- Comprehensive topic management (Create, Read, Update, Delete)
- CSV bulk import with validation and error reporting
- Advanced filtering by category, input type, and status
- Real-time search across title, description, and tags
- Usage tracking across learning paths
- 12 theological categories and flexible tagging

### ✨ Study Generator
- AI-powered study guide generation
- 5 study modes: Quick (3min), Standard (10min), Deep (25min), Lectio Divina (15min), Sermon (60min)
- Real-time SSE streaming with progressive display
- Generate from existing topics or custom input (topic/verse/question)
- Full content editing with markdown support
- Multi-language generation (English, Hindi, Malayalam)
- 7 comprehensive sections per guide

### 💰 LLM Cost Analytics
- Monitor and analyze LLM API usage and costs across all users and tiers
- Cost tracking and optimization insights

### 👥 Subscription Management
- Update user subscription plans and apply custom discounts
- User tier management

### 🎟️ Promo Code Management
- Create and manage promotional campaigns with flexible eligibility rules

## Tech Stack

### Frontend
- **Next.js 14** - App Router with Server/Client Components
- **TypeScript** - Strict type safety throughout
- **Tailwind CSS** - Utility-first styling
- **React Query** - Server state management (TanStack Query)
- **@dnd-kit** - Drag-and-drop functionality
- **react-markdown** - Markdown rendering with preview
- **papaparse** - CSV parsing for bulk import
- **Recharts** - Data visualization

### Backend
- **Supabase** - Backend as a Service
  - PostgreSQL database with RLS policies
  - Edge Functions (Deno runtime)
  - Real-time subscriptions
  - Authentication & Authorization

## Project Structure

```
admin-web/
├── app/
│   ├── (auth)/
│   │   └── login/                    # Admin login page
│   ├── (dashboard)/
│   │   ├── layout.tsx                # Dashboard shell with sidebar
│   │   ├── page.tsx                  # Overview dashboard
│   │   ├── llm-costs/                # LLM cost analytics
│   │   ├── subscriptions/            # Subscription management
│   │   ├── promo-codes/              # Promo code management
│   │   ├── learning-paths/           # ✨ Learning paths management
│   │   ├── topics/                   # ✨ Study topics library
│   │   └── study-generator/          # ✨ AI study guide generator
│   └── api/
│       └── admin/                    # ✨ Admin API routes
│           ├── learning-paths/       # Learning paths CRUD
│           ├── topics/               # Topics CRUD + bulk import
│           ├── path-topics/          # Path-topic associations
│           └── study-generator/      # Study generation + editing
├── components/
│   ├── dialogs/                      # ✨ Modal dialogs
│   │   ├── create-learning-path-dialog.tsx
│   │   ├── edit-learning-path-dialog.tsx
│   │   ├── path-topic-organizer.tsx
│   │   ├── create-topic-dialog.tsx
│   │   ├── edit-topic-dialog.tsx
│   │   └── bulk-import-dialog.tsx
│   ├── study-generator/              # ✨ Study generator components
│   │   ├── source-selector.tsx
│   │   ├── streaming-preview.tsx
│   │   └── content-editor.tsx
│   ├── tables/                       # ✨ Data tables
│   │   ├── learning-paths-table.tsx
│   │   └── topics-table.tsx
│   ├── ui/                           # ✨ Reusable UI components
│   │   ├── translation-editor.tsx
│   │   ├── icon-color-picker.tsx
│   │   ├── study-mode-selector.tsx
│   │   ├── tags-input.tsx
│   │   ├── dual-list-selector.tsx
│   │   └── markdown-editor.tsx
│   ├── sidebar.tsx                   # Dashboard sidebar
│   └── header.tsx                    # Dashboard header
├── lib/
│   ├── supabase/
│   │   ├── client.ts                 # Browser Supabase client
│   │   └── server.ts                 # Server Supabase client
│   └── api/
│       └── admin.ts                  # ✨ Admin API client functions
├── types/
│   └── admin.ts                      # ✨ TypeScript type definitions
├── docs/                             # ✨ Documentation
│   ├── ADMIN_USER_GUIDE.md          # User documentation
│   └── API_DOCUMENTATION.md         # API reference
└── middleware.ts                     # Auth middleware with admin check
```

## Getting Started

### Prerequisites

- Node.js 18+ installed
- Supabase account and project
- Admin user with `is_admin = true` in `user_profiles` table

### Installation

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Create environment file:**
   ```bash
   cp .env.local.example .env.local
   ```

3. **Update `.env.local` with Supabase credentials:**
   ```env
   NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   ```

4. **Deploy Supabase Edge Functions:**
   ```bash
   cd ../backend/supabase

   # Deploy admin functions
   supabase functions deploy admin-learning-paths
   supabase functions deploy admin-recommended-topics
   supabase functions deploy admin-learning-path-topics
   supabase functions deploy admin-study-generator
   supabase functions deploy admin-study-modifier
   ```

5. **Run development server:**
   ```bash
   npm run dev
   ```

6. **Open browser:**
   ```
   http://localhost:3000
   ```

## Development

### Code Style

Run checks:
```bash
npm run lint          # ESLint
npm run type-check    # TypeScript
npm run format        # Prettier
```

### Building for Production

```bash
npm run build
npm run start
```

## Authentication Flow

1. User navigates to admin panel
2. Middleware checks for valid Supabase session
3. Verifies user has `is_admin = true` in user_profiles table
4. Non-admin users redirected to `/unauthorized`
5. Admin users gain full dashboard access

## Admin Setup

Grant admin access to a user:

```sql
UPDATE user_profiles
SET is_admin = true
WHERE email = 'admin@example.com';
```

## Key Features Overview

### Learning Paths
- **Create**: Multi-step tabbed form with validation
- **Edit**: Full editing with topic organization
- **Organize**: Drag-drop topics with milestone markers
- **Reorder**: Visual drag-drop for display order
- **Translations**: Support for 3 languages

### Study Topics
- **CRUD Operations**: Full create, read, update, delete
- **Bulk Import**: CSV upload with validation
- **Advanced Filters**: Category, type, status, search
- **Usage Tracking**: See which paths use each topic
- **Cascade Delete**: Warnings when deleting used topics

### Study Generator
- **Source Options**: Existing topics or custom input
- **Study Modes**: 5 depth levels from Quick to Sermon
- **Languages**: English, Hindi, Malayalam
- **Real-time Generation**: SSE streaming with progress
- **Full Editing**: Modify all 7 sections after generation

## Documentation

- **User Guide**: [docs/ADMIN_USER_GUIDE.md](./docs/ADMIN_USER_GUIDE.md)
- **API Reference**: [docs/API_DOCUMENTATION.md](./docs/API_DOCUMENTATION.md)

## Security

- All routes protected by middleware
- Admin flag checked on every request
- Service role key used only in server-side API routes
- Supabase RLS policies enforce database security
- Input validation on all forms
- CSRF protection via Next.js

## Performance Optimizations

- React Query caching for server state
- Optimistic updates for instant UI feedback
- SSE streaming for progressive loading
- Lazy loading for translations
- Virtual scrolling for long lists
- Pagination for large datasets

## License

Proprietary - Disciplefy © 2026

## Support

For issues or questions:
- Documentation: `/docs` folder
- Email: support@disciplefy.in

---

**Version**: 1.0.0
**Last Updated**: January 2026
**Total LOC**: ~9,876 lines of production code
