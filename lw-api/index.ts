// server.js

import { serve } from 'bun';
import TurndownService from 'turndown';
import gfm from 'turndown-plugin-gfm';

const turndownService = new TurndownService();
turndownService.use(gfm.gfm);

const handler = async (req) => {
  if (req.method === 'POST') {
    try {
      const html = await req.text();
      const markdown = turndownService.turndown(html);

      return new Response(markdown, {
        headers: {
          'Content-Type': 'text/plain',
        },
      });
    } catch (error) {
      return new Response('Error processing HTML', { status: 500 });
    }
  } else {
    return new Response('Method Not Allowed', { status: 405 });
  }
};

const server = serve({
  port: 3000,
  fetch: handler,
});

console.log(`Server running at http://localhost:3000`);

