# Hotspot-over-Proxy — Detailed Implementation Plan (v3 Final)

## Confirmed Facts (No Assumptions)

| Item | Value |
|---|---|
| University proxy | `172.16.0.6:80` — **no authentication required** |
| Wi-Fi interface | `wlp0s20f3` (Intel `iwlmvm` driver) |
| Hotspot virtual interface | dynamically detected (usually `ap0`) |
| Hotspot subnet | **dynamically extracted** from the active AP interface |
| Hotspot tool | `create_ap` (part of `linux-wifi-hotspot`) |
| `redsocks` | Installed at `/usr/bin/redsocks` v0.5 |
| `iptables` | Installed — modules `nf_nat`, `xt_REDIRECT` already loaded |
| `dnsmasq` | Installed — managed by `create_ap` automatically |
| `ip_forward` | Already `1` (enabled) |
| `off` behavior | **Only strip proxy routing. Hotspot stays running.** |

---

## Traffic Flow — University Mode

```
[Phone/Device]
     │  TCP SYN to 142.250.10.100:443 (Google)
     ▼
[ap0 interface]  ← dynamically detected
     │
     │  iptables PREROUTING chain (nat table)
     │  Rule: -s <DYNAMIC_SUBNET> -p tcp --dport 80  → REDIRECT → :12345
     │  Rule: -s <DYNAMIC_SUBNET> -p tcp --dport 443 → REDIRECT → :12345
     │  (packets from laptop itself are NOT matched — subnet filter protects us)
     ▼
[redsocks — 127.0.0.1:12345]
     │  Reads original destination from SO_ORIGINAL_DST socket option
     │  Sends:  CONNECT 142.250.10.100:443 HTTP/1.1
     │          Host: 142.250.10.100
     ▼
[University Proxy — 172.16.0.6:80]
     │  Opens raw TCP tunnel to 142.250.10.100:443
     │  Returns:  HTTP/1.1 200 Connection established
     ▼
[Internet — 142.250.10.100:443]
     │  TLS handshake completes end-to-end (phone ↔ google)
     │  No MITM. No cert errors. No interception.
     ▼
[Response piped back through redsocks → phone]
```

---

## Script Precondition Checks & Dynamic Detection

This is what the script does **before** anything else when `on` is called:

### Step 1 — Check binaries & Hotspot Process
```bash
# Check create_ap exists
if ! command -v create_ap &>/dev/null; then exit 1; fi

# Check if a hotspot is currently running
if ! create_ap --list-running &>/dev/null; then exit 1; fi
```

### Step 2 — Dynamically Detect AP Interface
`create_ap` creates virtual interfaces starting with `ap`. We find the active one:
```bash
AP_IFACE=$(ip link show | awk '/^[0-9]+: ap[0-9]+:/ {sub(/:$/,"",$2); print $2}' | head -1)
if [ -z "$AP_IFACE" ]; then exit 1; fi
```

### Step 3 — Dynamically Extract Subnet (The Safe Way)
Instead of guessing `192.168.12.0/24`, we query the kernel for the exact IP range currently assigned to the active `ap0` interface:
```bash
HOTSPOT_SUBNET=$(ip -o -f inet addr show "$AP_IFACE" | awk '{print $4}')
if [ -z "$HOTSPOT_SUBNET" ]; then
    echo "[!] Could not determine subnet for $AP_IFACE."
    exit 1
fi
# Example Output: 192.168.12.1/24
```
This absolutely guarantees that `iptables` only intercepts traffic from the hotspot clients, adapting perfectly if the user changes the IP range in the `wihotspot` GUI.

### Step 4 — Idempotency & Zombie Check
Ensure proxy isn't already active (check state file) and `redsocks` isn't lingering.

---

## The ON / OFF Sequence

The sequence remains exactly as planned:
1. Write temporary `/tmp/redsocks-hotspot.conf`
2. Start `redsocks` in background (`daemon=off` + `&`) and save PID.
3. Inject surgical `iptables -t nat -A PREROUTING -s "$HOTSPOT_SUBNET" ...` rules.
4. Save `$AP_IFACE`, `$HOTSPOT_SUBNET`, and `$REDSOCKS_PID` to `/tmp/matrix-hotspot-proxy.state`.

On `off`, the script simply reads the state file, runs `iptables -D` with the exact same variables, kills the PID, and deletes the files.

---

## A Note on DNS Behavior

> [!WARNING]
> **DNS Fallback Strategy**
> As discussed, HTTP proxies cannot forward UDP DNS queries. The phone relies on the university's local DNS servers (via the laptop's `dnsmasq`) to resolve addresses. 
> 
> **How to tell if this fails:** When you test this at the university, if the phone connects successfully but browsers instantly say `DNS_PROBE_FINISHED_NO_INTERNET` (before even trying to load the page), it means the university blocks all external DNS. 
> 
> **The Fix (if it happens):** We will install a lightweight DNS-over-HTTPS daemon (like `cloudflared`) on the laptop. This encrypts DNS queries into TCP HTTPS traffic, which `redsocks` can seamlessly tunnel through the proxy just like normal web traffic!

---

## Open Questions

> [!NOTE]
> I have zero open technical questions. The architecture is solid, dynamic, and strictly safe. 
> 
> Please review and approve this final plan, and we will move straight to coding!
