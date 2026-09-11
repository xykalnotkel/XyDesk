#!/usr/bin/env python3
"""
XyDesk Backend Live Health Check
Gunakan token dari uploads/my-binimbg.txt (jangan hardcode di repo)

Usage:
  python tool/check_backend_live.py --admin-secret $ADMIN_SECRET
  atau tanpa argumen: hanya cek endpoint publik (tanpa /turn-ice)

Cek:
  - signal healthz
  - news feed
  - turn-ice (bila ADMIN_SECRET diberi)
  - auth OTP request (ke delivered@resend.dev — alamat uji Resend yang selalu ok)
  - resend domains (bila RESEND_API_KEY env)
"""
import argparse, json, sys, os, time
try:
    import requests
except ImportError:
    print("pip install requests")
    sys.exit(1)

SIGNAL = "https://signal.xydesk.my.id"
NEWS = "https://news.xydesk.my.id"

def ok(msg): print(f"\033[92m✓ {msg}\033[0m")
def fail(msg): print(f"\033[91m✗ {msg}\033[0m")
def info(msg): print(f"  {msg}")

def check_healthz():
    try:
        r = requests.get(f"{SIGNAL}/healthz", timeout=5)
        if r.text.strip() == "ok" and r.status_code == 200:
            ok(f"signaling healthz ok ({r.elapsed.total_seconds()*1000:.0f}ms)")
            return True
        else:
            fail(f"healthz {r.status_code} {r.text[:100]}")
            return False
    except Exception as e:
        fail(f"healthz error {e}")
        return False

def check_news():
    try:
        r = requests.get(f"{NEWS}/api/news", timeout=5)
        j = r.json()
        n = len(j.get("posts", []))
        slug = j["posts"][0]["slug"] if n else "-"
        ok(f"news feed {n} posts, first {slug} ({r.elapsed.total_seconds()*1000:.0f}ms)")
        return True
    except Exception as e:
        fail(f"news {e}")
        return False

def check_turn(admin_secret):
    if not admin_secret:
        info("turn-ice: skip (beri --admin-secret untuk cek TURN)")
        return None
    try:
        r = requests.get(f"{SIGNAL}/turn-ice", headers={"X-Admin": admin_secret}, timeout=7)
        if r.status_code == 403:
            fail("turn-ice 403 forbidden — ADMIN_SECRET salah")
            return False
        if r.status_code == 503:
            j = r.json()
            fail(f"turn-ice 503 turn-not-configured — {j.get('hint','')[:120]}")
            return False
        j = r.json()
        prov = j.get("providers", [])
        ice = j.get("iceServers", [])
        ok_cnt = sum(1 for p in prov if p.get("ok"))
        info(f"turn-ice {len(ice)} iceServers, providers {prov}")
        if ok_cnt > 0:
            ok(f"turn-ice {ok_cnt}/{len(prov)} provider ok, ttl {j.get('ttl')} degraded={j.get('degraded')}")
            return True
        else:
            fail(f"turn-ice 0 provider ok — {prov}")
            return False
    except Exception as e:
        fail(f"turn-ice error {e}")
        return False

def check_otp():
    try:
        r = requests.post(f"{SIGNAL}/auth/request-otp", json={"email":"delivered@resend.dev"}, timeout=7)
        j = r.json()
        if j.get("ok"):
            ok(f"otp request delivered@resend.dev ok {j}")
            return True
        else:
            fail(f"otp request failed {j}")
            return False
    except Exception as e:
        fail(f"otp {e}")
        return False

def check_resend_domains(api_key):
    if not api_key:
        info("resend domains: skip (RESEND_API_KEY env kosong)")
        return None
    try:
        r = requests.get("https://api.resend.com/domains", headers={"Authorization": f"Bearer {api_key}"}, timeout=7)
        j = r.json()
        for d in j.get("data", []):
            info(f"domain {d['name']} status={d['status']}")
        ok(f"resend {len(j.get('data',[]))} domains")
        return True
    except Exception as e:
        fail(f"resend {e}")
        return False

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--admin-secret", default=os.getenv("ADMIN_SECRET"))
    ap.add_argument("--resend-key", default=os.getenv("RESEND_API_KEY"))
    args = ap.parse_args()
    res = []
    res.append(check_healthz())
    res.append(check_news())
    res.append(check_otp())
    res.append(check_turn(args.admin_secret))
    res.append(check_resend_domains(args.resend_key))
    # summary
    fails = [r for r in res if r is False]
    if fails:
        print(f"\n{fails.__len__()} checks failed")
        sys.exit(1)
    else:
        print("\nAll critical checks ok (atau skipped)")
        sys.exit(0)
