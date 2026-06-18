const DEFAULT_REFRESH_WINDOW_MS = 5 * 60 * 1000;

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
    Object.prototype.hasOwnProperty.call(body, 'code') &&
    Object.prototype.hasOwnProperty.call(body, 'data')
  ) {
    if (body.code !== 0) {
      throw new Error(`API error ${body.code}: ${body.message || 'unknown error'}`);
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

function isUnauthorized(error) {
  return error instanceof HttpError && error.status === 401;
}

function shouldRefresh(site, nowMs, refreshWindowMs) {
  const rawExpiresAt = readField(site, 'tokenExpiresAt', 'token_expires_at');
  const expiresAt = Number(rawExpiresAt);
  return !Number.isFinite(expiresAt) || expiresAt <= nowMs + refreshWindowMs;
}

async function refreshAuth(site, options) {
  const fetchImpl = getFetch(options.fetchImpl);
  const baseUrl = normalizeBaseUrl(site.baseUrl ?? site.base_url);
  const refreshToken = readField(site, 'refreshToken', 'refresh_token');
  if (!refreshToken) throw new Error(`${site.name || baseUrl}: refreshToken is required`);

  const data = await requestJson(fetchImpl, `${baseUrl}/api/v1/auth/refresh`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ refresh_token: refreshToken }),
  });

  if (!data?.access_token || !data?.refresh_token) {
    throw new Error(`${site.name || baseUrl}: refresh response missing token fields`);
  }

  const expiresInSeconds = Number(data.expires_in || 0);
  const tokenExpiresAt = options.now() + expiresInSeconds * 1000;

  return {
    authToken: data.access_token,
    refreshToken: data.refresh_token,
    tokenExpiresAt,
  };
}

function authHeaders(authToken) {
  return {
    Accept: 'application/json',
    Authorization: `Bearer ${authToken}`,
  };
}

function readTargetApiKey(site) {
  return site.apiKey ?? site.api_key ?? site.key ?? null;
}

function keyPrefix(apiKey) {
  if (!apiKey) return '';
  return `${String(apiKey).slice(0, 8)}...`;
}

async function listKeysPage(site, authToken, options, page) {
  const fetchImpl = getFetch(options.fetchImpl);
  const baseUrl = normalizeBaseUrl(site.baseUrl ?? site.base_url);
  const pageSize = Number(site.pageSize || site.page_size || 100);
  const keyName = readField(site, 'keyName', 'key_name');
  const apiKey = readTargetApiKey(site);

  const params = new URLSearchParams({
    page: String(page),
    page_size: String(pageSize),
  });

  if (!apiKey && keyName) {
    params.set('search', String(keyName));
  }

  const data = await requestJson(fetchImpl, `${baseUrl}/api/v1/keys?${params}`, {
    headers: authHeaders(authToken),
  });

  const items = Array.isArray(data) ? data : data?.items || [];
  const total = Array.isArray(data) ? items.length : Number(data?.total ?? items.length);
  return { items, total, pageSize };
}

async function listAvailableGroups(site, authToken, options) {
  const fetchImpl = getFetch(options.fetchImpl);
  const baseUrl = normalizeBaseUrl(site.baseUrl ?? site.base_url);
  const data = await requestJson(fetchImpl, `${baseUrl}/api/v1/groups/available`, {
    headers: authHeaders(authToken),
  });
  return Array.isArray(data) ? data : [];
}

async function listUserGroupRates(site, authToken, options) {
  const fetchImpl = getFetch(options.fetchImpl);
  const baseUrl = normalizeBaseUrl(site.baseUrl ?? site.base_url);
  const data = await requestJson(fetchImpl, `${baseUrl}/api/v1/groups/rates`, {
    headers: authHeaders(authToken),
  });
  return parseUserGroupRates(data);
}

function parseUserGroupRates(data) {
  const result = new Map();

  if (Array.isArray(data)) {
    for (const row of data) {
      const groupId = row?.group_id ?? row?.groupId ?? row?.id;
      const rate = row?.rate_multiplier ?? row?.rateMultiplier ?? row?.balance_charge_rate ?? row?.balanceChargeRate;
      const id = Number(groupId);
      const value = Number(rate);
      if (Number.isFinite(id) && Number.isFinite(value)) {
        result.set(id, value);
      }
    }
    return result;
  }

  if (data && typeof data === 'object') {
    for (const [key, rawValue] of Object.entries(data)) {
      if (rawValue == null) {
        continue;
      }

      const directId = Number(key);
      const directRate = Number(rawValue);
      if (Number.isFinite(directId) && Number.isFinite(directRate)) {
        result.set(directId, directRate);
        continue;
      }

      if (rawValue && typeof rawValue === 'object') {
        const groupId = rawValue.group_id ?? rawValue.groupId ?? rawValue.id ?? key;
        const rate =
          rawValue.rate_multiplier ??
          rawValue.rateMultiplier ??
          rawValue.balance_charge_rate ??
          rawValue.balanceChargeRate;
        const id = Number(groupId);
        const value = Number(rate);
        if (Number.isFinite(id) && Number.isFinite(value)) {
          result.set(id, value);
        }
      }
    }
  }

  return result;
}

function findKeyByName(keys, keyName) {
  const target = String(keyName).toLowerCase();
  return (
    keys.find((key) => String(key.name || '').toLowerCase() === target) ||
    keys.find((key) => String(key.name || '').toLowerCase().includes(target))
  );
}

function findKeyByApiKey(keys, apiKey) {
  return keys.find((key) => key.key === apiKey);
}

async function findConfiguredKey(site, authToken, options) {
  const baseUrl = normalizeBaseUrl(site.baseUrl ?? site.base_url);
  const apiKey = readTargetApiKey(site);
  const keyName = readField(site, 'keyName', 'key_name');
  const maxPages = Number(site.maxPages || site.max_pages || 20);

  if (!apiKey && !keyName) {
    throw new Error(`${site.name || baseUrl}: apiKey is required`);
  }

  for (let page = 1; page <= maxPages; page += 1) {
    const { items, total, pageSize } = await listKeysPage(site, authToken, options, page);
    const key = apiKey ? findKeyByApiKey(items, apiKey) : findKeyByName(items, keyName);
    if (key) return key;

    if (items.length < pageSize || page * pageSize >= total) {
      break;
    }
  }

  if (apiKey) {
    throw new Error(`${site.name || baseUrl}: apiKey ${keyPrefix(apiKey)} not found`);
  }

  throw new Error(`${site.name || baseUrl}: key named "${keyName}" not found`);
}

function normalizeGroup(group) {
  if (!group) return null;
  return {
    id: group.id ?? null,
    name: group.name ?? '',
    platform: group.platform ?? '',
    balanceChargeRate: group.balance_charge_rate ?? group.balanceChargeRate ?? group.rate_multiplier ?? group.rateMultiplier ?? null,
    subscriptionChargeRate: group.subscription_charge_rate ?? null,
    rateMultiplier: group.rate_multiplier ?? null,
    imageRateMultiplier: group.image_rate_multiplier ?? null,
    raw: group,
  };
}

function normalizeKey(key) {
  return {
    id: key.id ?? null,
    keyPrefix: key.key ? keyPrefix(key.key) : '',
    name: key.name ?? '',
    groupId: key.group_id ?? null,
    status: key.status ?? '',
  };
}

async function resolveGroup(site, key, authToken, options) {
  if (key.group?.balance_charge_rate !== undefined) {
    return normalizeGroup(key.group);
  }

  if (key.group_id == null) {
    return normalizeGroup(key.group || null);
  }

  const groups = await listAvailableGroups(site, authToken, options);
  const group = groups.find((item) => Number(item.id) === Number(key.group_id)) || key.group || null;
  return normalizeGroup(group);
}

function applyUserGroupRate(group, userGroupRates) {
  if (!group || group.id == null) return group;
  const rate = userGroupRates.get(Number(group.id));
  if (!Number.isFinite(rate)) return group;
  return {
    ...group,
    balanceChargeRate: rate,
    raw: {
      ...group.raw,
      user_rate_multiplier: rate,
    },
  };
}

export async function fetchSiteKeyRate(site, opts = {}) {
  const options = {
    fetchImpl: opts.fetchImpl,
    now: opts.now || Date.now,
    refreshWindowMs: opts.refreshWindowMs ?? DEFAULT_REFRESH_WINDOW_MS,
  };
  const baseUrl = normalizeBaseUrl(site.baseUrl ?? site.base_url);
  let auth = {
    authToken: readField(site, 'authToken', 'auth_token'),
    refreshToken: readField(site, 'refreshToken', 'refresh_token'),
    tokenExpiresAt: Number(readField(site, 'tokenExpiresAt', 'token_expires_at')),
  };
  let refreshed = false;

  if (!auth.authToken || shouldRefresh(site, options.now(), options.refreshWindowMs)) {
    auth = await refreshAuth(site, options);
    refreshed = true;
  }

  let key;
  let group;
  async function readKeyAndGroup() {
    key = await findConfiguredKey({ ...site, baseUrl }, auth.authToken, options);
    group = await resolveGroup({ ...site, baseUrl }, key, auth.authToken, options);
    let userGroupRates = new Map();
    try {
      userGroupRates = await listUserGroupRates({ ...site, baseUrl }, auth.authToken, options);
    } catch (error) {
      if (isUnauthorized(error)) throw error;
    }
    group = applyUserGroupRate(group, userGroupRates);
  }

  try {
    await readKeyAndGroup();
  } catch (error) {
    if (!isUnauthorized(error) || refreshed) {
      throw error;
    }
    auth = await refreshAuth({ ...site, baseUrl }, options);
    refreshed = true;
    await readKeyAndGroup();
  }

  return {
    site: {
      name: site.name || baseUrl,
      baseUrl,
    },
    key: normalizeKey(key),
    group,
    balanceChargeRate: group?.balanceChargeRate ?? null,
    subscriptionChargeRate: group?.subscriptionChargeRate ?? null,
    refreshed,
    auth,
  };
}

export async function fetchSitesKeyRates(sites, opts = {}) {
  const results = [];

  for (const site of sites) {
    try {
      results.push({
        ok: true,
        value: await fetchSiteKeyRate(site, opts),
      });
    } catch (error) {
      results.push({
        ok: false,
        site: {
          name: site.name || site.baseUrl || site.base_url || '',
          baseUrl: site.baseUrl || site.base_url || '',
        },
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  return results;
}
