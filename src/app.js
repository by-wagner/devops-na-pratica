// @ts-check
import { createServer } from 'node:http';

/** @typedef {{ id: number, title: string, done: boolean }} Task */

/**
 * @param {import('node:http').ServerResponse} res
 * @param {number} status
 * @param {unknown} body
 */
function sendJson(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

/** @param {import('node:http').IncomingMessage} req */
async function readBody(req) {
  let raw = '';
  for await (const chunk of req) raw += chunk;
  return raw;
}

/**
 * Converte o corpo bruto em título válido, ou retorna null se for inválido.
 * @param {string} raw
 * @returns {string | null}
 */
function parseTitle(raw) {
  try {
    const { title } = JSON.parse(raw);
    return typeof title === 'string' && title.trim() ? title.trim() : null;
  } catch {
    return null;
  }
}

/** Cria o servidor HTTP da API. Armazenamento em memória (sem banco nesta fase). */
export function createApp() {
  /** @type {Task[]} */
  const tasks = [];

  return createServer(async (req, res) => {
    if (req.method === 'GET' && req.url === '/health') return sendJson(res, 200, { status: 'ok' });
    if (req.method === 'GET' && req.url === '/tasks') return sendJson(res, 200, tasks);
    if (req.method === 'POST' && req.url === '/tasks') {
      const title = parseTitle(await readBody(req));
      if (!title) return sendJson(res, 400, { error: 'Envie um JSON no formato {"title": "texto não vazio"}' });
      const task = { id: tasks.length + 1, title, done: false };
      tasks.push(task);
      return sendJson(res, 201, task);
    }
    sendJson(res, 404, { error: `Rota não encontrada: ${req.method} ${req.url}` });
  });
}
