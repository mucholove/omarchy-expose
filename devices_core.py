"""Shared logic for mac-status and device-config: Tailscale discovery, power
classification, strict validation and safe config I/O.

Nothing in here ever reads, stores or passes a password.
"""
import calendar
import ipaddress
import json
import os
import re
import socket
import stat
import subprocess
import tempfile
import time

PROBE_TIMEOUT = 1.0
PMSET_TTL = 600
RECENT_OFFLINE = 12 * 3600  # a Mac that dropped off this recently is most likely asleep

PROTOCOLS = ("vnc", "rdp", "ssh")
DEFAULT_PORTS = {"vnc": 5900, "rdp": 3389, "ssh": 22}
OS_PROTOCOL = {"macos": "vnc", "windows": "rdp", "linux": "ssh"}

MAX_DEVICES = 64
MAX_USERS = 16
MAX_NOTES = 500
MAX_FILE = 1 << 20

ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
MATCH_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}$")
# Never starts with "-": a user name must not be able to look like an ssh option.
USER_RE = re.compile(r"^[A-Za-z0-9._][A-Za-z0-9._-]{0,63}$")
HOST_RE = re.compile(
    r"^(?=.{1,253}$)[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
    r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$")


def state_dir():
    return os.path.expanduser("~/.local/state/expose-mucholove")


def config_path():
    return os.path.expanduser("~/.config/omarchy/expose-devices.json")


def legacy_path():
    return os.path.expanduser("~/.config/omarchy/expose-macs.json")


def profile_dir():
    return os.path.expanduser("~/.local/share/expose-mucholove/remmina")


# ---------------------------------------------------------------- validation

def clean_text(value, limit, multiline=False):
    """Display text: str, no control characters, bounded. Raises ValueError."""
    if not isinstance(value, str):
        raise ValueError("must be text")
    value = value.strip()
    if len(value) > limit:
        raise ValueError(f"longer than {limit} characters")
    for ch in value:
        if ch == "\n" and multiline:
            continue
        if ord(ch) < 32 or 127 <= ord(ch) < 160 or ch in "\u2028\u2029\u202e":
            raise ValueError("contains control characters")
    return value


def valid_address(value):
    """IPv4, IPv6 (no zone) or host name. Returns the string or raises."""
    if not isinstance(value, str):
        raise ValueError("must be text")
    value = value.strip()
    if value == "":
        return ""
    if len(value) > 253 or "%" in value:
        raise ValueError("not a valid address")
    try:
        ipaddress.ip_address(value)
        return value
    except ValueError:
        pass
    if not HOST_RE.match(value):
        raise ValueError("not a valid IP address or host name")
    return value


def valid_port(value):
    if value is None or value == "":
        return None
    if isinstance(value, bool) or not isinstance(value, int) or not 1 <= value <= 65535:
        raise ValueError("port must be a whole number from 1 to 65535")
    return value


def valid_user(entry):
    if not isinstance(entry, dict):
        raise ValueError("user must be an object")
    name = entry.get("name")
    if not isinstance(name, str) or not USER_RE.match(name):
        raise ValueError(f"user name {str(name)[:20]!r} may only use letters, digits . _ - (max 64)")
    return {"name": name, "label": clean_text(entry.get("label", ""), 64)}


def _ident(v):
    if not isinstance(v, str) or not ID_RE.match(v):
        raise ValueError("use letters, digits . _ - (max 64), starting with a letter or digit")
    return v


def _match(v):
    if v == "" or v is None:
        return ""
    if not isinstance(v, str) or not MATCH_RE.match(v):
        raise ValueError("use letters, digits, space . _ - (max 64)")
    return v


def _protocol(v):
    if v not in PROTOCOLS:
        raise ValueError("must be vnc, rdp or ssh")
    return v


def _flag(v):
    if not isinstance(v, bool):
        raise ValueError("must be true or false")
    return v


def validate_device(raw):
    """Strict validation of one config entry -> (clean|None, errors).
    Unknown keys are dropped."""
    if not isinstance(raw, dict):
        return None, ["entry must be an object"]
    errors, out = [], {}
    specs = [
        ("id", _ident, None), ("match", _match, ""),
        ("name", lambda v: clean_text(v, 64), ""), ("address", valid_address, ""),
        ("protocol", _protocol, "vnc"), ("port", valid_port, None),
        ("alwaysOn", _flag, True), ("hidden", _flag, False),
        ("notes", lambda v: clean_text(v, MAX_NOTES, True), ""),
    ]
    for key, fn, default in specs:
        if key not in raw:
            if key == "id":
                errors.append("id: required")
            out[key] = default
            continue
        try:
            out[key] = fn(raw[key])
        except ValueError as exc:
            errors.append(f"{key}: {exc}")
    users = []
    raw_users = raw.get("users", [])
    if not isinstance(raw_users, list):
        errors.append("users: must be a list")
    else:
        if len(raw_users) > MAX_USERS:
            errors.append(f"users: at most {MAX_USERS}")
        seen = set()
        for i, entry in enumerate(raw_users[:MAX_USERS]):
            try:
                user = valid_user(entry)
                if user["name"] in seen:
                    raise ValueError(f"user {user['name']!r} is listed twice")
                seen.add(user["name"])
                users.append(user)
            except ValueError as exc:
                errors.append(f"users[{i + 1}]: {exc}")
    out["users"] = users
    return (None, errors) if errors else (out, [])


def default_entry(dev_id, match="", protocol="vnc"):
    return {"id": dev_id, "match": match, "name": "", "address": "", "protocol": protocol,
            "port": None, "alwaysOn": True, "hidden": False, "notes": "", "users": []}


# ------------------------------------------------------------------- file io

class ConfigError(Exception):
    pass


def read_json_file(path):
    """Read a small regular JSON file without following symlinks.
    None when missing; ConfigError on anything unsafe or unreadable."""
    try:
        st = os.lstat(path)
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise ConfigError(f"cannot read {path}: {exc.strerror}")
    if stat.S_ISLNK(st.st_mode):
        raise ConfigError(f"{path} is a symbolic link; refusing to follow it")
    if not stat.S_ISREG(st.st_mode):
        raise ConfigError(f"{path} is not a regular file")
    if st.st_size > MAX_FILE:
        raise ConfigError(f"{path} is too large")
    try:
        with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW)) as f:
            return json.load(f)
    except (OSError, ValueError) as exc:
        raise ConfigError(f"cannot parse {path}: {exc}")


def ensure_private_dir(path, tighten=True):
    """Create path as 0700. An existing directory is tightened only when tighten is true:
    directories this plugin owns are; shared ones like ~/.config/omarchy are left alone
    (the file inside is 0600, which is what protects it)."""
    if os.path.islink(path):
        raise ConfigError(f"{path} is a symbolic link; refusing to use it")
    existed = os.path.isdir(path)
    os.makedirs(path, mode=0o700, exist_ok=True)
    if tighten or not existed:
        os.chmod(path, 0o700)


def atomic_write(path, text, mode=0o600):
    """Temp file in the same directory, then os.replace."""
    fd, tmp = tempfile.mkstemp(prefix=".tmp-", dir=os.path.dirname(path))
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w") as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def slug(text, fallback="device"):
    s = re.sub(r"[^A-Za-z0-9._-]+", "-", str(text)).strip("-._")[:64]
    return s if s and ID_RE.match(s) else fallback


def legacy_entries(legacy):
    """expose-macs.json -> device entries (read only; never written back)."""
    out, ids = [], set()
    if not isinstance(legacy, dict) or not isinstance(legacy.get("macs"), list):
        return out
    for raw in legacy["macs"][:MAX_DEVICES]:
        if not isinstance(raw, dict):
            continue
        base = default_entry(slug(raw.get("match", ""), ""), str(raw.get("match", "")), "vnc")
        if not base["id"] or base["id"] in ids:
            continue
        candidate = dict(base, name=raw.get("name", ""), alwaysOn=raw.get("alwaysOn", True))
        user = raw.get("user")
        if isinstance(user, str) and user:
            candidate["users"] = [{"name": user, "label": ""}]
        clean, _ = validate_device(candidate)
        if clean is None:
            clean, _ = validate_device(base)
        if clean is not None:
            ids.add(clean["id"])
            out.append(clean)
    return out


def load_config():
    """(entries, warnings, source). Malformed entries are skipped."""
    warnings = []
    try:
        data = read_json_file(config_path())
        if data is None:
            legacy = read_json_file(legacy_path())
            return (legacy_entries(legacy), warnings, "legacy") if legacy else ([], warnings, "none")
    except ConfigError as exc:
        return [], [str(exc)], "none"
    if not isinstance(data, dict) or data.get("version") != 1 or not isinstance(data.get("devices"), list):
        return [], ["expose-devices.json is not a version 1 device list"], "none"
    entries, ids = [], set()
    for i, raw in enumerate(data["devices"][:MAX_DEVICES]):
        clean, errors = validate_device(raw)
        if clean is None:
            warnings.append(f"skipped device {i + 1}: {errors[0]}")
        elif clean["id"] in ids:
            warnings.append(f"skipped duplicate id {clean['id']}")
        else:
            ids.add(clean["id"])
            entries.append(clean)
    return entries, warnings, "file"


def pristine(entry, default_protocol):
    return (not entry["name"] and not entry["address"] and entry["protocol"] == default_protocol
            and entry["port"] is None and entry["alwaysOn"] and not entry["hidden"]
            and not entry["notes"] and not entry["users"])


def save_config(entries, default_protocols=None):
    """Validate everything, then write atomically. (ok, errors). Nothing is
    written when anything is invalid."""
    if not isinstance(entries, list):
        return False, ["devices must be a list"]
    if len(entries) > MAX_DEVICES:
        return False, [f"at most {MAX_DEVICES} devices"]
    clean_list, errors, ids = [], [], set()
    for i, raw in enumerate(entries):
        clean, errs = validate_device(raw)
        label = str((raw.get("name") or raw.get("id") or "") if isinstance(raw, dict) else "") or f"device {i + 1}"
        if clean is None:
            errors += [f"{label[:40]}: {e}" for e in errs]
            continue
        if clean["id"] in ids:
            errors.append(f"{label[:40]}: id {clean['id']} used twice")
        ids.add(clean["id"])
        clean_list.append(clean)
    if errors:
        return False, errors
    defaults = default_protocols or {}
    keep = [e for e in clean_list if not (e["id"] in defaults and pristine(e, defaults[e["id"]]))]
    path = config_path()
    try:
        ensure_private_dir(os.path.dirname(path), tighten=False)
        if os.path.islink(path):
            return False, [f"{path} is a symbolic link; refusing to write it"]
        if os.path.lexists(path):
            with open(path) as f:
                previous = f.read(MAX_FILE)
            bak = path + ".bak"
            if os.path.islink(bak):
                os.unlink(bak)
            atomic_write(bak, previous)
        atomic_write(path, json.dumps({"version": 1, "devices": keep}, indent=2) + "\n")
    except (OSError, ConfigError) as exc:
        return False, [f"could not save: {exc}"]
    return True, []


# --------------------------------------------------------------- last user

def last_users():
    try:
        data = read_json_file(os.path.join(state_dir(), "last-user.json"))
    except ConfigError:
        return {}
    if not isinstance(data, dict):
        return {}
    return {k: v for k, v in data.items() if isinstance(k, str) and ID_RE.match(k)
            and isinstance(v, str) and USER_RE.match(v)}


def remember_user(dev_id, user):
    data = last_users()
    data[dev_id] = user
    try:
        ensure_private_dir(state_dir())
        atomic_write(os.path.join(state_dir(), "last-user.json"), json.dumps(data))
    except (OSError, ConfigError):
        pass


# ------------------------------------------------------------ remmina profile

def server_string(host, port):
    return f"[{host}]:{port}" if ":" in host else f"{host}:{port}"


def write_profile(entry, user, host, port):
    """Write ~/.local/share/expose-mucholove/remmina/<id>-<user>.remmina.

    The password is left EMPTY on purpose: Remmina prompts for it and may keep
    it in its own keyring. Keys follow Remmina 1.4 profile files but were NOT
    verified against a live Remmina (not installed on the build machine).
    """
    if not USER_RE.match(user) or not ID_RE.match(entry["id"]):
        raise ConfigError("invalid id or user")
    host = valid_address(host)
    if not host:
        raise ConfigError("device has no address to connect to")
    proto = entry["protocol"]
    title = clean_text((entry["name"] or entry["id"]) + " (" + user + ")", 100)
    lines = [
        "[remmina]",
        f"name={title}",
        f"protocol={'VNC' if proto == 'vnc' else 'RDP'}",
        f"server={server_string(host, port)}",
        f"username={user}",
        "password=",
        "disablepasswordstoring=0",
        "viewmode=1",
        "colordepth=32",
    ]
    lines += ["quality=9"] if proto == "vnc" else ["quality=0", "resolution_mode=2", "sound=off"]
    ensure_private_dir(os.path.dirname(profile_dir()))
    ensure_private_dir(profile_dir())
    path = os.path.join(profile_dir(), f"{entry['id']}-{user}.remmina")
    if os.path.islink(path):
        os.unlink(path)
    atomic_write(path, "\n".join(lines) + "\n")
    return path


# ---------------------------------------------------------- tailscale peers

def parse_time(text):
    """RFC 3339 timestamp (nanoseconds, any offset) to epoch seconds; 0 if unset."""
    if not text or text.startswith("0001-"):
        return 0
    m = re.match(r"(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)(?:\.\d+)?(Z|[+-]\d\d:\d\d)?$", text)
    if not m:
        return 0
    y, mo, d, h, mi, s, tz = m.groups()
    epoch = calendar.timegm((int(y), int(mo), int(d), int(h), int(mi), int(s)))
    if tz and tz != "Z":
        sign = 1 if tz[0] == "+" else -1
        epoch -= sign * (int(tz[1:3]) * 3600 + int(tz[4:6]) * 60)
    return epoch


def safe_address(value):
    try:
        return valid_address(value)
    except ValueError:
        return ""


def split_hostport(text):
    """CurAddr 'ip:port' or '[v6]:port' -> the address without the port, or ''."""
    text = str(text or "")
    if text.startswith("["):
        host = text[1:].split("]")[0]
    else:
        host = text.rsplit(":", 1)[0] if text.count(":") == 1 else text
    try:
        ipaddress.ip_address(host)
        return host
    except ValueError:
        return ""


def clean_or_blank(text):
    try:
        return clean_text(str(text), 100)
    except ValueError:
        return ""


def peers(status, os_names):
    """Peers whose OS is in os_names (lowercase), as plain dicts. The local
    machine is not under Peer; anything with a self flag is skipped too."""
    result = []
    for peer in (status.get("Peer") or {}).values():
        os_name = str(peer.get("OS", "")).lower()
        os_name = "macos" if os_name == "darwin" else os_name
        if os_name not in os_names or peer.get("Self") or peer.get("IsSelf"):
            continue
        all_ips = []
        for ip in peer.get("TailscaleIPs") or []:
            try:
                ipaddress.ip_address(ip)
                all_ips.append(ip)
            except ValueError:
                pass
        v4 = [ip for ip in all_ips if ":" not in ip]
        if not v4:
            continue
        dns = safe_address(str(peer.get("DNSName", "")).rstrip("."))
        label = dns.split(".")[0] if dns else str(peer.get("HostName", ""))
        lan = split_hostport(peer.get("CurAddr", ""))
        relay = re.sub(r"[^A-Za-z0-9._-]", "", str(peer.get("Relay", "")))[:32]
        online = peer.get("Online") is True
        if not online:
            connection = ""
        elif lan:
            connection = "direct"
        else:
            connection = "relayed via " + relay if relay else "relayed"
        result.append({
            "id": slug(label, "device"),
            "hostName": clean_or_blank(peer.get("HostName", "")),
            "os": os_name,
            "ip": v4[0],
            "ips": all_ips,
            "dnsName": dns,
            "lanAddress": lan if online else "",
            "connection": connection,
            "online": online,
            "lastSeen": parse_time(str(peer.get("LastSeen", ""))),
        })
    return sorted(result, key=lambda p: p["id"])


def tailscale_status(timeout=4):
    out = subprocess.run(["tailscale", "status", "--json"], capture_output=True, text=True, timeout=timeout)
    return json.loads(out.stdout or "{}")


def match_peer_entries(peer_list, entries):
    """Map peer id -> config entry: exact id first, then substring `match`;
    each entry claims at most one peer. Returns (map, claimed entry ids)."""
    claimed, result = set(), {}
    by_id = {e["id"]: e for e in entries}
    for peer in peer_list:
        if peer["id"] in by_id:
            result[peer["id"]] = by_id[peer["id"]]
            claimed.add(peer["id"])
    for peer in peer_list:
        if peer["id"] in result:
            continue
        needle = [peer["id"].lower(), peer["hostName"].lower(), peer["ip"]]
        for entry in entries:
            m = entry["match"].lower()
            if entry["id"] in claimed or not m:
                continue
            if any(m in item for item in needle):
                result[peer["id"]] = entry
                claimed.add(entry["id"])
                break
    return result, claimed


# ------------------------------------------------------- power/classification

def parse_pmset(text):
    """AC-power sleep minutes and wake-on-network from `pmset -g [custom]`."""
    section, values = "", {}
    for line in str(text).splitlines():
        stripped = line.strip()
        if stripped.endswith(":") and " " in stripped.rstrip(":"):
            section = stripped.lower()
            continue
        m = re.match(r"^(\w+)\s+(\d+)\b", stripped)
        if not m:
            continue
        key, value = m.group(1), int(m.group(2))
        if section.startswith("battery"):
            continue
        values.setdefault(key, value)
    sleep, womp = values.get("sleep"), values.get("womp")
    return {"sleep": sleep, "womp": None if womp is None else womp != 0}


def duration(seconds):
    seconds = max(0, int(seconds))
    if seconds < 90:
        return "moments"
    if seconds < 3600:
        return f"{seconds // 60} min"
    if seconds < 86400:
        return f"{seconds // 3600}h"
    return f"{seconds // 86400}d"


def classify(online, last_seen, now, power, expected=True):
    reasons = []
    sleep = power.get("sleep") if power else None
    if not online:
        age = now - last_seen if last_seen else None
        recent = age is not None and age < RECENT_OFFLINE
        reasons.append(f"offline {duration(age)}" if age is not None else "offline")
        return {"state": "sleeps" if recent else "offline", "alwaysOn": False, "reasons": reasons}
    if sleep is None:
        return {"state": "online", "alwaysOn": None, "reasons": ["power settings unknown"]}
    if sleep > 0:
        reasons.append(f"sleeps after {sleep} min")
        if power.get("womp") is False:
            reasons.append("Wake for network access is off")
        return {"state": "sleeps", "alwaysOn": False, "reasons": reasons}
    if power.get("womp") is False:
        reasons.append("Wake for network access is off")
    return {"state": "online", "alwaysOn": True, "reasons": reasons}


def classify_other(online, last_seen, now):
    """Non-Mac devices: online/offline history only, no power inference."""
    if online:
        return {"state": "online", "alwaysOn": None, "reasons": []}
    age = now - last_seen if last_seen else None
    return {"state": "offline", "alwaysOn": False,
            "reasons": [f"offline {duration(age)}" if age is not None else "offline"]}


def port_open(host, port):
    try:
        with socket.create_connection((host, port), PROBE_TIMEOUT):
            return True
    except OSError:
        return False


def cached_power(ip, user):
    """Power settings via cache or a read-only BatchMode ssh; None when
    unavailable. Never accepts an unknown host key, never prompts."""
    if user and not USER_RE.match(user):
        return None
    path = os.path.join(state_dir(), "pmset-" + re.sub(r"[^0-9a-zA-Z.]", "_", ip) + ".json")
    try:
        with open(path) as f:
            cached = json.load(f)
        if time.time() - float(cached.get("at", 0)) < PMSET_TTL and cached.get("user") == user:
            return cached.get("power")
    except (OSError, ValueError):
        pass
    power = None
    target = f"{user}@{ip}" if user else ip
    try:
        for command in ("pmset -g custom", "pmset -g"):
            out = subprocess.run(
                ["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
                 "-o", "ConnectTimeout=2", "--", target, command],
                capture_output=True, text=True, timeout=5, stdin=subprocess.DEVNULL)
            if out.returncode == 0:
                parsed = parse_pmset(out.stdout)
                if parsed["sleep"] is not None:
                    power = parsed
                    break
    except (OSError, subprocess.SubprocessError):
        power = None
    try:
        os.makedirs(state_dir(), exist_ok=True)
        with open(path, "w") as f:
            json.dump({"at": time.time(), "user": user, "power": power}, f)
    except OSError:
        pass
    return power


# ------------------------------------------------------- remmina availability

PLUGIN_DIR = "/usr/lib/remmina/plugins"
# protocol -> (plugin file, Arch package that provides its library)
PLUGINS = {"vnc": ("remmina-plugin-vnc.so", "libvncserver"), "rdp": ("remmina-plugin-rdp.so", "freerdp")}
INSTALL_ALL = "sudo pacman -S remmina libvncserver freerdp"


def plugin_broken(returncode, output):
    """True when `ldd <plugin>` says the plugin cannot load: it failed (file
    missing) or lists an unresolved library. Remmina's own VNC plugin is the
    one that speaks Apple's ARD login; gtk-vnc (GVNC) does not."""
    return returncode != 0 or "not found" in str(output)


def run_argv(argv):
    try:
        out = subprocess.run(argv, capture_output=True, text=True, timeout=5, stdin=subprocess.DEVNULL)
        return out.returncode, out.stdout + out.stderr
    except (OSError, subprocess.SubprocessError) as exc:
        return 1, str(exc)


def client_check(protocol, have_remmina, ldd=run_argv):
    """{"ok": bool, "message": str} for a click on Connect. `ldd` takes an argv
    and returns (returncode, text); no shell is involved."""
    if protocol not in PLUGINS:
        return {"ok": True, "message": ""}
    if not have_remmina:
        return {"ok": False, "message": "Remmina is not installed. Install it with: " + INSTALL_ALL}
    broken = {p: plugin_broken(*ldd(["ldd", os.path.join(PLUGIN_DIR, f)])) for p, (f, _) in PLUGINS.items()}
    if not broken[protocol]:
        return {"ok": True, "message": ""}
    packages = [PLUGINS[p][1] for p in ("vnc", "rdp") if broken[p]]
    name = "VNC" if protocol == "vnc" else "RDP"
    return {"ok": False, "message": f"Remmina's {name} plugin is missing a library. Install it with: sudo pacman -S "
            + " ".join(packages)}
