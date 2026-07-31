# Notifications

HubLaunch's promise is that you're interrupted only on purpose — which means
the notification is where your side of the loop starts. This page covers how
to receive notifications (Slack out of the box, Telegram or anything else via
a small bridge) and how far you can take automating your response.

## What gets sent, and when

Set `updateNotificationUrl` in `.hublaunch/hublaunch.config.js` and the server
POSTs to it at each lifecycle stage of a launched task:

| Stage           | When                                                                  |
| --------------- | --------------------------------------------------------------------- |
| `running`       | The sandbox has started working on your plan                           |
| `issue_created` | The GitHub issue for the run exists (with its URL)                     |
| `completed`     | The PR is ready — includes the PR link and the verification score      |
| `failed`        | Something went wrong — includes the failure stage and a log tail       |

Notifications are strictly forward-only (you'll never get a "started" after a
"completed") and sent once per stage.

## Slack (works out of the box)

URLs on `hooks.slack.com` get a ready-to-render `{ "text": "…" }` body. Create
an [incoming webhook](https://api.slack.com/messaging/webhooks) for your
channel and paste the URL:

```js
export const config = {
  // ...
  updateNotificationUrl: "https://hooks.slack.com/services/T0/B0/secret",
  updateNotificationNameTag: "<@U0123456>", // optional: who to @-mention
};
```

`updateNotificationNameTag` is rendered verbatim in the message — use Slack
mention markup (`<@YOUR_MEMBER_ID>`) so completions actually ping you.

## Any other webhook (generic JSON)

Every non-Slack URL receives a JSON body with the raw event fields — including
`trackingName`, `status`, `prUrl`, `prNumber`, `issueUrl`, `durationSeconds`,
`verifyScore`, `verifyReason`, and a `logTail` on failures. Point it at
Discord (via a relay), ntfy, n8n, Pipedream, or your own endpoint.

## Telegram

Telegram has no incoming-webhook URL you can paste directly — its Bot API
wants a `chat_id` plus `text`. The clean solution is a tiny relay that
reformats the JSON event and forwards it. A complete Cloudflare Worker
(free tier is plenty):

```js
// wrangler secrets: TG_TOKEN (from @BotFather), TG_CHAT (your chat id)
export default {
  async fetch(request, env) {
    const e = await request.json();
    const lines = [
      `HubLaunch: ${e.trackingName} — ${e.status}`,
      e.prUrl && `PR: ${e.prUrl}`,
      e.verifyReason && `Verification: ${e.verifyReason}`,
      e.error && `Error: ${e.error}`,
    ].filter(Boolean);
    await fetch(`https://api.telegram.org/bot${env.TG_TOKEN}/sendMessage`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ chat_id: env.TG_CHAT, text: lines.join("\n") }),
    });
    return new Response("ok");
  },
};
```

Deploy it, then set `updateNotificationUrl` to the worker's URL. The same
pattern works for any chat platform with a bot API — the relay is the adapter.

If you'd rather not deploy anything, hosted automation tools (n8n, Pipedream,
Zapier) can receive the webhook and forward to Telegram with a few clicks.

## Automating your response

The notification carries everything needed to prepare your review before you
even switch windows. Since a completion event includes the tracking name and
PR link, a small watcher on your machine (or the relay above) can react by
pulling the run's artifacts with [`hula info`](./advanced.md#hula-info):

```bash
hula info <trackingName> --initial --raw   # the PR summary, to stdout
hula info <trackingName> --diff            # the PR diff, opened in your editor
```

Teams have used this to make the "approve" moment nearly instant: when the
"PR ready" message arrives, a watcher opens the PR diff and summary in an
editor pane and a preview window automatically — so by the time you sit down,
everything you need to approve is already on screen. `hula info
<trackingName> --clientSessionId` even returns the agent session that launched
the run, if you want to resume it in place.

Start simple: a Slack or Telegram ping with the PR link is 90% of the value.
The rest is garnish you can add when the loop feels worth tightening.
