import { serve } from "https://deno.land/std@0.208.0/http/server.ts"

serve(async (req: Request): Promise<Response> => {
  const envInfo = {
    anthropicKey: Deno.env.get('ANTHROPIC_API_KEY'),
    anthropicKeyLength: Deno.env.get('ANTHROPIC_API_KEY')?.length || 0,
    anthropicKeyStart: Deno.env.get('ANTHROPIC_API_KEY')?.substring(0, 20) || 'MISSING',
    openaiKey: Deno.env.get('OPENAI_API_KEY'),
    openaiKeyLength: Deno.env.get('OPENAI_API_KEY')?.length || 0,
    allEnvVars: Object.keys(Deno.env.toObject()).filter(key => 
      key.includes('API') || key.includes('KEY') || key.includes('ANTHROPIC') || key.includes('OPENAI')
    )
  }

  return new Response(JSON.stringify(envInfo, null, 2), {
    headers: { 'Content-Type': 'application/json' }
  })
})