/**
 * DEVA Stateless Proxy (Cloudflare Worker)
 * 
 * This worker acts as an invisible shield for your Groq API key.
 * It receives the AI request from the Flutter app, attaches the key securely,
 * sends it to Groq, and returns the response.
 * 
 * NO DATA IS SAVED. NO LOGS ARE KEPT.
 * 
 * Instructions:
 * 1. Install wrangler: `npm install -g wrangler`
 * 2. Login: `wrangler login`
 * 3. Create project: `wrangler init deva-proxy` (choose "Hello World worker")
 * 4. Replace `src/index.js` with this file.
 * 5. Add your Groq API key as a secret: `wrangler secret put GROQ_API_KEY`
 * 6. Deploy: `wrangler deploy`
 * 7. Copy the deployed URL and paste it into `app_constants.dart` in the Flutter app.
 */

export default {
  async fetch(request, env, ctx) {
    // Only allow POST requests
    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    try {
      // 1. Read the request body from the app
      const body = await request.text();

      // 2. Forward to Groq, attaching the hidden API key from environment secrets
      const groqResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.GROQ_API_KEY}`
        },
        body: body
      });

      // 3. Get the response from Groq
      const data = await groqResponse.text();

      // 4. Return it back to the app
      return new Response(data, {
        status: groqResponse.status,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    } catch (error) {
      return new Response(JSON.stringify({ error: 'Proxy Error' }), { status: 500 });
    }
  },
};
