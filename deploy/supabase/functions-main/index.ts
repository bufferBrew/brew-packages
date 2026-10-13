// Router for the self-hosted Edge Runtime: /<function>/... → a worker running
// the app's supabase/functions/<function>/index.ts. Same contract as
// Supabase's platform: the caller's JWT is verified first (HS256 with
// JWT_SECRET) unless VERIFY_JWT=false, and every worker sees this
// container's environment (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
// TOKEN_ENCRYPTION_KEY, and the app's own secrets).
//
// Dependencies: bare imports (e.g. 'fast-xml-parser') resolve through a
// deno.json with an "imports" map at the root of the app's functions folder
// (or in a function's own folder); the runtime finds it by walking up. A
// legacy import_map.json alone is ignored here.
//
// Copied into every Brew app by brew/sync-deploy.sh from brew-packages.

const JWT_SECRET = Deno.env.get('JWT_SECRET') ?? '';
const VERIFY_JWT = (Deno.env.get('VERIFY_JWT') ?? 'true') !== 'false';
const FUNCTIONS_DIR = '/home/deno/functions';

const encoder = new TextEncoder();
let hmacKey: CryptoKey | undefined;

function b64urlDecode(s: string): Uint8Array {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(s.length / 4) * 4, '=');
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

async function verifyJwt(token: string): Promise<boolean> {
  const parts = token.split('.');
  if (parts.length !== 3) return false;
  hmacKey ??= await crypto.subtle.importKey(
    'raw', encoder.encode(JWT_SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify'],
  );
  const ok = await crypto.subtle.verify(
    'HMAC', hmacKey, b64urlDecode(parts[2]), encoder.encode(`${parts[0]}.${parts[1]}`),
  );
  if (!ok) return false;
  const payload = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[1])));
  return typeof payload.exp !== 'number' || payload.exp * 1000 > Date.now();
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  const name = new URL(req.url).pathname.split('/').filter(Boolean)[0];
  if (!name || name.startsWith('_') || name.includes('..')) {
    return json(404, { error: 'function not found' });
  }

  // Preflights carry no credentials; the function answers them itself.
  if (VERIFY_JWT && req.method !== 'OPTIONS') {
    const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '') ?? '';
    if (!(await verifyJwt(token))) return json(401, { error: 'invalid JWT' });
  }

  try {
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath: `${FUNCTIONS_DIR}/${name}`,
      memoryLimitMb: 256,
      workerTimeoutMs: 5 * 60 * 1000,
      noModuleCache: false,
      importMapPath: null,
      envVars: Object.entries(Deno.env.toObject()),
    });
    return await worker.fetch(req);
  } catch (e) {
    console.error(`function ${name} failed:`, e);
    return json(500, { error: `function ${name} failed`, detail: String(e) });
  }
});
