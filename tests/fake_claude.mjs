// Stands in for `claude -p --output-format stream-json` in server_test.mjs:
// notes its arguments and prompt (FAKE_CLAUDE_LOG, one JSON line per call) and
// answers with the question's first line. A run that resumes nothing gets a
// session of its own; a question saying "lourde" leaves a very large session,
// "longue" one worth renewing after a pause, "forfait" says how much of the plan
// is used ("forfait épuisé": with no answer). The session's price: 0.03 dollars, 0.05 once
// resumed; "refus" with a key: the key is refused.

import fs from 'node:fs';

let prompt = '';
for await (const chunk of process.stdin) prompt += chunk;
const args = process.argv.slice(2);
const option = (name) => (args.includes(name) ? args[args.indexOf(name) + 1] : null);
fs.appendFileSync(process.env.FAKE_CLAUDE_LOG, `${JSON.stringify({ args, prompt, key: process.env.ANTHROPIC_API_KEY })}\n`);
const question = prompt.split('\n')[2] || '';
const held = question.includes('lourde') ? 300000 : question.includes('longue') ? 100000 : 30000;
const usage = { input_tokens: 2, cache_creation_input_tokens: 1000, cache_read_input_tokens: held, output_tokens: 100 };
const model = `claude-${option('--model') || 'opus'}-5-5`;
const key = process.env.ANTHROPIC_API_KEY;
console.log(JSON.stringify({ type: 'system', subtype: 'init', apiKeySource: key ? 'ANTHROPIC_API_KEY' : 'none' }));
if (question.includes('forfait')) {
  console.log(JSON.stringify({ type: 'rate_limit_event', rate_limit_info: { status: 'allowed', rateLimitType: 'five_hour', unifiedWindows: {
    five_hour: { utilization: 0.3, resetsAt: 1795567200, status: 'allowed' }, seven_day: { utilization: 0.555, resetsAt: 1795870800, status: 'allowed' },
    seven_day_opus: { utilization: 0.1, resetsAt: 1795870800 }, overage: { utilization: 1 },
  } } }));
}
if (key && question.includes('refus')) {
  console.log(JSON.stringify({ type: 'result', subtype: 'success', is_error: true, result: 'Invalid API key · Fix external API key' }));
  process.exit(1);
}
if (question.includes('forfait épuisé')) {
  console.log(JSON.stringify({ type: 'result', subtype: 'success', is_error: true, result: 'limite du forfait atteinte' }));
  process.exit(1);
}
console.log(JSON.stringify({ type: 'assistant', parent_tool_use_id: null, message: { model, usage } }));
console.log(JSON.stringify({ type: 'result', subtype: 'success', is_error: false, result: `Réponse : ${question}`, usage, total_cost_usd: option('--resume') ? 0.05 : 0.03, modelUsage: { [model]: { inputTokens: 4, outputTokens: 900, cacheCreationInputTokens: 90000, cacheReadInputTokens: 900000 } }, session_id: option('--resume') || `session-${process.pid}` }));
