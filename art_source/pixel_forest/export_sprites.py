"""Slice the original Aseprite sheet without resampling any pixel."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CELLS = {
    'keeper_side': (0, 0, 32, 40), 'keeper_top': (32, 0, 32, 40),
    'shadow': (64, 0, 32, 40), 'shadow_ranged': (96, 0, 32, 40),
    'crate': (128, 0, 32, 40), 'checkpoint_lantern': (160, 0, 32, 64),
    'stone_gate': (192, 0, 48, 64), 'platform': (0, 64, 96, 24),
    'wall': (104, 64, 32, 32), 'pressure_plate': (144, 64, 32, 32),
    'pressure_plate_active': (176, 64, 32, 32), 'spikes': (0, 104, 32, 20),
    'firefly': (40, 104, 16, 16), 'projectile_player': (64, 104, 12, 14),
    'projectile_enemy': (88, 104, 12, 14), 'heart': (112, 104, 16, 16),
    'reticle': (136, 104, 16, 16),
}

def export(sheet_path, destination):
    sheet = Image.open(sheet_path).convert('RGBA')
    destination.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for name, (x, y, w, h) in CELLS.items():
        asset = sheet.crop((x, y, x+w, y+h))
        assert asset.getbbox(), name
        assert not any(asset.getchannel('A').histogram()[1:255]), name
        asset.save(destination / f'{name}.png')
        manifest[name] = {'cell': [x, y, w, h], 'bounds': list(asset.getbbox())}
    (Path(__file__).parent / 'sprites.json').write_text(
        json.dumps(manifest, indent=2) + '\n', encoding='utf-8')

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sheet', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    export(args.sheet, args.destination)
