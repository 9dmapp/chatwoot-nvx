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

  // `customAttributes` maps an attribute key to a path, read the same way as the fields above.
  // These ride along on set_user rather than making a second request: the widget already
  // forwards `custom_attributes` and the endpoint already permits it.
  //
  // Values are stringified because the attribute definitions this is written for are all of
  // display type `text`. A numeric id stored as a JSON number renders, but then fails to match
  // a text filter in the dashboard - silently, which is the worst way for it to fail.
  const customAttributes = {};
  Object.entries(identifyFrom.customAttributes || {}).forEach(([key, path]) => {
    const value = readPath(path);
    if (value !== undefined && value !== null && value !== '') {
      customAttributes[key] = String(value);
    }
  });
  if (Object.keys(customAttributes).length) {
    user.custom_attributes = customAttributes;
  }

  // Chatwoot requires one of these alongside the identifier; custom attributes do not satisfy it.
  if (!user.name && !user.email && !user.avatar_url) return null;

  return { identifier: String(identifier), user };
};
