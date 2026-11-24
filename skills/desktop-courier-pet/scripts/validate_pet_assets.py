#!/usr/bin/env python3
"""Validate Taro PNG/manifest assets without modifying them. Requires Pillow."""
import argparse
import json
from pathlib import Path
import re
import sys


def validate(root, strips):
    try:
        from PIL import Image
    except ImportError:
        return {"passed": False, "errors": ["Pillow is required; use an environment with Pillow installed."]}
    errors, checked = [], []
    try:
        catalog = json.loads((root / "Skins/skins.json").read_text())
        if not isinstance(catalog, list):
            raise ValueError("manifest must be a list")
    except (OSError, ValueError) as exc:
        return {"passed": False, "errors": [str(exc)]}
    ids = {"original"}
    images = [("original", root / "mantle.png")]
    for number, skin in enumerate(catalog):
        if not isinstance(skin, dict):
            errors.append(f"entry {number}: expected object")
            continue
        sid = skin.get("id")
        if not isinstance(sid, str) or not re.fullmatch(r"[a-z][a-z0-9-]*", sid):
            errors.append(f"entry {number}: invalid id")
            continue
        if sid in ids:
            errors.append(f"{sid}: duplicate/reserved id")
            continue
        ids.add(sid)
        for key in ("name", "note"):
            if not isinstance(skin.get(key), str) or not skin[key].strip():
                errors.append(f"{sid}: missing {key}")
        for key in ("body", "light", "dark", "suckers", "ink", "accent", "card", "blush"):
            if not isinstance(skin.get(key), str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", skin[key]):
                errors.append(f"{sid}: invalid {key} color")
        images.append((sid, root / "Skins" / f"{sid}.png"))
    for sid in strips:
        if sid not in ids:
            errors.append(f"strip {sid}: unknown id")
    for sid, path in images:
        try:
            with Image.open(path) as image:
                image.load()
                if image.format != "PNG":
                    raise ValueError("expected PNG")
                if "A" not in image.getbands() and "transparency" not in image.info:
                    raise ValueError("missing alpha channel")
                alpha = image.convert("RGBA").getchannel("A")
                low, high = alpha.getextrema()
                if low == 255 or high == 0:
                    raise ValueError("expected visible subject and transparent background")
                item = {"id": sid, "size": list(image.size), "alpha": [low, high]}
                if sid in strips:
                    count = strips[sid]
                    if image.width < count:
                        raise ValueError("strip narrower than cell count")
                    boxes = []
                    for i in range(count):
                        left, right = image.width * i // count, image.width * (i + 1) // count
                        box = alpha.crop((left, 0, right, image.height)).point(lambda x: 255 if x > 24 else 0).getbbox()
                        if box is None or box[2] - box[0] < 8 or box[3] - box[1] < 8:
                            raise ValueError(f"cell {i + 1} empty or too small")
                        if box[0] == 0 or box[2] == right - left or box[1] == 0 or box[3] == image.height:
                            raise ValueError(f"cell {i + 1} touches crop edge; inspect separation")
                        boxes.append([left + box[0], box[1], box[2] - box[0], box[3] - box[1]])
                    item["cellBounds"] = boxes
                checked.append(item)
        except (OSError, ValueError) as exc:
            errors.append(f"{sid}: {exc}")
    return {"passed": not errors, "checked": checked, "errors": errors,
            "limits": "Validates files, alpha and cell geometry; semantic character count and appearance require visual inspection."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("assets", type=Path, help="Directory containing mantle.png and Skins/skins.json")
    parser.add_argument("--strip", action="append", default=[], metavar="ID:COUNT", help="Check an equal-column sprite strip")
    args = parser.parse_args()
    strips = {}
    for value in args.strip:
        try:
            sid, raw_count = value.rsplit(":", 1)
            count = int(raw_count)
            if not re.fullmatch(r"[a-z][a-z0-9-]*", sid) or count < 1 or count > 64:
                raise ValueError()
            strips[sid] = count
        except ValueError:
            parser.error("--strip must be a valid ID followed by :COUNT, with count from 1 to 64")
    result = validate(args.assets, strips)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
