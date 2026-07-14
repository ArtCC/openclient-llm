---
description: "Use when storing sensitive data, handling user input, managing credentials, working with the network layer, or reviewing code for security vulnerabilities."
applyTo: "**/*.swift"
---

# Security Guidelines

Based on OWASP Mobile Top 10 and Apple platform best practices.

---

## Sensitive data storage

### Never store sensitive data in UserDefaults or plain files

```swift
// ❌ UserDefaults — readable without entitlements on jailbroken devices
UserDefaults.standard.set(token, forKey: "auth_token")

// ❌ Plain file in Documents/
let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
try token.write(to: url.appendingPathComponent("token.txt"), atomically: true, encoding: .utf8)

// ✅ Keychain for credentials, tokens, private keys
try keychainManager.save(token, forKey: "auth_token")
```

### Keychain rules

- Use `kSecAttrAccessibleAfterFirstUnlock` for background-accessible items
- Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for items that must not leave the device
- Set `kSecAttrSynchronizable: false` unless iCloud sync is explicitly required
- Never log Keychain references or their contents

---

## No sensitive data in logs

```swift
// ❌ Logs API keys, tokens, PII
print("Token: \(authToken)")
print("User email: \(user.email)")

// ✅ Log categories, not values
print("Auth token loaded successfully")
print("User authenticated")
```

Rules:
- Never log: passwords, tokens, API keys, private keys, PII (name, email, phone, location)
- Log events and outcomes — not the data involved
- `LogManager` currently uses `print` behind `#if DEBUG`; all levels are no-ops in release builds. Do not describe this as `os_log` or rely on debug-level privacy redaction.
- `APIClient.request` currently prints successful generic JSON response bodies in full and prints up to 500 characters of HTTP error bodies in DEBUG builds. This is existing behavior, not endorsed guidance; do not add similar logging, and treat redaction/removal as unresolved hardening because model responses and server errors may contain sensitive content.

---

## Input validation

Validate all input at system boundaries (network responses, file imports, user input fields):

```swift
// ✅ Validate before using
guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
    throw ValidationError.emptyName
}
guard name.count <= 255 else {
    throw ValidationError.nameTooLong
}

// ✅ Decode with explicit types — never use Any or untyped JSON
struct APIResponse: Decodable {
    let id: UUID
    let name: String
    let createdAt: Date
}
let response = try JSONDecoder().decode(APIResponse.self, from: data)
```

- Never pass raw user input to system APIs (file paths, shell commands, URL construction)
- Sanitise strings displayed in UI that originate from external sources

---

## Network security

```swift
// Prefer HTTPS for internet-reachable servers.
// This app also supports user-selected self-hosted HTTP endpoints on localhost/LAN.

// ✅ Certificate pinning for high-sensitivity endpoints (if required)
// Implement via URLSession delegate — do not use third-party libraries unless vetted

// ✅ Validate server responses before using
guard (200..<300).contains(httpResponse.statusCode) else {
    throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
}
```

- The iOS and macOS targets currently set `NSAllowsArbitraryLoads = true` so users can reach self-hosted LiteLLM/OpenAI-compatible servers over HTTP on localhost, LANs, or private networks. This is a compatibility exception, not a statement that HTTP is secure.
- Prefer HTTPS and valid certificate verification whenever the server is internet-reachable. Do not broaden HTTP use to app-owned or fixed third-party services, and do not add trust-all certificate delegates.
- Do not remove or narrow the current ATS exception without a tested replacement that preserves user-configured self-hosted HTTP connectivity on every supported platform.
- Do not log raw HTTP responses that may contain sensitive data
- Set reasonable timeouts — never use `timeoutInterval: 0`

---

## Cryptography

```swift
// ✅ Use CryptoKit for all cryptographic operations
import CryptoKit

let key = SymmetricKey(size: .bits256)
let sealedBox = try AES.GCM.seal(data, using: key)

// ❌ Never roll your own crypto
// ❌ Never use MD5 or SHA-1 for security purposes (only for non-security checksums)
// ❌ Never hardcode encryption keys
```

- Use `CryptoKit` — never implement crypto primitives manually
- Generate keys using `SecKeyGeneratePair` or `SymmetricKey(size:)` — never derive from user input without a proper KDF
- Store keys in the Keychain or Secure Enclave — never in code or UserDefaults

---

## Authentication and authorisation

- Never store passwords in plain text — not even temporarily
- Use `LocalAuthentication` (`LAContext`) for biometric/Face ID gating
- Invalidate sessions on sign-out — remove all Keychain entries associated with the session
- Do not implement "remember me" by persisting passwords — persist tokens with appropriate Keychain accessibility

---

## Hardcoded secrets

```swift
// ❌ Hardcoded API key
let apiKey = "sk-1234567890abcdef"

// ✅ Load from a configuration source (environment, secure config, backend-provided token)
let apiKey = Configuration.apiKey  // Loaded from a non-committed source
```

- No API keys, secrets, or credentials in source code
- Add `*.xcconfig` files containing secrets to `.gitignore`
- Use environment variables or a secrets manager for CI/CD
- `Secrets.xcconfig` values used by Votice are expanded into the client bundle. They must be treated as recoverable client
  configuration even though the local file and CI values are protected from source control. Never use this mechanism for
  a privileged server-side secret.

---

## Data in transit between app and extension (if applicable)

- Use `Codable` with explicit types for `handleAppMessage` payloads
- Validate and bounds-check all values received from the extension before using them
- Do not pass raw strings that could be interpreted as code or paths

---

## Checklist (per PR / feature)

- [ ] No sensitive data in UserDefaults or plain files — use Keychain
- [ ] No secrets, API keys, or credentials in source code
- [ ] No PII or tokens in logs
- [ ] All user input validated at the boundary
- [ ] Network: HTTPS is preferred; the current ATS exception remains only to preserve user-configured self-hosted HTTP connectivity
- [ ] Debug diagnostics do not add request, response, server-error, conversation, or credential payload logging
- [ ] Cryptography uses `CryptoKit` — no custom implementations
- [ ] Biometric gating uses `LocalAuthentication`
- [ ] Sessions are fully invalidated on sign-out
- [ ] `Decodable` types are explicit — no `Any` in JSON parsing
