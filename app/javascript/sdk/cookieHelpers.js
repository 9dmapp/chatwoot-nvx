import Cookies from 'js-cookie';

const REQUIRED_USER_KEYS = ['avatar_url', 'email', 'name'];
const ALLOWED_USER_ATTRIBUTES = [...REQUIRED_USER_KEYS, 'identifier_hash'];
// FNV-1a-128 held as four 32-bit limbs, least significant first. The arithmetic below is the
// same hash as a BigInt implementation and the test vectors prove it; what it avoids is touching
// the page's `BigInt`, which host sites do replace. One brand's vendor bundle shipped a shim
// returning undefined with no asUintN, which made every setUser throw and silently disabled
// visitor identity. A fingerprint for change detection should not be able to break that way.
const FNV1A_128_OFFSET_BASIS = [0x6295c58d, 0x62b82175, 0x07bb0142, 0x6c62272e];
// The prime is 2**88 + 0x13b, so multiplying is a shift by 88 plus a small multiply.
const FNV1A_128_PRIME_LOW = 0x13b;
const UINT32 = 0x100000000;
const CONTACT_INFORMATION_ATTRIBUTES = [
  'phone_number',
  'company_name',
  'city',
  'country_code',
  'description',
  'social_profiles',
];

const normalizeUserAttribute = value => {
  if (!value || typeof value !== 'object') return value || '';

  return Object.keys(value)
    .sort()
    .map(key => [key, value[key]]);
};

export const getUserCookieName = () => {
  const SET_USER_COOKIE_PREFIX = 'cw_user_';
  const { websiteToken: websiteIdentifier } = window.$chatwoot;
  return `${SET_USER_COOKIE_PREFIX}${websiteIdentifier}`;
};

export const getUserString = ({ identifier = '', user }) => {
  const userAttributes = [
    ...ALLOWED_USER_ATTRIBUTES.map(key => [key, user[key] || '']),
    ...CONTACT_INFORMATION_ATTRIBUTES.filter(
      key => user[key] !== undefined
    ).map(key => [key, normalizeUserAttribute(user[key])]),
    ['identifier', String(identifier)],
  ];
  return JSON.stringify(userAttributes);
};

// h * (2**88 + 0x13b) mod 2**128, in place.
const multiplyByPrime = h => {
  // The small multiply: each limb times 0x13b stays under 2**53, so it is exact in a double.
  const low = [0, 0, 0, 0];
  let carry = 0;
  for (let i = 0; i < 4; i += 1) {
    const product = h[i] * FNV1A_128_PRIME_LOW + carry;
    low[i] = product % UINT32;
    carry = Math.floor(product / UINT32);
  }

  // The shift: 88 bits is two whole limbs plus 24, so only limbs 2 and 3 can be reached.
  const shifted = [
    0,
    0,
    (h[0] << 24) >>> 0, // eslint-disable-line no-bitwise
    ((h[0] >>> 8) + ((h[1] << 24) >>> 0)) >>> 0, // eslint-disable-line no-bitwise
  ];

  carry = 0;
  for (let i = 0; i < 4; i += 1) {
    const sum = low[i] + shifted[i] + carry;
    h[i] = sum % UINT32;
    carry = sum >= UINT32 ? 1 : 0;
  }
};

export const fnv1a128 = value => {
  const data = new TextEncoder().encode(value);
  const hash = [...FNV1A_128_OFFSET_BASIS];

  data.forEach(byte => {
    hash[0] = (hash[0] ^ byte) >>> 0; // eslint-disable-line no-bitwise
    multiplyByPrime(hash);
  });

  return hash
    .map(limb => limb.toString(16).padStart(8, '0'))
    .reverse()
    .join('');
};

export const computeHashForUserData = (...args) =>
  fnv1a128(getUserString(...args));

export const hasUserKeys = user =>
  REQUIRED_USER_KEYS.reduce((acc, key) => acc || !!user[key], false);

export const setCookieWithDomain = (
  name,
  value,
  { expires = 365, baseDomain = undefined } = {}
) => {
  const cookieOptions = {
    expires,
    sameSite: 'Lax',
    domain: baseDomain,
  };

  // if type of value is object, stringify it
  // this is because js-cookies 3.0 removed builtin json support
  // ref: https://github.com/js-cookie/js-cookie/releases/tag/v3.0.0
  if (typeof value === 'object') {
    value = JSON.stringify(value);
  }

  Cookies.set(name, value, cookieOptions);
};
