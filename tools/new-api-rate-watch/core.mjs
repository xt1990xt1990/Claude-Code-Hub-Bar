class HttpError extends Error {
  constructor(status, url, body) {
    super(`HTTP ${status} from ${url}: ${JSON.stringify(body).slice(0, 240)}`);
    this.status = status;
    this.url = url;
    this.body = body;
  }
}

function getFetch(fetchImpl) {
  const impl = fetchImpl || globalThis.fetch;
  if (typeof impl !== 'function') {
    throw new Error('fetch is not available. Use Node.js 18+ or pass fetchImpl.');
  }
  return impl;
}

function normalizeBaseUrl(baseUrl) {
  if (!baseUrl) throw new Error('baseUrl is required');
  return String(baseUrl).replace(/\/+$/, '');
}

function readField(object, camelName, snakeName) {
  return object?.[camelName] ?? object?.[snakeName];
}

function unwrapApiResponse(body) {
  if (
    body &&
    typeof body === 'object' &&
    Object.prototype.hasOwnProperty.call(body, 'success')
  ) {
    if (body.success === false) {
      throw new Error(`API error: ${body.message || 'unknown error'}`);
    }
    return body.data;
  }
  return body;
}

async function requestJson(fetchImpl, url, options = {}) {
  const response = await fetchImpl(url, options);
  const text = await response.text();
  let body;

  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    throw new Error(`Non-JSON response from ${url}: ${text.slice(0, 160)}`);
  }

  if (!response.ok) {
    throw new HttpError(response.status, url, body);
  }

  return unwrapApiResponse(body);
}

function authHeaders(site) {
  const accessToken = readField(site, 'accessToken', 'access_token');
  const userId = readField(site, 'userId', 'user_id');
  const cookieHeader = readField(site, 'cookieHeader', 'cookie_header');
  const headers = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  };

  if (accessToken) {
    headers.Authorization = `Bearer ${accessToken}`;
  }
  if (userId !== undefined && userId !== null && String(userId).trim() !== '') {
    headers['New-Api-User'] = String(userId);
  }
  if (cookieHeader !== undefined && cookieHeader !== null && String(cookieHeader).trim() !== '') {
    headers.Cookie = String(cookieHeader);
  }
  return headers;
}

function readTargetApiKey(site) {
  return site.apiKey ?? site.api_key ?? site.key ?? null;
}

function normalizeApiKey(apiKey) {
  return String(apiKey || '').trim().replace(/^sk-/i, '');
}

function keyPrefix(apiKey) {
  const normalized = normalizeApiKey(apiKey);
  if (!normalized) return '';
  return `${normalized.slice(0, 8)}...${normalized.slice(-4)}`;
}

function apiKeySuffix(apiKey) {
  const normalized = normalizeApiKey(apiKey).replaceAll('*', '');
  if (normalized.length < 4) return '';
  return normalized.slice(-4);
}

function tokenSearchQueries(apiKey) {
  const normalized = normalizeApiKey(apiKey);
  const suffix = apiKeySuffix(apiKey);
  if (normalized.length <= 4 && suffix) {
    return [`%${suffix}`, null];
  }
  return [normalized, suffix ? `%${suffix}` : null, null];
}

function pageItems(data) {
  if (Array.isArray(data)) return data;
  return data?.items || data?.data?.items || [];
}

function pageTotal(data, items) {
  return Number(data?.total ?? data?.data?.total ?? items.length);
}

async function listTokensPage(site, options, page, tokenQuery = undefined) {
  const fetchImpl = getFetch(options.fetchImpl);
  const baseUrl = normalizeBaseUrl(site.baseUrl ?? site.base_url);
  const pageSize = Number(site.pageSize || site.page_size || 100);
  const keyName = readField(site, 'keyName', 'key_name');
  const apiKey = readTargetApiKey(site);

  const params = new URLSearchParams({
    p: String(page - 1),
    size: String(pageSize),
  });

  if (tokenQuery !== undefined && tokenQuery !== null && String(tokenQuery).trim() !== '') {
    params.set('token', String(tokenQuery));
  } else if (apiKey && tokenQuery !== null) {
    params.set('token', normalizeApiKey(apiKey));
  } else if (keyName) {
    params.set('keyword', String(keyName));
  }

  const data = await requestJson(fetchImpl, `${baseUrl}/api/token/search?${params}`, {
    headers: authHeaders(site),
  });
  const items = pageItems(data);
  const total = pageTotal(data, items);
  return { items, total, pageSize };
}

function tokenNameMatches(token, keyName) {
  const normalizedName = String(token.name || '').toLowerCase();
  const target = String(keyName || '').toLowerCase();
  return normalizedName === target || normalizedName.includes(target);
}

function tokenKeyMatches(tokenKey, targetApiKey) {
  const normalizedTokenKey = normalizeApiKey(tokenKey);
  const normalizedTarget = normalizeApiKey(targetApiKey);
  return Boolean(normalizedTokenKey && normalizedTarget && normalizedTokenKey === normalizedTarget);
}

function tokenKeySuffixMatches(tokenKey, targetApiKey) {
  const tokenSuffix = apiKeySuffix(tokenKey);
  const targetSuffix = apiKeySuffix(targetApiKey);
  return Boolean(tokenSuffix && targetSuffix && tokenSuffix === targetSuffix);
}

function maskedTokenMayMatch(tokenKey, targetApiKey) {
  const normalizedTokenKey = normalizeApiKey(tokenKey);
  const normalizedTarget = normalizeApiKey(targetApiKey);
  if (!normalizedTokenKey || !normalizedTarget) return false;
  return (
    normalizedTokenKey.includes('*') &&
    normalizedTarget.startsWith(normalizedTokenKey.slice(0, 4)) &&
    normalizedTarget.endsWith(normalizedTokenKey.slice(-4))
  );
}

function tokenMayMatchAfterReveal(tokenKey, targetApiKey) {
  return maskedTokenMayMatch(tokenKey, targetApiKey) || tokenKeySuffixMatches(tokenKey, targetApiKey);
}

async function revealTokenKey(site, tokenId, options) {
  const fetchImpl = getFetch(options.fetchImpl);
  const baseUrl = normalizeBaseUrl(site.baseUrl ?? site.base_url);
  const data = await requestJson(fetchImpl, `${baseUrl}/api/token/${tokenId}/key`, {
    method: 'POST',
    headers: authHeaders(site),
    body: JSON.stringify({}),
  });

  return typeof data === 'string' ? data.trim() : String(data?.key || '').trim();
}

async function hydrateAndMatchToken(site, token, options) {
  const apiKey = readTargetApiKey(site);
  if (!apiKey) return token;

  if (tokenKeyMatches(token.key, apiKey)) {
    return token;
  }

  if (token.id == null || !tokenMayMatchAfterReveal(token.key, apiKey)) {
    return null;
  }

  const fullKey = await revealTokenKey(site, token.id, options);
  if (!tokenKeyMatches(fullKey, apiKey) && !tokenKeySuffixMatches(fullKey, apiKey)) {
    return null;
  }

  return {
    ...token,
    key: fullKey,
  };
}

async function findConfiguredToken(site, options) {
  const baseUrl = normalizeBaseUrl(site.baseUrl ?? site.base_url);
  const apiKey = readTargetApiKey(site);
  const keyName = readField(site, 'keyName', 'key_name');
  const maxPages = Number(site.maxPages || site.max_pages || 20);

  if (!apiKey && !keyName) {
    throw new Error(`${site.name || baseUrl}: apiKey is required`);
  }

  const tokenQueries = apiKey ? tokenSearchQueries(apiKey) : [undefined];

  for (const tokenQuery of tokenQueries) {
    for (let page = 1; page <= maxPages; page += 1) {
      const { items, total, pageSize } = await listTokensPage(site, options, page, tokenQuery);
      const candidates = apiKey ? items : items.filter((token) => tokenNameMatches(token, keyName));

      for (const token of candidates) {
        const matched = await hydrateAndMatchToken(site, token, options);
        if (matched) return matched;
      }

      if (items.length < pageSize || page * pageSize >= total) {
        break;
      }
    }
  }

  if (apiKey) {
    throw new Error(`${site.name || baseUrl}: apiKey ${keyPrefix(apiKey)} not found`);
  }

  throw new Error(`${site.name || baseUrl}: key named "${keyName}" not found`);
}

async function listUserGroups(site, options) {
  const fetchImpl = getFetch(options.fetchImpl);
  const baseUrl = normalizeBaseUrl(site.baseUrl ?? site.base_url);
  const data = await requestJson(fetchImpl, `${baseUrl}/api/user/self/groups`, {
    headers: authHeaders(site),
  });
  return data && typeof data === 'object' ? data : {};
}

function normalizeRatio(value) {
  if (value === '自动') return value;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function normalizeGroup(groupName, groupInfo) {
  if (!groupName) return null;
  const ratio = normalizeRatio(groupInfo?.ratio);
  return {
    name: groupName,
    ratio,
    desc: groupInfo?.desc ?? null,
    raw: groupInfo ?? null,
  };
}

function normalizeToken(token) {
  return {
    id: token.id ?? null,
    keyPrefix: token.key ? keyPrefix(token.key) : '',
    name: token.name ?? '',
    group: token.group ?? '',
    status: token.status ?? null,
  };
}

export async function fetchSiteKeyRate(site, opts = {}) {
  const options = {
    fetchImpl: opts.fetchImpl,
  };
  const baseUrl = normalizeBaseUrl(site.baseUrl ?? site.base_url);
  const token = await findConfiguredToken({ ...site, baseUrl }, options);
  const groups = await listUserGroups({ ...site, baseUrl }, options);
  const group = normalizeGroup(token.group, groups[token.group]);

  return {
    provider: 'new-api',
    site: {
      name: site.name || baseUrl,
      baseUrl,
    },
    key: normalizeToken(token),
    group,
    balanceChargeRate: group?.ratio ?? null,
    raw: {
      token,
      group: groups[token.group] ?? null,
    },
  };
}

export async function fetchSitesKeyRates(sites, opts = {}) {
  const results = [];
  for (const site of sites) {
    results.push(await fetchSiteKeyRate(site, opts));
  }
  return results;
}
