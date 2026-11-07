// @ts-check
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';

let server;
let baseUrl;

before(async () => {
  server = createApp();
  await new Promise((resolve) => server.listen(0, resolve)); // porta 0 = o SO escolhe uma porta livre
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

test('deve_retornarOk_quando_healthForRequisitado', async () => {
  const res = await fetch(`${baseUrl}/health`);

  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { status: 'ok' });
});

test('deve_criarTarefa_quando_tituloForValido', async () => {
  const res = await fetch(`${baseUrl}/tasks`, {
    method: 'POST',
    body: JSON.stringify({ title: 'Configurar pipeline' }),
  });

  assert.equal(res.status, 201);
  const task = await res.json();
  assert.equal(task.title, 'Configurar pipeline');
  assert.equal(task.done, false);
});

test('deve_listarTarefasCriadas_quando_tarefasForemRequisitadas', async () => {
  const res = await fetch(`${baseUrl}/tasks`);

  assert.equal(res.status, 200);
  const tasks = await res.json();
  assert.ok(tasks.some((t) => t.title === 'Configurar pipeline'));
});

test('deve_retornar400_quando_tituloEstiverAusente', async () => {
  const res = await fetch(`${baseUrl}/tasks`, { method: 'POST', body: '{}' });

  assert.equal(res.status, 400);
});

test('deve_retornar400_quando_corpoNaoForJson', async () => {
  const res = await fetch(`${baseUrl}/tasks`, { method: 'POST', body: 'not json' });

  assert.equal(res.status, 400);
});

test('deve_retornar404_quando_rotaForDesconhecida', async () => {
  const res = await fetch(`${baseUrl}/nope`);

  assert.equal(res.status, 404);
});
