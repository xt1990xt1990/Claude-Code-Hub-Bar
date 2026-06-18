import test from 'node:test';
import assert from 'node:assert/strict';

import { fetchSiteKeyRate } from './core.mjs';

function jsonResponse(body, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    async text() {
      return JSON.stringify(body);
    },
  };
}

test('refreshes an expired token and reads balance_charge_rate from key group', async () => {
  const requests = [];
  const fetchImpl = async (url, options = {}) => {
    requests.push({ url: String(url), options });

    if (String(url).endsWith('/api/v1/auth/refresh')) {
      return jsonResponse({
        code: 0,
        data: {
          access_token: 'new-access',
          refresh_token: 'new-refresh',
          expires_in: 86400,
        },
      });
    }

    if (String(url).includes('/api/v1/keys')) {
      assert.equal(new URL(String(url)).searchParams.has('search'), false);
      assert.equal(options.headers.Authorization, 'Bearer new-access');
      return jsonResponse({
        code: 0,
        data: {
          items: [
            {
              id: 10,
              key: 'sk-plus',
              name: 'plus',
              group_id: 76,
              group: {
                id: 76,
                name: 'codex-pro',
                platform: 'openai',
                balance_charge_rate: 1.3,
                subscription_charge_rate: 4.5,
              },
            },
          ],
          total: 1,
        },
      });
    }

    if (String(url).endsWith('/api/v1/groups/rates')) {
      assert.equal(options.headers.Authorization, 'Bearer new-access');
      return jsonResponse({
        code: 0,
        data: {},
      });
    }

    throw new Error(`Unexpected request ${url}`);
  };

  const result = await fetchSiteKeyRate(
    {
      name: 'lucen',
      baseUrl: 'https://lucen.cc/',
      authToken: 'old-access',
      refreshToken: 'old-refresh',
      tokenExpiresAt: 1,
      apiKey: 'sk-plus',
    },
    { fetchImpl, now: () => 1_000_000 },
  );

  assert.equal(result.refreshed, true);
  assert.equal(result.auth.authToken, 'new-access');
  assert.equal(result.auth.refreshToken, 'new-refresh');
  assert.equal(result.key.name, 'plus');
  assert.equal(result.group.id, 76);
  assert.equal(result.group.balanceChargeRate, 1.3);
  assert.equal(result.group.subscriptionChargeRate, 4.5);
  assert.equal(requests.length, 3);
});

test('uses groups/available when the key payload does not include group details', async () => {
  const fetchImpl = async (url, options = {}) => {
    if (String(url).includes('/api/v1/keys')) {
      assert.equal(new URL(String(url)).searchParams.has('search'), false);
      assert.equal(options.headers.Authorization, 'Bearer valid-access');
      return jsonResponse({
        code: 0,
        data: {
          items: [{ id: 11, key: 'sk-target', name: 'plus', group_id: 88 }],
          total: 1,
        },
      });
    }

    if (String(url).endsWith('/api/v1/groups/available')) {
      return jsonResponse({
        code: 0,
        data: [
          {
            id: 88,
            name: 'claude-plus',
            platform: 'anthropic',
            balance_charge_rate: 2.2,
            subscription_charge_rate: 3.3,
          },
        ],
      });
    }

    throw new Error(`Unexpected request ${url}`);
  };

  const result = await fetchSiteKeyRate(
    {
      name: 'site-a',
      baseUrl: 'https://site-a.example',
      authToken: 'valid-access',
      refreshToken: 'refresh',
      tokenExpiresAt: 9_999_999_999_999,
      apiKey: 'sk-target',
    },
    { fetchImpl, now: () => 1_000_000 },
  );

  assert.equal(result.refreshed, false);
  assert.equal(result.group.id, 88);
  assert.equal(result.group.balanceChargeRate, 2.2);
});

test('uses groups/rates user override before default group rate', async () => {
  const fetchImpl = async (url, options = {}) => {
    if (String(url).includes('/api/v1/keys')) {
      assert.equal(new URL(String(url)).searchParams.has('search'), false);
      assert.equal(options.headers.Authorization, 'Bearer valid-access');
      return jsonResponse({
        code: 0,
        data: {
          items: [{ id: 11, key: 'sk-target', name: 'plus', group_id: 88 }],
          total: 1,
        },
      });
    }

    if (String(url).endsWith('/api/v1/groups/available')) {
      return jsonResponse({
        code: 0,
        data: [
          {
            id: 88,
            name: 'discounted',
            rate_multiplier: 0.1,
          },
        ],
      });
    }

    if (String(url).endsWith('/api/v1/groups/rates')) {
      return jsonResponse({
        code: 0,
        data: {
          88: 0.05,
        },
      });
    }

    throw new Error(`Unexpected request ${url}`);
  };

  const result = await fetchSiteKeyRate(
    {
      name: 'site-a',
      baseUrl: 'https://site-a.example',
      authToken: 'valid-access',
      refreshToken: 'refresh',
      tokenExpiresAt: 9_999_999_999_999,
      apiKey: 'sk-target',
    },
    { fetchImpl, now: () => 1_000_000 },
  );

  assert.equal(result.group.id, 88);
  assert.equal(result.group.balanceChargeRate, 0.05);
  assert.equal(result.balanceChargeRate, 0.05);
});

test('keeps default group rate when groups/rates returns null for that group', async () => {
  const fetchImpl = async (url, options = {}) => {
    if (String(url).includes('/api/v1/keys')) {
      assert.equal(new URL(String(url)).searchParams.has('search'), false);
      assert.equal(options.headers.Authorization, 'Bearer valid-access');
      return jsonResponse({
        code: 0,
        data: {
          items: [{ id: 11, key: 'sk-target', name: 'plus', group_id: 88 }],
          total: 1,
        },
      });
    }

    if (String(url).endsWith('/api/v1/groups/available')) {
      return jsonResponse({
        code: 0,
        data: [{ id: 88, name: 'defaulted', rate_multiplier: 0.1 }],
      });
    }

    if (String(url).endsWith('/api/v1/groups/rates')) {
      return jsonResponse({
        code: 0,
        data: {
          88: null,
        },
      });
    }

    throw new Error(`Unexpected request ${url}`);
  };

  const result = await fetchSiteKeyRate(
    {
      name: 'site-a',
      baseUrl: 'https://site-a.example',
      authToken: 'valid-access',
      refreshToken: 'refresh',
      tokenExpiresAt: 9_999_999_999_999,
      apiKey: 'sk-target',
    },
    { fetchImpl, now: () => 1_000_000 },
  );

  assert.equal(result.balanceChargeRate, 0.1);
});

test('refreshes and retries once when the keys request returns 401', async () => {
  let keysCalls = 0;
  const fetchImpl = async (url, options = {}) => {
    if (String(url).includes('/api/v1/keys')) {
      keysCalls += 1;
      if (keysCalls === 1) {
        assert.equal(new URL(String(url)).searchParams.has('search'), false);
        assert.equal(options.headers.Authorization, 'Bearer stale-access');
        return jsonResponse({ code: 'INVALID_TOKEN', message: 'invalid token' }, 401);
      }

      assert.equal(new URL(String(url)).searchParams.has('search'), false);
      assert.equal(options.headers.Authorization, 'Bearer retry-access');
      return jsonResponse({
        code: 0,
        data: {
          items: [
            {
              id: 12,
              key: 'sk-stale',
              name: 'plus',
              group_id: 99,
              group: {
                id: 99,
                name: 'retry-group',
                balance_charge_rate: 1.8,
              },
            },
          ],
          total: 1,
        },
      });
    }

    if (String(url).endsWith('/api/v1/auth/refresh')) {
      return jsonResponse({
        code: 0,
        data: {
          access_token: 'retry-access',
          refresh_token: 'retry-refresh',
          expires_in: 86400,
        },
      });
    }

    throw new Error(`Unexpected request ${url}`);
  };

  const result = await fetchSiteKeyRate(
    {
      name: 'site-b',
      baseUrl: 'https://site-b.example',
      authToken: 'stale-access',
      refreshToken: 'refresh',
      tokenExpiresAt: 9_999_999_999_999,
      apiKey: 'sk-stale',
    },
    { fetchImpl, now: () => 1_000_000 },
  );

  assert.equal(result.refreshed, true);
  assert.equal(keysCalls, 2);
  assert.equal(result.auth.authToken, 'retry-access');
  assert.equal(result.balanceChargeRate, 1.8);
});
