"""Verify imported pixels in feet coordinates, independent of packing/trim dimensions."""
from pathlib import Path
import hashlib
import json
import unittest
import wave
from array import array
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def pixels(im, anchor):
    return {(x-anchor[0], y-anchor[1]): im.getpixel((x,y))
            for y in range(im.height) for x in range(im.width) if im.getpixel((x,y))[3]}


class WardenArtTests(unittest.TestCase):
    def test_body_and_attached_fx_atlas_preserve_reference_pixels_and_feet(self):
        atlas = Image.open(ROOT/'art/build/sprites.png').convert('RGBA')
        frames = json.loads((ROOT/'art/build/sprites.json').read_text())['frames']
        v4 = ROOT/'art/reference/warden_cleave_range_v4'
        manifest = json.loads((v4/'manifest.json').read_text())
        count = 0
        for key, f in frames.items():
            if key.startswith('warden_'):
                state = key[len('warden_'):].split('_right_')[0]
                im = Image.open(v4/'body'/state/(key+'.png')).convert('RGBA').resize((120,120),Image.Resampling.NEAREST)
                anchor = (50,110)
            elif key.startswith('fx_warden_'):
                family = key[len('fx_warden_'):].rsplit('_',1)[0]
                im = Image.open(v4/'fx'/family/(key+'.png')).convert('RGBA')
                anchor = manifest['fx_assets'][key]['anchor']
            else:
                continue
            actual = atlas.crop((f['x'],f['y'],f['x']+f['w'],f['y']+f['h']))
            self.assertEqual(pixels(actual,(f['ax'],f['ay'])),pixels(im,anchor),key)
            count += 1
        self.assertEqual(count,135)
        self.assertLessEqual(atlas.height,8192)

    def test_recorded_audio_hashes_and_pcm_peaks(self):
        audio = ROOT/'presentation/audio'
        entries = json.loads((audio/'sources.json').read_text())['warden_recorded_remixes']
        self.assertEqual(len(entries),13)
        for entry in entries:
            path = audio/entry['file']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),entry['sha256'])
            with wave.open(str(path),'rb') as w:
                self.assertEqual((w.getnchannels(),w.getsampwidth(),w.getframerate()),(1,2,44100))
                samples = array('h',w.readframes(w.getnframes()))
            self.assertLessEqual(max(abs(x) for x in samples),21300)
            self.assertGreater(len(samples),1000)
            self.assertEqual(samples[0],0)


if __name__=='__main__':
    unittest.main()
