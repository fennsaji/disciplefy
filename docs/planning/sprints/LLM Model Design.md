````markdown
# 📘 LLM Model Requirements & Implementation Guide

> **Disciplefy: Bible Study App**  
> AI‑powered study‐guide generator using Supabase Edge Functions and OpenAI/Claude APIs  
> **Last Updated:** July 2025

---

## 1. 🎯 Purpose
Provide an AI‑powered “study guide” generator that delivers theologically sound, contextually accurate, and devotional content based on any Bible reference or topic input.

---

## 2. ⚙️ Platform & API Overview

| Component                | Technology                                   |
|--------------------------|----------------------------------------------|
| LLM Provider             | OpenAI (GPT‑3.5/GPT‑4) or Anthropic Claude   |
| Backend                  | Supabase Edge Functions (TypeScript)         |
| Database & Auth          | Supabase PostgreSQL + Supabase Auth (RLS)    |
| Hosting & CI/CD          | GitHub Actions → Supabase CLI                |
| Monitoring & Logging     | Sentry + Supabase Logs                       |

---

## 3. 🧱 System & Prompt Design

### 3.1 System Prompt (Edge Function)
In `src/functions/_shared/systemPrompt.ts`:
```ts
export const SYSTEM_PROMPT = `
You are Disciplefy StudyBot, a theological AI assistant.
Always base every statement on canonical Scripture.
Cite explicit verses in brackets.
Maintain a devotional, objective, non‑denominational tone.
Respond only with structured JSON matching our schema.
`;
````

### 3.2 Prompt Template (User Level)

In `src/functions/_shared/promptTemplates.ts`:

```ts
export function makeStudyPrompt(params: {
  inputType: "scripture" | "topic";
  inputValue: string;
  language: string;
}) {
  const { inputType, inputValue, language } = params;
  return `
${SYSTEM_PROMPT}
USER:
{"input_type":"${inputType}","input_value":"${inputValue}","language":"${language}"}

ASSISTANT: Produce a study guide that includes:
1. Context: 
2. Interpretation:
3. Life Application:
4. Discussion Questions:
5. Related Verses:
`;
}
```

---

## 4. 🔌 Supabase Edge Function Implementation

### 4.1 Project Structure

```
backend/
└── supabase/
    ├── functions/
    │   ├── study-generate/         # generate-study-guide.ts
    │   ├── topics-recommend/       # topics-recommend.ts
    │   └── _shared/
    │       ├── systemPrompt.ts
    │       └── promptTemplates.ts
    ├── migrations/
    │   └── 20250705000001_initial.sql
    └── supabase/
        └── config.toml
```

### 4.2 `study-generate` Function (TypeScript)

In `backend/supabase/functions/study-generate/index.ts`:

```ts
import { serve } from "https://deno.land/x/sift/mod.ts";
import { createClient } from "https://deno.land/x/supabase/mod.ts";
import { SYSTEM_PROMPT, makeStudyPrompt } from "../_shared/promptTemplates.ts";
import { callLLM } from "../_shared/llmClient.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

serve(async (req) => {
  try {
    const { input_type, input_value, language, user_context } = await req.json();
    const prompt = makeStudyPrompt({ inputType: input_type, inputValue: input_value, language });

    // Call OpenAI/Claude
    const llmResponse = await callLLM(prompt);

    // Validate & sanitize output
    const validated = validateAndSanitize(llmResponse);
    if (!validated.ok) throw new Error("Invalid LLM output");

    // Cache result
    await supabase
      .from("study_guides_cache")
      .insert({ input_type, input_value, language, content: validated.data });

    return new Response(JSON.stringify({ success: true, guide: validated.data }), { status: 200 });
  } catch (err) {
    console.error("Study-generate error:", err);
    return new Response(JSON.stringify({ success: false, error: err.message }), { status: 500 });
  }
});
```

### 4.3 LLM Client Wrapper

In `backend/supabase/functions/_shared/llmClient.ts`:

```ts
export async function callLLM(prompt: string): Promise<string> {
  const apiKey = Deno.env.get("OPENAI_API_KEY")!;
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-3.5-turbo",
      messages: [{ role: "system", content: prompt }],
      max_tokens: 800,
    }),
  });
  const json = await res.json();
  return json.choices?.[0]?.message?.content ?? "";
}
```

---

## 5. 🔍 Validation & Sanitization

### 5.1 JSON Schema

Create `StudyGuideSchema` in `src/functions/_shared/schema.ts`:

```ts
import { z } from "https://deno.land/x/zod/mod.ts";

export const StudyGuideSchema = z.object({
  context: z.string().min(50),
  interpretation: z.string().min(50),
  life_application: z.string().min(50),
  discussion_questions: z.array(z.string()).min(1),
  related_verses: z.array(z.string()).min(1),
});

export type StudyGuide = z.infer<typeof StudyGuideSchema>;
```

### 5.2 Validation Function

In `backend/supabase/functions/_shared/validation.ts`:

```ts
import { StudyGuideSchema } from "./schema.ts";

export function validateAndSanitize(raw: string) {
  try {
    const parsed = JSON.parse(raw);
    const result = StudyGuideSchema.safeParse(parsed);
    if (!result.success) return { ok: false };
    // Additional topic‐alignment check...
    return { ok: true, data: result.data };
  } catch {
    return { ok: false };
  }
}
```

---

## 6. 📊 Database & Caching

### 6.1 `study_guides_cache` Table (SQL migration)

```sql
create table study_guides_cache (
  id uuid default gen_random_uuid() primary key,
  input_type text not null,
  input_value text not null,
  language text not null,
  content jsonb not null,
  created_at timestamptz default now()
);
```

### 6.2 Row Level Security

```sql
alter table study_guides_cache enable row level security;

create policy "public read cache" on study_guides_cache
  for select using (true);

create policy "cache write" on study_guides_cache
  for insert using (auth.role() = 'service_role');
```

---

## 7. 💸 Cost & Rate Limiting

* **Budget**: ≤ \$15/mo for first 500 calls
* **Rate Limiting** (in `config.toml`):

  ```toml
  [auth.rate_limits]
  anonymous = { max = 3, window = "1h" }
  authenticated = { max = 30, window = "1h" }
  ```
* **Caching**: frequent inputs served from `study_guides_cache`

---

## 8. 🛠️ Deployment & CI/CD

### 8.1 GitHub Actions Workflow (`.github/workflows/deploy.yml`)

```yaml
name: Deploy Supabase Functions

on:
  push:
    branches: [ main ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Deno
        uses: denoland/setup-deno@v1
      - name: Install Supabase CLI
        run: npm install -g supabase
      - name: Deploy Migrations
        run: supabase db push --project ${{ secrets.SUPABASE_PROJECT_REF }}
      - name: Deploy Edge Functions
        run: supabase functions deploy --project ${{ secrets.SUPABASE_PROJECT_REF }} --force
```

### 8.2 Environment Variables (GitHub Secrets)

* `SUPABASE_URL`
* `SUPABASE_SERVICE_ROLE_KEY`
* `OPENAI_API_KEY`
* `CLAUDE_API_KEY` (if using Anthropic)

---

## 9. 🔐 Security & Compliance

* **Prompt Injection**: sanitize inputs, enforce 100‑char limit
* **PII**: never include personal data
* **Access Control**: Supabase RLS policies + JWT validation
* **Output Filtering**: JSON schema enforcement + topic alignment
