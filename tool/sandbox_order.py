#!/usr/bin/env python3
"""Create a test order on the N-Genius sandbox and write it to order.json.

Credentials come from the environment only (never from files):

    NGENIUS_API_KEY     the outlet's API key from the N-Genius portal (used as-is in
                        "Authorization: Basic <key>")
    NGENIUS_OUTLET_REF  the outlet reference (UUID)

Usage:
    python tool/sandbox_order.py --action SALE --amount 1250 --currency AED --language en \
        --email buyer@example.com --output order.json

Paste the resulting JSON into the example app, or push it to a device and start the app with
`--dart-define=ORDER_JSON_FILE=<path>`. Standard library only.
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

SANDBOX = "https://api-gateway.sandbox.ngenius-payments.com"
IDENTITY_URL = SANDBOX + "/identity/auth/access-token"
ORDERS_URL = SANDBOX + "/transactions/outlets/{outlet}/orders"


def post_json(url, headers, body):
    data = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise SystemExit("HTTP %s from %s\n%s" % (error.code, url, detail))


def access_token(api_key):
    response = post_json(
        IDENTITY_URL,
        {
            "Authorization": "Basic " + api_key,
            "Content-Type": "application/vnd.ni-identity.v1+json",
            "Accept": "application/vnd.ni-identity.v1+json",
        },
        {"realmName": "ni"},
    )
    token = response.get("access_token")
    if not token:
        raise SystemExit("No access_token in the identity response: %s" % json.dumps(response))
    return token


def create_order(token, outlet, action, amount, currency, language, email):
    return post_json(
        ORDERS_URL.format(outlet=outlet),
        {
            "Authorization": "Bearer " + token,
            "Content-Type": "application/vnd.ni-payment.v2+json",
            "Accept": "application/vnd.ni-payment.v2+json",
        },
        {
            "action": action,
            "amount": {"currencyCode": currency, "value": amount},
            "language": language,
            "emailAddress": email,
            "merchantAttributes": {"skipConfirmationPage": True},
        },
    )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--action", default="SALE", choices=["AUTH", "SALE", "PURCHASE"])
    parser.add_argument("--amount", type=int, default=1250, help="amount in minor units (1250 = 12.50 AED)")
    parser.add_argument("--currency", default="AED")
    parser.add_argument("--language", default="en")
    parser.add_argument("--email", default="buyer@example.com", help="emailAddress sent with the order")
    parser.add_argument("--output", default="order.json")
    args = parser.parse_args(argv)

    api_key = os.environ.get("NGENIUS_API_KEY")
    outlet = os.environ.get("NGENIUS_OUTLET_REF")
    if not api_key or not outlet:
        print("Set NGENIUS_API_KEY and NGENIUS_OUTLET_REF in the environment first.", file=sys.stderr)
        return 2

    order = create_order(access_token(api_key), outlet, args.action, args.amount, args.currency, args.language, args.email)
    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(order, handle, indent=2)
    print("Order %s written to %s" % (order.get("reference", "?"), args.output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
