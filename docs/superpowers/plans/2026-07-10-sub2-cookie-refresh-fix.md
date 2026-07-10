# Sub2API Cookie Refresh Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Cookie-only Sub2API login state refresh reliably across 24-hour access-token expiry, including refresh-cookie rotation, then install and restart the latest client.

**Architecture:** Treat a non-empty `sub2api_refresh_token` Cookie as the authoritative refresh credential and match the browser protocol by sending an empty JSON body. Return HTTP response metadata from the existing JSON request helper so rotated `Set-Cookie` values can be parsed with Foundation, merged into the stored Cookie header, and persisted through the existing credential store.

**Tech Stack:** Swift, Foundation `URLSession`/`HTTPCookie`, standalone Swift regression tests, Xcode macOS Release build.

---

## File Map

- Modify `CCHBar/UpstreamRateService.swift`: select Cookie-only refresh requests, expose response metadata internally, merge rotated response Cookies into returned credentials.
- Modify `CCHBar/UpstreamRateBrowserAuth.swift`: import the Cookie token over stale keychain state, validate near-expiry credentials, persist a rotated Cookie returned during browser-login validation, and clear a stale refresh Cookie before re-login.
- Modify `tools/upstream-rate-cloudflare-challenge.test.swift`: integration coverage for Cookie-authoritative requests, body-token compatibility, and Cookie rotation.
- Modify `tools/upstream-rate-sub2-cloudflare-cookie.test.swift`: browser-import regression coverage for overwriting stale refresh state.

### Task 1: Make the refresh Cookie authoritative

**Files:**
- Modify: `tools/upstream-rate-cloudflare-challenge.test.swift`
- Modify: `CCHBar/UpstreamRateService.swift:250-281`

- [ ] **Step 1: Change the Cookie-only test to reproduce stale-field conflict**

Use a credential whose keychain field is stale while its browser Cookie is fresh:

```swift
credential.sub2CookieHeader = "sub2api_refresh_token=browser"
credential.sub2RefreshToken = "stale-keychain-token"
```

Keep the assertion that `/api/v1/auth/refresh` receives body `{}`.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcrun swiftc CCHBar/UpstreamRateModels.swift CCHBar/UpstreamRateCredentials.swift CCHBar/UpstreamRateService.swift CCHBar/UpstreamRateBrowserAuth.swift tools/upstream-rate-cloudflare-challenge.test.swift -o /tmp/upstream-rate-cloudflare-challenge.test
/tmp/upstream-rate-cloudflare-challenge.test
```

Expected: FAIL with `cookie-only refresh should send an empty JSON body`, because the current conditional sends the stale keychain token in the body.

- [ ] **Step 3: Use an empty body whenever the dedicated Cookie exists**

In both service refresh and browser-login validation, select the request body only from Cookie presence:

```swift
let body: [String: Any] = hasCookieRefreshToken
    ? [:]
    : ["refresh_token": refreshToken]
```

- [ ] **Step 4: Add body-only compatibility coverage**

Add a test credential with no Cookie and `sub2RefreshToken = "body-refresh"`. Record the refresh request and assert:

```swift
expectTrue(refresh?.cookie == nil, "body-token refresh should not require a Cookie")
expectTrue(
    refresh?.body.contains(#""refresh_token":"body-refresh""#) == true,
    "body-token refresh should preserve the existing request contract"
)
```

- [ ] **Step 5: Run the focused test and verify GREEN**

Run the command from Step 2. Expected: exit 0 with no `FAIL` output.

### Task 2: Persist rotated refresh Cookies

**Files:**
- Modify: `tools/upstream-rate-cloudflare-challenge.test.swift`
- Modify: `CCHBar/UpstreamRateService.swift:535-592`
- Modify: `CCHBar/UpstreamRateService.swift:665-681`
- Modify: `CCHBar/UpstreamRateBrowserAuth.swift:718-746`

- [ ] **Step 1: Add a failing Cookie-rotation assertion**

Make the test protocol return a rotated Cookie and omit a response-body refresh token:

```swift
headerFields: [
    "Content-Type": "application/json",
    "Set-Cookie": "sub2api_refresh_token=rotated; Path=/; HttpOnly; Secure; SameSite=Lax"
]
```

Use this refresh response:

```swift
#"{"code":0,"data":{"access_token":"access-from-cookie","expires_in":3600}}"#
```

Assert the returned credential contains `sub2api_refresh_token=rotated`, no longer contains `sub2api_refresh_token=browser`, preserves unrelated Cookies, and has `sub2RefreshToken == "rotated"`.

- [ ] **Step 2: Run the focused test and verify RED**

Run the Task 1 test command. Expected: FAIL because the returned credential still contains the original Cookie.

- [ ] **Step 3: Return HTTP metadata from the JSON helper**

Introduce a private result and make the existing helper delegate to it:

```swift
private struct JSONResponse {
    let value: Any
    let response: HTTPURLResponse
}

private func requestJSON(
    baseURL: String,
    path: String,
    queryItems: [URLQueryItem] = [],
    method: String = "GET",
    headers: [String: String] = [:],
    body: [String: Any]? = nil,
    unwrap: ResponseEnvelope
) async throws -> Any {
    let result = try await requestJSONResponse(
        baseURL: baseURL,
        path: path,
        queryItems: queryItems,
        method: method,
        headers: headers,
        body: body,
        unwrap: unwrap
    )
    return result.value
}

private func requestJSONResponse(
    baseURL: String,
    path: String,
    queryItems: [URLQueryItem] = [],
    method: String = "GET",
    headers: [String: String] = [:],
    body: [String: Any]? = nil,
    unwrap: ResponseEnvelope
) async throws -> JSONResponse {
    let base = baseURL
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    guard var components = URLComponents(string: base + path) else {
        throw UpstreamRateServiceError.invalidURL
    }
    if !queryItems.isEmpty {
        components.queryItems = queryItems
    }
    guard let url = components.url else {
        throw UpstreamRateServiceError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
    }
    if let body {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw UpstreamRateServiceError.invalidResponse("上游响应无效")
    }
    guard (200...299).contains(http.statusCode) else {
        throw UpstreamRateServiceError.http(
            http.statusCode,
            headers: upstreamRateHTTPHeaders(http)
        )
    }
    let rawValue = data.isEmpty ? NSNull() : try JSONSerialization.jsonObject(with: data)
    return JSONResponse(
        value: try unwrapEnvelope(rawValue, unwrap: unwrap),
        response: http
    )
}
```

Keep every existing `requestJSON` call source-compatible; only `refreshSub2Token` needs `requestJSONResponse`.

- [ ] **Step 4: Add a structured response-Cookie merge helper**

Add a file-level helper that uses Foundation parsing:

```swift
func upstreamRateMergingResponseCookies(
    _ cookieHeader: String,
    response: HTTPURLResponse
) -> String {
    guard let url = response.url, let host = url.host?.lowercased() else {
        return cookieHeader
    }
    let headerFields = response.allHeaderFields.reduce(into: [String: String]()) { result, entry in
        guard let key = entry.key as? String else { return }
        result[key] = "\(entry.value)"
    }
    let responseCookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        .filter { cookie in
            let domain = cookie.domain
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .lowercased()
            return domain.isEmpty || domain == host || host.hasSuffix(".\(domain)")
        }
    guard !responseCookies.isEmpty else { return cookieHeader }

    var names: [String] = []
    var values: [String: String] = [:]
    for part in cookieHeader.split(separator: ";") {
        let pieces = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard let rawName = pieces.first, pieces.count == 2 else { continue }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { continue }
        if values[name] == nil { names.append(name) }
        values[name] = pieces[1].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    for cookie in responseCookies {
        if cookie.expiresDate.map({ $0 <= Date() }) == true {
            values.removeValue(forKey: cookie.name)
            names.removeAll { $0 == cookie.name }
        } else {
            if values[cookie.name] == nil { names.append(cookie.name) }
            values[cookie.name] = cookie.value
        }
    }
    return names.compactMap { name in
        values[name].map { "\(name)=\($0)" }
    }.joined(separator: "; ")
}
```

- [ ] **Step 5: Update the service credential after refresh**

After decoding access-token fields:

```swift
let mergedCookieHeader = upstreamRateMergingResponseCookies(
    credential.sub2CookieHeader,
    response: result.response
)
next.sub2CookieHeader = mergedCookieHeader

let responseCookieRefreshToken = upstreamRateSub2RefreshTokenCookieValue(mergedCookieHeader)
if !responseCookieRefreshToken.isEmpty {
    next.sub2RefreshToken = responseCookieRefreshToken
} else if !nextRefreshToken.isEmpty {
    next.sub2RefreshToken = nextRefreshToken
}
```

- [ ] **Step 6: Apply the same merge during browser-login validation**

When validation succeeds, merge `http` response Cookies into `next.sub2CookieHeader`. Prefer the resulting Cookie token over a response-body token before returning `next`.

- [ ] **Step 7: Run both focused suites and verify GREEN**

Run:

```bash
xcrun swiftc CCHBar/UpstreamRateModels.swift CCHBar/UpstreamRateCredentials.swift CCHBar/UpstreamRateService.swift CCHBar/UpstreamRateBrowserAuth.swift tools/upstream-rate-cloudflare-challenge.test.swift -o /tmp/upstream-rate-cloudflare-challenge.test
/tmp/upstream-rate-cloudflare-challenge.test
xcrun swiftc CCHBar/UpstreamRateModels.swift CCHBar/UpstreamRateCredentials.swift CCHBar/UpstreamRateService.swift CCHBar/UpstreamRateBrowserAuth.swift tools/upstream-rate-sub2-cloudflare-cookie.test.swift -o /tmp/upstream-rate-sub2-cloudflare-cookie.test
/tmp/upstream-rate-sub2-cloudflare-cookie.test
```

Expected: both executables exit 0 with no output.

### Task 3: Verify browser import overwrites stale state

**Files:**
- Modify: `tools/upstream-rate-sub2-cloudflare-cookie.test.swift`
- Modify: `CCHBar/UpstreamRateBrowserAuth.swift:267-299`
- Modify: `CCHBar/UpstreamRateBrowserAuth.swift:396-429`
- Modify: `CCHBar/UpstreamRateBrowserAuth.swift:687-755`

- [ ] **Step 1: Strengthen the import regression test**

Initialize the input credential with:

```swift
var credential = UpstreamRateCredential.empty(host: "ageteam.online", sourceType: .sub2API)
credential.sub2RefreshToken = "stale-keychain-token"
```

After importing `sub2api_refresh_token=browser`, assert `next.sub2RefreshToken == "browser"`.

- [ ] **Step 2: Run the browser-import suite**

Run the second command block from Task 2 Step 7. Expected: exit 0; the current worktree import merge already supplies the minimal behavior.

- [ ] **Step 3: Review the login capture path**

Confirm the production path has all three behaviors and no host-specific checks:

```swift
await clearStaleBrowserCredential(for: credential)
```

```swift
next.sub2RefreshToken = cookieRefreshToken
```

```swift
let shouldRefresh = next.sub2AuthToken.isEmpty
    || (next.sub2TokenExpiresAt?.timeIntervalSinceNow ?? 0) <= 5 * 60
```

- [ ] **Step 4: Run `git diff --check`**

Expected: exit 0 with no whitespace errors.

### Task 4: Full verification, install, and restart

**Files:**
- Verify: the focused auth tests, stale-snapshot regression test, and Node rate-watch tests
- Build: `CCHBar.xcodeproj`
- Install: `/Applications/Claude Code Hub Bar.app`

- [ ] **Step 1: Run the stale-snapshot regression test**

Run:

```bash
xcrun swiftc CCHBar/UpstreamRateModels.swift tools/upstream-rate-stale-snapshot.test.swift -o /tmp/upstream-rate-stale-snapshot.test
/tmp/upstream-rate-stale-snapshot.test
```

Expected: exit 0 with no output. The two focused auth suites were already run in Task 2 Step 7.

- [ ] **Step 2: Run Node tests**

Run:

```bash
node --test tools/new-api-rate-watch/core.test.mjs tools/sub2-rate-watch/core.test.mjs
```

Expected: all tests pass, zero failures.

- [ ] **Step 3: Build the Release app**

Run:

```bash
xcodebuild -project CCHBar.xcodeproj -scheme CCHBar -configuration Release -destination 'platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **` and a fresh app at `~/Library/Developer/Xcode/DerivedData/CCHBar-*/Build/Products/Release/Claude Code Hub Bar.app`.

- [ ] **Step 4: Install the fresh build**

Resolve `TARGET_BUILD_DIR` with `xcodebuild -showBuildSettings -configuration Release`. Quit the currently running app by bundle identifier, replace only `/Applications/Claude Code Hub Bar.app` with the fresh Release bundle, and verify:

```bash
codesign --verify --deep --strict '/Applications/Claude Code Hub Bar.app'
defaults read '/Applications/Claude Code Hub Bar.app/Contents/Info' CFBundleShortVersionString
```

Expected: code-sign verification exits 0 and the installed version is `1.2.6`.

- [ ] **Step 5: Restart and verify the running executable**

Launch:

```bash
open -na '/Applications/Claude Code Hub Bar.app'
```

Verify the process command points to `/Applications/Claude Code Hub Bar.app/Contents/MacOS/Claude Code Hub Bar`, remains alive for at least five seconds, and only one app process is running.

- [ ] **Step 6: Commit the implementation**

Stage only the four scoped code/test files and this plan:

```bash
git add CCHBar/UpstreamRateBrowserAuth.swift CCHBar/UpstreamRateService.swift tools/upstream-rate-cloudflare-challenge.test.swift tools/upstream-rate-sub2-cloudflare-cookie.test.swift docs/superpowers/plans/2026-07-10-sub2-cookie-refresh-fix.md
git commit -m "Fix Sub2API cookie login refresh"
```
