#!/usr/bin/env python3
"""Fills the privacy placeholders in one go: data/online/privacy.tres (what the game shows) and
docs/privacy.html (the public page), so both always say the same (docs/privacy-ops.md).

The placeholders: [CONTROLLER_NAME] (your legal name, or your registered business name),
[CONTACT_EMAIL] (the privacy address, deletion requests go there), [POLICY_URL] (where
docs/privacy.html is published, e.g. a GitHub Pages address; only the game uses it).

Usage (from anywhere, python3, standard library only):
  python3 tools/privacy/fill_policy.py --name "Jane Doe" --email "privacy@example.com" --url "https://example.com/privacy.html"
  python3 tools/privacy/fill_policy.py            # only copies what privacy.tres holds into the page
  python3 tools/privacy/fill_policy.py --check    # exit 1 while a placeholder is left
"""

import argparse
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
TRES = os.path.join(ROOT, "data", "online", "privacy.tres")
HTML = os.path.join(ROOT, "docs", "privacy.html")
FIELDS = {"controller_name": "[CONTROLLER_NAME]", "contact_email": "[CONTACT_EMAIL]", "policy_url": "[POLICY_URL]"}


def read_values(text):
    values = {}
    for field in FIELDS:
        match = re.search(r'^%s = "((?:[^"\\]|\\.)*)"$' % field, text, re.M)
        values[field] = match.group(1) if match else FIELDS[field]
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--name", help="the controller's legal name")
    parser.add_argument("--email", help="the privacy contact address")
    parser.add_argument("--url", help="the public address of docs/privacy.html")
    parser.add_argument("--check", action="store_true", help="exit 1 while a placeholder is left")
    args = parser.parse_args()

    with open(TRES, encoding="utf-8") as f:
        tres = f.read()
    given = {"controller_name": args.name, "contact_email": args.email, "policy_url": args.url}
    for field, value in given.items():
        if value is None:
            continue
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        tres, count = re.subn(r'^%s = ".*"$' % field, '%s = "%s"' % (field, escaped), tres, flags=re.M)
        if count != 1:
            sys.exit("%s not found in %s" % (field, TRES))
    values = read_values(tres)

    with open(HTML, encoding="utf-8") as f:
        html = f.read()
    for field, placeholder in FIELDS.items():
        if values[field] != placeholder:
            html = html.replace(placeholder, values[field].replace("&", "&amp;").replace("<", "&lt;"))

    left = [p for f, p in FIELDS.items() if values[f] == p or p in html]
    if args.check:
        if left:
            print("Placeholders left: " + ", ".join(sorted(set(left))))
            sys.exit(1)
        print("The privacy policy is filled.")
        return
    with open(TRES, "w", encoding="utf-8") as f:
        f.write(tres)
    with open(HTML, "w", encoding="utf-8") as f:
        f.write(html)
    print("Filled. Left: " + (", ".join(sorted(set(left))) if left else "none"))


if __name__ == "__main__":
    main()
