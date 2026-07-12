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
- In debug builds, prefer `os_log` with `.debug` level (stripped in release by default)

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
// ✅ Always use HTTPS — never allow HTTP in production
// Info.plist: NSAppTransportSecurity must not have NSAllowsArbitraryLoads = true

// ✅ Certificate pinning for high-sensitivity endpoints (if required)
// Implement via URLSession delegate — do not use third-party libraries unless vetted

// ✅ Validate server responses before using
guard (200..<300).contains(httpResponse.statusCode) else {
    throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
}
```

- **`NSAllowsArbitraryLoads = true` is intentional in this project.** LiteLLM runs as a self-hosted server on user-controlled infrastructure (localhost, LAN, private network) and may serve over plain HTTP. Disabling ATS globally is the accepted trade-off; do not remove this setting.
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
- [ ] Network: `NSAllowsArbitraryLoads = true` is kept (required for self-hosted LiteLLM over HTTP/LAN) — do not restrict user-entered server URLs
- [ ] Cryptography uses `CryptoKit` — no custom implementations
- [ ] Biometric gating uses `LocalAuthentication`
- [ ] Sessions are fully invalidated on sign-out
- [ ] `Decodable` types are explicit — no `Any` in JSON parsing