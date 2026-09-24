// Reads the signed-in visitor's identity out of wherever the host site already keeps it, so a
// site does not have to write its own glue to call setUser.
//
// A path names a place rather than a value: 'sessionStorage.MC_SESSION_INFO.id' means the key
// MC_SESSION_INFO in sessionStorage, parsed as JSON, then its `id`. Anything missing or
// unparseable reads as undefined; a site's storage is not something to throw over.
const ROOTS = {
  sessionStorage: 'storage',
  localStorage: 'storage',
  window: 'window',
};

const walk = (value, segments) =>
  segments.reduce(
    (current, key) =>
      current === null || current === undefined ? undefined : current[key],
    value
  );

export const readPath = path => {
  if (typeof path !== 'string' || !path) return undefined;

  const [root, key, ...rest] = path.split('.');
  if (!ROOTS[root]) return undefined;

  try {
    if (ROOTS[root] === 'window') return walk(window, [key, ...rest]);

    const raw = window[root].getItem(key);
    if (raw === null) return undefined;
    if (!rest.length) return raw;

    return walk(JSON.parse(raw), rest);
  } catch (error) {
    // Storage can be unreadable (private mode, blocked cookies) and the value may not be JSON.
    // Either way there is no identity to report, which is a normal state, not a failure.
    return undefined;
  }
};

// Chatwoot needs a name, email or avatar alongside the identifier, so a mapping that resolves to
// an identifier and nothing else cannot be used.
export const resolveIdentity = (identifyFrom = {}) => {
  const identifier = readPath(identifyFrom.identifier);
  if (identifier === undefined || identifier === null || identifier === '') {
    return null;
  }

  const user = {};
  ['name', 'email', 'avatar_url', 'phone_number'].forEach(field => {
    const value = readPath(identifyFrom[field]);
    if (value !== undefined && value !== null && value !== '')
      user[field] = value;
  });

  const identifierHash = readPath(identifyFrom.identifierHash);
  if (identifierHash) user.identifier_hash = identifierHash;

  if (!user.name && !user.email && !user.avatar_url) return null;

  return { identifier: String(identifier), user };
};
