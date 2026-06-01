# Token Management

HubLaunch authenticates with GitHub using OAuth-style tokens. This page explains what gets stored, when you need to re-login, and how the refresh flow works.

## Token Types

### GitHub App Tokens (Current, Recommended)

**Client ID format**: `Iv...`

- ✅ **Do not expire** by default
- ✅ Better rate limits (5,000 req/hour per installation)
- ✅ Simpler authentication flow
- ❌ No refresh tokens provided
- ⚠️ User can revoke access at any time

### GitHub OAuth App Tokens (Alternative)

**Client ID format**: `Ov...`

- ✅ Supports refresh tokens for auto-renewal
- ✅ Configurable expiry
- ❌ More complex setup
- ❌ Lower rate limits (5,000 req/hour total, across all users)

## Token Storage

HubLaunch stores tokens in `~/.hublaunch/github-token` as JSON with metadata:

```json
{
  "access_token": "gho_xxxxx",
  "refresh_token": "ghr_xxxxx",
  "expires_at": "2026-01-11T12:00:00Z",
  "created_at": "2026-01-10T12:00:00Z"
}
```

Old plain-string tokens are still accepted — the next `hula login` upgrades them to the JSON format automatically.

## Current Behavior

1. **Non-expiring tokens** — GitHub App tokens persist until revoked.
2. **Automatic refresh** — if a token is invalid, HubLaunch attempts to refresh it transparently before failing.
3. **Graceful fallback** — if refresh fails, a clear message tells you to run `hula login`.

### When You'll See an Auth Message

Only when auto-refresh fails:

```
⚠️  GitHub authentication token has expired or is invalid.

To re-authenticate, run:
  hula login
```

### Improved Login Output

```bash
$ hula login
🔄 Refreshing GitHub authentication...
1. Visit: https://github.com/login/device
2. Enter code: ABCD-1234

✅ Authenticated with GitHub
✅ Authenticated with Hula (yourusername)
✓ GitHub token saved to: ~/.hublaunch/github-token
✓ Refresh token stored for automatic renewal
✓ GitHub CLI configured

🎉 Login successful! Your authentication has been refreshed.
```

## Refresh Flow

1. `checkGhAuth()` detects an invalid token in `gh auth status`.
2. HubLaunch loads the saved token metadata from `~/.hublaunch/github-token`.
3. If a `refresh_token` is present, it's sent to GitHub's refresh endpoint.
4. Stored tokens are updated and the `gh` CLI is reconfigured.
5. The original command continues without user intervention.

## When You Need to Re-login

You'll need to run `hula login` again if:

1. You **revoked access** at https://github.com/settings/applications
2. The token file was **deleted** from `~/.hublaunch/github-token`
3. The **GitHub App was uninstalled** (if using an installation)
4. Auto-refresh fails (fallback behavior)

## Troubleshooting

### "Token has expired or is invalid"

```bash
# Re-authenticate
hula login

# Verify the token file
cat ~/.hublaunch/github-token

# Check GitHub App status
# https://github.com/settings/applications
```

### Auto-refresh Isn't Working

If you're on GitHub App tokens (the default), there's nothing to refresh — those tokens don't expire. The refresh code is there for future OAuth App support.

### Frequent Re-logins Required

Common causes and fixes:

```bash
# Check gh CLI version
gh --version

# Fix token file permissions
chmod 600 ~/.hublaunch/github-token

# Clear gh CLI state and start over
gh auth logout
hula login
```

## Testing Token Refresh (Developers)

```bash
# Simulate an invalid token
echo '{"access_token":"invalid","refresh_token":"test"}' > ~/.hublaunch/github-token

# Any hula command should trigger the refresh path
hula view
```

## Switching to OAuth App (Optional)

To use OAuth App tokens with true refresh-token auto-renewal:

1. Create an OAuth App (not GitHub App) on GitHub
2. Set `GITHUB_APP_CLIENT_ID` to the OAuth App client ID (`Ov...`)
3. The existing refresh flow picks up `refresh_token` automatically

## References

- [GitHub Apps vs OAuth Apps](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/differences-between-github-apps-and-oauth-apps)
- [Device Flow](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app#using-the-device-flow-to-generate-a-user-access-token)
- [Token Expiration](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/token-expiration-and-revocation)

For general authentication and setup issues, see [Troubleshooting](troubleshooting.md).
