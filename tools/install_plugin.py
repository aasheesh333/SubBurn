#!/usr/bin/env python3
"""
Install + run the SubBurn Builder plugin in Figma web, then verify the result.

Figma's web editor only exposes "Import plugin from manifest…" through the
Plugins > Development submenu, and the manifest picker is a native file dialog.
Playwright can drive both, which the generic browser MCP cannot.

    python3 tools/install_plugin.py
"""
import json
import pathlib
import sys

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "figma-plugin" / "manifest.json"
FILE_URL = "https://www.figma.com/design/9S9W6uNjFxuP2CIj47uy39/SubBurn"
CDP = "http://127.0.0.1:9333"


def dump_menu(page):
    """Return visible menu items so we can find the Development submenu."""
    return page.evaluate(
        """() => [...document.querySelectorAll('[role="menuitem"], [role="menuitemcheckbox"]')]
                 .map(e => (e.textContent || '').trim())
                 .filter(Boolean)"""
    )


def main():
    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp(CDP)
        ctx = browser.contexts[0]
        page = ctx.pages[0] if ctx.pages else ctx.new_page()

        page.goto(FILE_URL, wait_until="domcontentloaded", timeout=90000)
        # Figma's editor boot is slow under SwiftShader
        page.wait_for_selector('[role="button"][aria-label="Main menu"]', timeout=90000)
        page.wait_for_timeout(4000)
        print("editor ready:", page.title())

        # --- open main menu ---
        page.click('[aria-label="Main menu"]')
        page.wait_for_timeout(600)
        items = dump_menu(page)
        print("top-level:", items)

        # --- hover Plugins ---
        page.get_by_role("menuitem", name="Plugins", exact=True).hover()
        page.wait_for_timeout(900)
        sub = dump_menu(page)
        print("plugins submenu:", sub)

        # --- look for Development ---
        dev = None
        for cand in ("Development", "Development plugins"):
            loc = page.get_by_role("menuitem", name=cand, exact=False)
            if loc.count():
                dev = loc.first
                break

        if dev is None:
            print("\nNo 'Development' submenu in the web editor.")
            print("Full menu text:")
            print("\n".join(sub))
            browser.close()
            return 2

        dev.hover()
        page.wait_for_timeout(800)
        devitems = dump_menu(page)
        print("development submenu:", devitems)

        imp = page.get_by_text("Import plugin from manifest", exact=False)
        if not imp.count():
            print("Import item not found")
            browser.close()
            return 3

        with page.expect_file_chooser(timeout=15000) as fc:
            imp.first.click()
        chooser = fc.value
        chooser.set_files(str(MANIFEST))
        print("manifest uploaded:", MANIFEST)
        page.wait_for_timeout(2500)

        # --- run it ---
        page.click('[aria-label="Main menu"]')
        page.wait_for_timeout(500)
        page.get_by_role("menuitem", name="Plugins", exact=True).hover()
        page.wait_for_timeout(700)
        page.get_by_role("menuitem", name="Development", exact=False).first.hover()
        page.wait_for_timeout(700)
        run = page.get_by_text("SubBurn Builder", exact=False)
        print("plugin entry count:", run.count())
        if run.count():
            run.first.click()
            print("launched plugin")

        page.wait_for_timeout(25000)  # build + style creation takes a while
        shot = ROOT / "renders" / "figma-after-plugin.png"
        shot.parent.mkdir(parents=True, exist_ok=True)
        page.screenshot(path=str(shot))
        print("screenshot:", shot)

        browser.close()
        return 0


if __name__ == "__main__":
    sys.exit(main())
