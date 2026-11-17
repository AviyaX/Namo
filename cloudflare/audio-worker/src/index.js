// Serves the chant recordings from the R2 bucket bound as AUDIO.
//
// GET and HEAD only, keys under audio/ only. Range requests work (the players
// seek with them). Every object was uploaded with Content-Type audio/mp4 and a
// one-year immutable Cache-Control; both are passed through, with defaults in
// case an object lacks them. Nothing is logged and nothing identifies the
// caller: the Worker only reads the path and the Range header.

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD',
  'Access-Control-Allow-Headers': 'Range',
  'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Accept-Ranges, ETag',
  'Access-Control-Max-Age': '86400',
};

function notFound() {
  return new Response('Not found', { status: 404, headers: CORS });
}

function headersFor(object) {
  const headers = new Headers(CORS);
  object.writeHttpMetadata(headers);
  if (!headers.has('Content-Type')) headers.set('Content-Type', 'audio/mp4');
  if (!headers.has('Cache-Control')) {
    headers.set('Cache-Control', 'public, max-age=31536000, immutable');
  }
  headers.set('ETag', object.httpEtag);
  headers.set('Accept-Ranges', 'bytes');
  return headers;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method not allowed', {
        status: 405,
        headers: { ...CORS, Allow: 'GET, HEAD' },
      });
    }
    let key;
    try {
      key = decodeURIComponent(new URL(request.url).pathname.slice(1));
    } catch (_) {
      return notFound();
    }
    if (!key.startsWith('audio/') || key.includes('..')) return notFound();

    if (request.method === 'HEAD') {
      const object = await env.AUDIO.head(key);
      if (object === null) return notFound();
      const headers = headersFor(object);
      headers.set('Content-Length', String(object.size));
      return new Response(null, { status: 200, headers });
    }

    const object = await env.AUDIO.get(key, {
      range: request.headers,
      onlyIf: request.headers,
    });
    if (object === null) return notFound();
    const headers = headersFor(object);
    if (!('body' in object)) {
      // A conditional request whose condition failed.
      return new Response(null, { status: 304, headers });
    }
    if (object.range) {
      const { offset = 0, length, suffix } = object.range;
      const start = suffix === undefined ? offset : object.size - suffix;
      const count = suffix === undefined ? length ?? object.size - start : suffix;
      headers.set('Content-Range', `bytes ${start}-${start + count - 1}/${object.size}`);
      headers.set('Content-Length', String(count));
      return new Response(object.body, { status: 206, headers });
    }
    headers.set('Content-Length', String(object.size));
    return new Response(object.body, { status: 200, headers });
  },
};
