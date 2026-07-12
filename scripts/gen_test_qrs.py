#!/usr/bin/env python3
"""
Generate QR PNG images for all GreenRoot QR scan test scenarios.

Usage:
    python3 gen_test_qrs.py               # reads test_qr_values.env in same dir
    python3 gen_test_qrs.py --env path    # custom env file

Requires: pip install qrcode[pil] pillow
"""

import argparse
import os
import sys
import textwrap

try:
    import qrcode
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Missing dependencies. Run: pip install 'qrcode[pil]' pillow")
    sys.exit(1)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(SCRIPT_DIR, "test_qrs")


# ── Load env file ─────────────────────────────────────────────────────────────

def load_env(path: str) -> dict:
    values = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, _, v = line.partition("=")
                values[k.strip()] = v.strip()
    return values


# ── Scenario definitions ──────────────────────────────────────────────────────
# Each tuple: (filename, label, content_key_or_literal, expected_outcome)

def build_scenarios(env: dict) -> list:
    return [
        (
            "01_valid_manager_invite",
            "Valid Manager Invite (PENDING)",
            env.get("VALID_MANAGER_INVITE_UUID", ""),
            "✅ Invite sheet → Accept button visible → manager role granted",
        ),
        (
            "02_valid_customer_invite",
            "Valid Customer Invite (PENDING)",
            env.get("VALID_CUSTOMER_INVITE_UUID", ""),
            "✅ Invite sheet → Accept button visible → customer role linked",
        ),
        (
            "03_accepted_invite",
            "Already-Used Invite",
            env.get("ACCEPTED_INVITE_UUID", ""),
            "❌ Warning banner: 'already used or expired' — no Accept button",
        ),
        (
            "04_nonexistent_invite",
            "Non-existent UUID",
            env.get("NONEXISTENT_UUID", "00000000-0000-0000-0000-000000000000"),
            "❌ Error card: 'may have expired or already been used'",
        ),
        (
            "05_valid_trip_code",
            "Valid Trip Code (PENDING, no driver)",
            env.get("VALID_DISPATCH_CODE", ""),
            "✅ Driver: TripPreviewScreen → Accept → ACCEPTED\n"
            "❌ Owner/Manager: 'Only drivers can join trips'",
        ),
        (
            "06_already_accepted_trip",
            "Already-Accepted Trip Code",
            env.get("ALREADY_ACCEPTED_CODE", ""),
            "❌ Driver: TripPreviewScreen → error 'already assigned to another driver'",
        ),
        (
            "07_nonexistent_trip",
            "Non-existent Dispatch Code",
            env.get("NONEXISTENT_CODE", "DSP-00000000-9999"),
            "❌ TripPreviewScreen → 404 error 'Trip not found'",
        ),
        (
            "08_valid_verify_token",
            "Valid Quotation Verify Token (hex)",
            env.get("VALID_VERIFY_TOKEN", ""),
            "✅ Verify sheet: VERIFIED + quotation code + status + dates",
        ),
        (
            "09_invalid_verify_token",
            "Invalid Verify Token (random hex)",
            env.get("INVALID_VERIFY_TOKEN", "deadbeef" * 8),
            "❌ Verify sheet: 'Invalid QR Code' / not recognised",
        ),
        (
            "10_verify_token_alt",
            "Verify Token (alternate, same as 08)",
            env.get("VERIFY_URL", ""),
            "✅ Same as 08 — confirms 64-hex token recognised from QR",
        ),
        (
            "11_foreign_qr",
            "Foreign / Non-GreenRoot QR",
            env.get("FOREIGN_QR", "https://amazon.com/product/12345"),
            "❌ 'Not a GreenRoot QR' screen with type info",
        ),
        (
            "12_wrong_target_invite",
            "Wrong-Target Invite",
            env.get("WRONG_TARGET_INVITE_UUID", ""),
            "❌ Buyer scans invite for 9800000099 → 'This invite was sent to someone else'",
        ),
    ]


# ── QR image generation ───────────────────────────────────────────────────────

LABEL_HEIGHT = 90
CARD_PAD = 16
QR_SIZE = 300


def make_qr_image(content: str) -> Image.Image:
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=8,
        border=4,
    )
    qr.add_data(content)
    qr.make(fit=True)
    return qr.make_image(fill_color="black", back_color="white").resize(
        (QR_SIZE, QR_SIZE), Image.LANCZOS
    )


def make_card(label: str, content: str, expected: str) -> Image.Image:
    qr_img = make_qr_image(content)
    card_w = QR_SIZE + CARD_PAD * 2
    card_h = QR_SIZE + LABEL_HEIGHT + CARD_PAD * 2

    card = Image.new("RGB", (card_w, card_h), color=(255, 255, 255))
    card.paste(qr_img, (CARD_PAD, CARD_PAD))

    draw = ImageDraw.Draw(card)
    try:
        font_label = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)
        font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 11)
    except Exception:
        font_label = ImageFont.load_default()
        font_small = font_label

    y = QR_SIZE + CARD_PAD + 6
    # Scenario label
    wrapped = textwrap.fill(label, width=42)
    draw.text((CARD_PAD, y), wrapped, fill=(15, 23, 42), font=font_label)
    y += 28
    # Expected outcome (truncated)
    short_expected = expected.split("\n")[0][:70]
    draw.text((CARD_PAD, y), short_expected, fill=(100, 116, 139), font=font_small)
    y += 16
    # Content preview
    preview = content[:50] + "…" if len(content) > 50 else content
    draw.text((CARD_PAD, y), preview, fill=(148, 163, 184), font=font_small)

    return card


# ── HTML index ────────────────────────────────────────────────────────────────

def write_html(scenarios: list, out_dir: str) -> None:
    rows = ""
    for filename, label, content, expected in scenarios:
        png = f"{filename}.png"
        expected_html = expected.replace("\n", "<br>")
        rows += f"""
        <div class="card">
          <img src="{png}" alt="{label}">
          <div class="info">
            <strong>{label}</strong><br>
            <code class="content">{content[:60]}{'…' if len(content) > 60 else ''}</code><br>
            <span class="expected">{expected_html}</span>
          </div>
        </div>
        """

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>GreenRoot QR Test Gallery</title>
<style>
  body {{ font-family: -apple-system, sans-serif; background: #f8fafc; padding: 24px; }}
  h1 {{ color: #0f172a; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); gap: 20px; margin-top: 24px; }}
  .card {{ background: white; border-radius: 12px; box-shadow: 0 1px 4px rgba(0,0,0,.1); padding: 16px; }}
  .card img {{ width: 100%; border-radius: 8px; border: 1px solid #e2e8f0; }}
  .info {{ margin-top: 12px; }}
  .info strong {{ color: #0f172a; font-size: 14px; }}
  .content {{ display: block; font-size: 11px; color: #64748b; word-break: break-all; margin: 4px 0; }}
  .expected {{ font-size: 12px; color: #475569; }}
</style>
</head>
<body>
<h1>GreenRoot QR Scan — Test Gallery</h1>
<p>Open on a Mac browser, scan each code with the phone camera or use "Choose from Gallery" in the app.</p>
<div class="grid">{rows}</div>
</body>
</html>
"""
    with open(os.path.join(out_dir, "index.html"), "w") as f:
        f.write(html)
    print(f"  ✓ index.html")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--env", default=os.path.join(SCRIPT_DIR, "test_qr_values.env"))
    args = parser.parse_args()

    if not os.path.exists(args.env):
        print(f"Env file not found: {args.env}")
        print("Run scripts/setup_qr_test_data.sh first.")
        sys.exit(1)

    env = load_env(args.env)
    os.makedirs(OUT_DIR, exist_ok=True)
    scenarios = build_scenarios(env)

    # Skip scenarios where content is empty (API not running / data missing)
    missing = [(f, l) for f, l, c, _ in scenarios if not c]
    if missing:
        print("WARNING: some scenarios have no content (API data missing):")
        for f, l in missing:
            print(f"  - {l}")

    print(f"\nGenerating {len(scenarios)} QR images → {OUT_DIR}/")
    for filename, label, content, expected in scenarios:
        if not content:
            print(f"  SKIP  {filename}.png  (no content)")
            continue
        card = make_card(label, content, expected)
        out_path = os.path.join(OUT_DIR, f"{filename}.png")
        card.save(out_path)
        print(f"  ✓ {filename}.png")

    write_html(scenarios, OUT_DIR)
    print(f"\nDone. Open: {OUT_DIR}/index.html")


if __name__ == "__main__":
    main()
