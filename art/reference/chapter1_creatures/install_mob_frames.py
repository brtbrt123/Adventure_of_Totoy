"""Import existing creature reference pixels unchanged into the text-grid pipeline."""
from pathlib import Path
import json,sys,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/art'))
import artlib
PALETTE=artlib.load_palette(); SYMBOLS={rgb:s for s,rgb in PALETTE.by_symbol.items()}
def main():
    manifest={}
    for mob,base,prefix in [('mossling','creature_mossling_v1','creature_mossling'),('boar','creature_thornback_boar_v1','creature_thornback_boar')]:
        path=Path(__file__).parent/(base+'.png');image=Image.open(path).convert('RGBA');meta=json.loads(path.with_suffix('.json').read_text())
        for name,frame in meta['frames'].items():
            state_n=name.removeprefix(prefix+'_');state,n=state_n.rsplit('_',1);key=mob+'_'+state+'_right_'+n
            cut=image.crop((frame['x'],frame['y'],frame['x']+frame['w'],frame['y']+frame['h']))
            rows=[]
            for y in range(cut.height):
                row=''
                for x in range(cut.width):
                    r,g,b,a=cut.getpixel((x,y));assert a in (0,255)
                    if a: assert SYMBOLS[(r,g,b)] not in PALETTE.reserved
                    row+=SYMBOLS[(r,g,b)] if a else '.'
                rows.append(row)
            (ROOT/'art/src'/(key+'.txt')).write_text('# kind: sprite\n# anchor: %d,%d\n# Unchanged native pixels from approved/reference creature atlas; owner motion review pending.\n'%(frame['ax'],frame['ay'])+'\n'.join(rows)+'\n')
        manifest[mob]={'source':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'frames':len(meta['frames']),'states':meta['states']}
    (Path(__file__).parent/'runtime_import.json').write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':main()
