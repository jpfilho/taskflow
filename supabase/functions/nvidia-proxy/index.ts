import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

serve(async (req: Request) => {
  // Tratar requisição OPTIONS prévia do CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { systemPrompt, userPrompt, modelName, temperature, maxTokens, apiKey } = await req.json();

    // Prioriza a chave enviada pelo cliente; se vazia, usa a do servidor
    const activeApiKey = apiKey || Deno.env.get("NVIDIA_API_KEY");

    if (!activeApiKey) {
      return new Response(
        JSON.stringify({ error: "Chave da API NVIDIA não configurada nem no cliente nem no servidor." }),
        { 
          status: 400, 
          headers: { 
            ...corsHeaders, 
            "Content-Type": "application/json" 
          } 
        }
      );
    }

    console.log(`🤖 nvidia-proxy: Enviando prompt para o modelo ${modelName}`);

    const response = await fetch('https://integrate.api.nvidia.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${activeApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: modelName,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: temperature ?? 0.3,
        max_tokens: maxTokens ?? 2048,
      }),
    });

    const data = await response.json();

    return new Response(
      JSON.stringify(data),
      {
        status: response.status,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        }
      }
    );
  } catch (error) {
    console.error("❌ Erro no proxy NVIDIA:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { 
          ...corsHeaders, 
          "Content-Type": "application/json" 
        } 
      }
    );
  }
});
