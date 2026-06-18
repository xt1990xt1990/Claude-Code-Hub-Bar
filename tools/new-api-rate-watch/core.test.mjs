import test from 'node:test';
import assert from 'node:assert/strict';

import { fetchSiteKeyRate, fetchSitesKeyRates } from './core.mjs';

function jsonResponse(body, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    async text() {
      return JSON.stringify(body);
    },
  };
}

test('searches a new-api token by apiKey and maps group ratio to balanceChargeRate', async () => {
  const requests = [];
  const fetchImpl = async (url, options = {}) => {
    requests.push({ url: String(url), options });

    if (String(url).includes('/api/token/search')) {
      const parsed = new URL(String(url));
      assert.equal(parsed.searchParams.get('token'), 'abc123');
      assert.equal(options.headers.Authorization, 'Bearer access-token');
      assert.equal(options.headers['New-Api-User'], '5081');
      return jsonResponse({
        success: true,
        data: {
          items: [
            {
              id: 13455,
              name: 'plus',
              key: 'abc123',
              group: 'Claude Max-2',
              status: 1,
            },
          ],
          total: 1,
        },
      });
    }

    if (String(url).endsWith('/api/user/self/groups')) {
      assert.equal(options.headers.Authorization, 'Bearer access-token');
      assert.equal(options.headers['New-Api-User'], '5081');
      return jsonResponse({
        success: true,
        data: {
          'Claude Max-2': {
            ratio: 0.75,
            desc: 'Claude Max-2 test',
          },
        },
      });
    }

    throw new Error(`Unexpected request ${url}`);
  };

  const result = await fetchSiteKeyRate(
    {
      name: 'zzshu',
      baseUrl: 'https://zzshu.cc/',
      userId: 5081,
      accessToken: 'access-token',
      apiKey: 'sk-abc123',
    },
    { fetchImpl },
  );

  assert.equal(result.provider, 'new-api');
  assert.equal(result.site.name, 'zzshu');
  assert.equal(result.key.id, 13455);
  assert.equal(result.key.name, 'plus');
  assert.equal(result.key.keyPrefix, 'abc123...c123');
  assert.equal(result.group.name, 'Claude Max-2');
  assert.equal(result.group.ratio, 0.75);
  assert.equal(result.balanceChargeRate, 0.75);
  assert.equal(requests.length, 2);
});

test('sends cookie header for cookie-session new-api frontends', async () => {
  const fetchImpl = async (url, options = {}) => {
    assert.equal(options.headers.Cookie, 'session=abc');
    assert.equal(options.headers['New-Api-User'], '7234');

    if (String(url).includes('/api/token/search')) {
      return jsonResponse({
        success: true,
        data: {
          items: [
            {
              id: 9,
              key: 'sk-cookie',
              name: 'cookie',
              group: 'cookie-group',
            },
          ],
          total: 1,
        },
      });
    }

    if (String(url).endsWith('/api/user/self/groups')) {
      return jsonResponse({
        success: true,
        data: {
          'cookie-group': { ratio: 0.42, desc: 'Cookie Group' },
        },
      });
    }

    throw new Error(`Unexpected request ${url}`);
  };

  const result = await fetchSiteKeyRate(
    {
      baseUrl: 'https://new-api.example',
      userId: '7234',
      cookieHeader: 'session=abc',
      apiKey: 'sk-cookie',
    },
    { fetchImpl },
  );

  assert.equal(result.balanceChargeRate, 0.42);
});

test('reveals a masked matching token key before exact apiKey comparison', async () => {
  const fetchImpl = async (url, options = {}) => {
    if (String(url).includes('/api/token/search')) {
      return jsonResponse({
        success: true,
        data: {
          items: [
            {
              id: 10,
              name: 'masked',
              key: 'demo****...TAIL',
              group: 'vip',
              status: 1,
            },
          ],
          total: 1,
        },
      });
    }

    if (String(url).endsWith('/api/token/10/key')) {
      assert.equal(options.method, 'POST');
      return jsonResponse({
        success: true,
        data: {
          key: 'demoTestTokenForMask0000TAIL',
        },
      });
    }

    if (String(url).endsWith('/api/user/self/groups')) {
      return jsonResponse({
        success: true,
        data: {
          vip: { ratio: '1.25', desc: 'VIP' },
        },
      });
    }

    throw new Error(`Unexpected request ${url}`);
  };

  const result = await fetchSiteKeyRate(
    {
      name: 'masked-site',
      baseUrl: 'https://new-api.example',
      userId: '7',
      accessToken: 'token',
      apiKey: 'demoTestTokenForMask0000TAIL',
    },
    { fetchImpl },
  );

  assert.equal(result.key.keyPrefix, 'demoTest...TAIL');
  assert.equal(result.group.ratio, 1.25);
  assert.equal(result.balanceChargeRate, 1.25);
});

test('matches a new-api token by apiKey suffix when only the tail is available', async () => {
  const searchTokens = [];
  const fetchImpl = async (url, options = {}) => {
    if (String(url).includes('/api/token/search')) {
      const parsed = new URL(String(url));
      searchTokens.push(parsed.searchParams.get('token'));
      if (parsed.searchParams.get('token') === '%TAIL') {
        return jsonResponse({
          success: true,
          data: {
            items: [
              {
                id: 42,
                name: 'codex-plus',
                key: 'demo**********TAIL',
                group: 'codex-plus',
              },
            ],
            total: 1,
          },
        });
      }
      return jsonResponse({
        success: true,
        data: {
          items: [],
          total: 0,
        },
      });
    }

    if (String(url).endsWith('/api/token/42/key')) {
      assert.equal(options.method, 'POST');
      return jsonResponse({
        success: true,
        data: {
          key: 'demoTestTokenForMask0000TAIL',
        },
      });
    }

    if (String(url).endsWith('/api/user/self/groups')) {
      return jsonResponse({
        success: true,
        data: {
          'codex-plus': { ratio: 0.75, desc: 'Codex Plus' },
        },
      });
    }

    throw new Error(`Unexpected request ${url}`);
  };

  const result = await fetchSiteKeyRate(
    {
      name: 'codexapis',
      baseUrl: 'https://codexapis.com',
      userId: '7234',
      cookieHeader: 'session=abc',
      apiKey: 'TAIL',
    },
    { fetchImpl },
  );

  assert.equal(result.key.id, 42);
  assert.equal(result.balanceChargeRate, 0.75);
  assert.deepEqual(searchTokens, ['%TAIL']);
});

test('falls back to keyName when apiKey is not provided', async () => {
  const fetchImpl = async (url) => {
    if (String(url).includes('/api/token/search')) {
      const parsed = new URL(String(url));
      assert.equal(parsed.searchParams.get('keyword'), 'backup');
      assert.equal(parsed.searchParams.has('token'), false);
      return jsonResponse({
        success: true,
        data: {
          items: [{ id: 11, name: 'backup-key', key: 'sk-backup', group: 'default' }],
          total: 1,
        },
      });
    }

    if (String(url).endsWith('/api/user/self/groups')) {
      return jsonResponse({
        success: true,
        data: {
          default: { ratio: 1 },
        },
      });
    }

    throw new Error(`Unexpected request ${url}`);
  };

  const result = await fetchSiteKeyRate(
    {
      name: 'name-site',
      baseUrl: 'https://name.example',
      userId: '12',
      accessToken: 'token',
      keyName: 'backup',
    },
    { fetchImpl },
  );

  assert.equal(result.key.name, 'backup-key');
  assert.equal(result.balanceChargeRate, 1);
});

test('fetches multiple new-api sites sequentially', async () => {
  const order = [];
  const fetchImpl = async (url) => {
    const host = new URL(String(url)).host;
    order.push(host);

    if (String(url).includes('/api/token/search')) {
      return jsonResponse({
        success: true,
        data: {
          items: [{ id: host === 'one.example' ? 1 : 2, name: host, key: host, group: host }],
          total: 1,
        },
      });
    }

    if (String(url).endsWith('/api/user/self/groups')) {
      return jsonResponse({
        success: true,
        data: {
          [host]: { ratio: host === 'one.example' ? 0.5 : 0.8 },
        },
      });
    }

    throw new Error(`Unexpected request ${url}`);
  };

  const results = await fetchSitesKeyRates(
    [
      { baseUrl: 'https://one.example', userId: '1', accessToken: 'a', apiKey: 'sk-one.example' },
      { baseUrl: 'https://two.example', userId: '2', accessToken: 'b', apiKey: 'sk-two.example' },
    ],
    { fetchImpl },
  );

  assert.deepEqual(results.map((item) => item.balanceChargeRate), [0.5, 0.8]);
  assert.deepEqual(order, ['one.example', 'one.example', 'two.example', 'two.example']);
});
