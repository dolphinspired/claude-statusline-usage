# `/usage` Command — Decompiled from Claude Code v2.1.63

Extracted from the compiled binary at:
`~/.local/share/claude/versions/2.1.63`

The binary embeds minified JavaScript (React/Ink). The code below is reconstructed
into readable TypeScript/React form.

---

## Overview

`/usage` is not a standalone slash command — it is a **tab** inside the Settings
dialog (`m2H`), alongside "Status" and "Config". It renders via the Ink terminal UI
library.

The full flow:
1. `UsageTab` mounts and calls `fetchUsageData()`
2. `fetchUsageData()` hits `GET /api/oauth/usage` with OAuth auth headers
3. Response fields `five_hour`, `seven_day`, `seven_day_sonnet`, `extra_usage` drive
   the UI
4. Each limit is rendered as a `UsageBar` (progress bar + percent + reset time)

---

## API Endpoint

```
GET {BASE_API_URL}/api/oauth/usage
Headers:
  Content-Type: application/json
  User-Agent: <claude version string>
  ...oauth headers
Timeout: 5000ms
```

### Response shape (inferred)

```ts
interface UsageResponse {
  five_hour?:       UsageLimit;   // "Current session"
  seven_day?:       UsageLimit;   // "Current week (all models)"
  seven_day_sonnet?: UsageLimit;  // "Current week (Sonnet only)"
  extra_usage?:     ExtraUsage;
}

interface UsageLimit {
  utilization: number | null; // 0–100
  resets_at:   string;        // ISO timestamp
}

interface ExtraUsage {
  is_enabled:     boolean;
  monthly_limit:  number | null; // cents, null = unlimited
  used_credits?:  number;        // cents
  utilization?:   number;        // 0–100
}
```

---

## Source Code (Reconstructed)

### API fetch (`gdD`)

```ts
async function fetchUsageData() {
  if (tokenIsExpired()) return null;
  const auth = getAuth();
  if (auth.error) throw Error(`Auth error: ${auth.error}`);

  const headers = {
    "Content-Type": "application/json",
    "User-Agent": getUserAgent(),
    ...auth.headers,
  };
  const url = `${getBaseApiUrl()}/api/oauth/usage`;
  return (await axios.get(url, { headers, timeout: 5000 })).data;
}
```

### Usage bar component (`pdD`)

```tsx
function UsageBar({ title, limit, maxWidth, showTimeInReset = true, extraSubtext }) {
  const { utilization, resets_at } = limit;
  if (utilization === null) return null;

  const percentText = `${Math.floor(utilization)}% used`;
  let subtext = resets_at
    ? `Resets ${formatRelativeTime(resets_at, true, showTimeInReset)}`
    : undefined;
  if (extraSubtext) subtext = subtext ? `${extraSubtext} · ${subtext}` : extraSubtext;

  const BAR_WIDTH = 50;
  if (maxWidth >= BAR_WIDTH + 12) {
    return (
      <Box flexDirection="column">
        <Text bold>{title}</Text>
        <Box flexDirection="row" gap={1}>
          <ProgressBar
            ratio={utilization / 100}
            width={BAR_WIDTH}
            fillColor="rate_limit_fill"
            emptyColor="rate_limit_empty"
          />
          <Text>{percentText}</Text>
        </Box>
        {subtext && <Text dimColor>{subtext}</Text>}
      </Box>
    );
  }

  // narrow terminal fallback
  return (
    <Box flexDirection="column">
      <Text>
        <Text bold>{title}</Text>
        {subtext && (
          <>
            <Text> </Text>
            <Text dimColor>· {subtext}</Text>
          </>
        )}
      </Text>
      <ProgressBar
        ratio={utilization / 100}
        width={maxWidth}
        fillColor="rate_limit_fill"
        emptyColor="rate_limit_empty"
      />
      <Text>{percentText}</Text>
    </Box>
  );
}
```

### Extra usage section (`Lw9`)

```tsx
const EXTRA_USAGE_TITLE = "Extra usage";

function ExtraUsage({ extraUsage, maxWidth }) {
  const plan = getPlan(); // "pro" | "max" | ...
  if (plan !== "pro" && plan !== "max") return false;

  if (!extraUsage.is_enabled) {
    // only shown when feature flag (kHH) is enabled
    return (
      <Box flexDirection="column">
        <Text bold>{EXTRA_USAGE_TITLE}</Text>
        <Text dimColor>Extra usage not enabled • /extra-usage to enable</Text>
      </Box>
    );
  }

  if (extraUsage.monthly_limit === null) {
    return (
      <Box flexDirection="column">
        <Text bold>{EXTRA_USAGE_TITLE}</Text>
        <Text dimColor>Unlimited</Text>
      </Box>
    );
  }

  if (
    typeof extraUsage.used_credits !== "number" ||
    typeof extraUsage.utilization !== "number"
  ) return null;

  const used  = formatCurrency(extraUsage.used_credits / 100, 2);
  const limit = formatCurrency(extraUsage.monthly_limit / 100, 2);
  const now   = new Date();
  const resetsAt = new Date(now.getFullYear(), now.getMonth() + 1, 1);

  return (
    <UsageBar
      title={EXTRA_USAGE_TITLE}
      limit={{ utilization: extraUsage.utilization, resets_at: resetsAt.toISOString() }}
      showTimeInReset={false}
      extraSubtext={`${used} / ${limit} spent`}
      maxWidth={maxWidth}
    />
  );
}
```

### Main usage tab (`ddD`)

```tsx
function UsageTab() {
  const [data,    setData]    = useState<UsageResponse | null>(null);
  const [error,   setError]   = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const { columns } = useTerminalSize();
  const maxWidth = Math.min(columns - 2, 80);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setData(await fetchUsageData());
    } catch (e) {
      const msg = e.response?.data ? extractMessage(e.response.data) : undefined;
      setError(msg ? `Failed to load usage data: ${msg}` : "Failed to load usage data");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);
  useKeyBinding("settings:retry", () => load(), { isActive: !!error && !loading });

  if (error) return (
    <Box flexDirection="column" marginTop={1} gap={1}>
      <Text color="error">Error: {error}</Text>
      <Text dimColor>
        <KeyBinding action="settings:retry" fallback="r" description="retry" />
        {" "}
        <KeyBinding action="confirm:no" fallback="Esc" description="cancel" />
      </Text>
    </Box>
  );

  if (!data) return (
    <Box flexDirection="column" marginTop={1} gap={1}>
      <Text dimColor>Loading usage data…</Text>
      <Text dimColor>
        <KeyBinding action="confirm:no" fallback="Esc" description="cancel" />
      </Text>
    </Box>
  );

  const limits = [
    { title: "Current session",            limit: data.five_hour       },
    { title: "Current week (all models)",  limit: data.seven_day       },
    { title: "Current week (Sonnet only)", limit: data.seven_day_sonnet },
  ];

  return (
    <Box flexDirection="column" marginTop={1} gap={1} width="100%">
      {!limits.some(({ limit }) => limit) && (
        <Text dimColor>/usage is only available for subscription plans.</Text>
      )}
      {limits.map(({ title, limit }) =>
        limit && <UsageBar key={title} title={title} limit={limit} maxWidth={maxWidth} />
      )}
      {data.extra_usage && (
        <ExtraUsage extraUsage={data.extra_usage} maxWidth={maxWidth} />
      )}
      <Text dimColor>
        <KeyBinding action="confirm:no" fallback="Esc" description="cancel" />
      </Text>
    </Box>
  );
}
```

### Settings dialog wiring (`m2H`)

The `/usage` tab lives inside the shared Settings dialog alongside Status and Config:

```tsx
function SettingsDialog({ onClose, context, defaultTab }) {
  // ... state for tab navigation ...
  return (
    <Box flexDirection="column">
      <Divider />
      <TabbedPanel title="Settings:" color="permission" defaultTab={defaultTab}>
        <Tab key="status" title="Status">  <StatusTab context={context} /> </Tab>
        <Tab key="config" title="Config">  <ConfigTab context={context} onClose={onClose} /> </Tab>
        <Tab key="usage"  title="Usage">   <UsageTab /> </Tab>
      </TabbedPanel>
    </Box>
  );
}
```

---

## Notes

- The `/usage` command (`ddD`) is registered under the `"usage"` tab key of the Settings dialog.
- Theme colors `rate_limit_fill` and `rate_limit_empty` control the progress bar appearance.
- `five_hour` field name suggests the "current session" window is a 5-hour rolling window.
- `extra_usage` is gated: only rendered for `pro`/`max` plan users, and only when a
  separate feature flag (`kHH`) is enabled for the "not yet enabled" nudge state.
- The `/usage` command is distinct from `/cost` (token counts) and `/stats` (session history).
