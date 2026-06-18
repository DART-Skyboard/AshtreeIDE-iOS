#!/usr/bin/env python3
"""
App Store Connect Submit-for-Review Script
Ash Tree IDE · DART Meadow | Radical Deepscale LLC.
Waits for build processing, then submits the latest build for App Store review.
"""
import jwt, time, urllib.request, urllib.error, json, sys, os

KEY_ID   = "NQXQ595W59"
ISSUER   = os.environ.get("ASC_ISSUER", "")
APP_ID   = "6780086515"
KEY_PATH = os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_NQXQ595W59.p8")

if not ISSUER:
    print("ERROR: ASC_ISSUER env var not set")
    sys.exit(1)

with open(KEY_PATH, "r") as f:
    private_key = f.read()

def make_token():
    return jwt.encode(
        {"iss": ISSUER, "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"},
        private_key, algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"})

def asc(path, method="GET", body=None):
    token = make_token()
    req = urllib.request.Request(
        f"https://api.appstoreconnect.apple.com/v1{path}",
        data=json.dumps(body).encode() if body else None,
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        print(f"ASC {method} {path} -> {e.code}: {e.read().decode()[:300]}")
        return None

# Wait for build to finish processing in ASC (up to 15 min)
print("Waiting for build to process in App Store Connect...")
build_id = None
for attempt in range(30):
    time.sleep(30)
    builds = asc(f"/builds?filter[app]={APP_ID}&filter[processingState]=VALID&limit=5&sort=-uploadedDate")
    if builds and builds.get("data"):
        build_id = builds["data"][0]["id"]
        version = builds["data"][0]["attributes"].get("version","?")
        print(f"Build processed: id={build_id} version={version}")
        break
    print(f"  [{(attempt+1)*30}s] Still processing...")

if not build_id:
    print("Build not yet processed. Submit manually in App Store Connect.")
    sys.exit(0)

# Find app store version ready for submission
versions = asc(f"/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=5")
version_id = None
if versions and versions.get("data"):
    for v in versions["data"]:
        state = v["attributes"]["appStoreState"]
        ver   = v["attributes"]["versionString"]
        print(f"  Version {ver}: {state}")
        if state in ["READY_FOR_SUBMISSION","PREPARE_FOR_SUBMISSION","DEVELOPER_REJECTED","REJECTED"]:
            version_id = v["id"]
            print(f"Using version {ver} (id={version_id})")
            break

if not version_id:
    print("No version found ready for submission.")
    print("Go to App Store Connect -> Ash Tree IDE -> Submit for Review manually.")
    sys.exit(0)

# Attach build to the version
print(f"Attaching build {build_id} to version {version_id}...")
result = asc(f"/appStoreVersions/{version_id}/relationships/build", method="PATCH",
             body={"data": {"type": "builds", "id": build_id}})
print(f"Build attached: {result is not None}")

# Submit for review
print("Submitting for review...")
submit = asc("/appStoreVersionSubmissions", method="POST",
    body={"data": {
        "type": "appStoreVersionSubmissions",
        "relationships": {
            "appStoreVersion": {
                "data": {"type": "appStoreVersions", "id": version_id}
            }
        }
    }})

if submit and submit.get("data"):
    print("SUCCESS: Ash Tree IDE submitted for App Store Review!")
    print(f"Submission ID: {submit['data']['id']}")
else:
    print("Auto-submit response:", json.dumps(submit, indent=2) if submit else "None")
    print("Check App Store Connect to confirm or submit manually.")
