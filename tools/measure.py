#!/usr/bin/env python3
"""Measure the real geometry of each frame so layout fixes are evidence-based.

    python3 tools/measure.py
"""
import json
import pathlib

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = (ROOT / "index.html").as_uri()

PROBE = """() => {
  const out = [];
  document.querySelectorAll('.screen').forEach(s => {
    if (s.closest('.backdrop')) return;
    const r = el => el ? Math.round(el.getBoundingClientRect().height) : null;
    const top = el => el ? Math.round(el.getBoundingClientRect().top) : null;
    const pad = s.querySelector('.pad');
    const stage = s.querySelector('.stage');
    const wrap = s.querySelector('.receipt-wrap');
    const card = s.querySelector('#receipt-card');
    const dock = s.querySelector('.bottom-dock');
    out.push({
      id: s.id,
      screen: r(s),
      pad: r(pad),
      padScroll: pad ? pad.scrollHeight : null,
      stage: r(stage),
      stageTop: top(stage),
      receipt: r(wrap),
      receiptCard: card ? Math.round(card.getBoundingClientRect().height) : null,
      dock: r(dock),
      lastChild: pad && pad.lastElementChild
        ? {tag: pad.lastElementChild.className, bottom: Math.round(pad.lastElementChild.getBoundingClientRect().bottom)}
        : null
    });
  });
  return out;
}"""


def main():
    with sync_playwright() as p:
        b = p.chromium.launch(channel="chrome", args=["--no-sandbox"])
        page = b.new_page(viewport={"width": 1800, "height": 1100}, device_scale_factor=1)
        page.goto(URL)
        page.wait_for_load_state("networkidle")
        page.evaluate("document.fonts.ready")
        page.wait_for_timeout(200)
        for row in page.evaluate(PROBE):
            print(json.dumps(row))
        b.close()


if __name__ == "__main__":
    main()
