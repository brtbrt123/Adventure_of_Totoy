"""Author approved trial art and editable presentation scenes; never writes core/data/tools."""
from pathlib import Path
from PIL import Image
import hashlib
import json
import math

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
PREFIX = 'hollow_trial_'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def literal(value):
    return json.dumps(value,separators=(', ', ': '))


def grid(name, im, anchor, colours):
    rows = [''.join('.' if im.getpixel((x,y))[3]==0 else colours[im.getpixel((x,y))[:3]] for x in range(im.width)) for y in range(im.height)]
    (ROOT/'art/src'/(name+'.txt')).write_text(f'# kind: sprite\n# anchor: {anchor[0]},{anchor[1]}\n'+'\n'.join(rows)+'\n')


def main():
    approved = json.loads((HERE/'APPROVAL.json').read_text())
    assert sha(HERE/approved['native_asset'])==approved['sha256']
    prior_path = HERE/'scene_registration.json'
    prior_record = json.loads(prior_path.read_text()) if prior_path.exists() else {}
    authored_map = ROOT/'presentation/maps/hollow_trial_layered.tscn'
    if authored_map.exists():
        assert prior_record.get('generated_scene_sha256')==sha(authored_map),'Preserve external map edits; do not regenerate'
    for path in (ROOT/'presentation/props').glob('hollow_trial_*.tscn'):
        assert prior_record.get('prop_scene_sha256',{}).get(path.stem)==sha(path),'Preserve external prop-scene edits: '+path.name
    destination = ROOT/'presentation/forest/hollow_trial_layered_ground.png'
    if destination.exists():
        assert sha(destination)==approved['sha256'],'Preserve changes to installed ground'
    props = json.loads((HERE/'prop_review/manifest.json').read_text())['props']
    # The bottom tree feet are fixed at y336. Smaller derived copies keep their canopies below the y276 fight floor.
    variants = HERE/'scene_variants'
    variants.mkdir(exist_ok=True)
    for i in (1,2):
        name = f'tree_{i}_small'
        original = props[f'tree_{i}']
        image = Image.open(HERE/'prop_review/native'/f'tree_{i}.png').convert('RGBA')
        image = image.resize((round(image.width*.45),round(image.height*.45)),Image.Resampling.NEAREST)
        width,height = math.ceil(image.width/8)*8,math.ceil(image.height/8)*8
        canvas = Image.new('RGBA',(width,height))
        canvas.alpha_composite(image,((width-image.width)//2,height-image.height))
        canvas.save(variants/(name+'.png'))
        props[name] = {'anchor':[width//2,height],'suggested_base_size':[round(v*.45) for v in original['suggested_base_size']]}
    layout = json.loads((ROOT/'docs/previews/hollow_trial_v1/layout.json').read_text())
    palette = json.loads((ROOT/'art/palette.json').read_text())
    colours = {tuple(bytes.fromhex(c['hex'][1:])):c['symbol'] for c in palette['colors']}
    sockets = {}
    definitions = {}
    approvals = {}
    for short, record in props.items():
        name = PREFIX+short
        source = (variants if short.endswith('_small') else HERE/'prop_review/native')/(short+'.png')
        im = Image.open(source).convert('RGBA')
        w,h = im.size
        ax,ay = record['anchor']
        grid(name,im,(ax,ay),colours)
        bw,bh = record['suggested_base_size']
        solid = bw>0
        circles = []
        if solid:
            radius = min(bh*.5,bw*.5)
            count = max(1,math.ceil((bw-2*radius)/max(1,radius))+1)
            for i in range(count):
                x = 0 if count==1 else -(bw*.5-radius)+(bw-2*radius)*i/(count-1)
                circles.append([round(x,3),-bh*.5,radius])
        definitions[name] = {'w':w,'h':h,'anchor':[ax,ay],'base_width':bw,'solid':solid,'image':name+'.png','colliders':circles,'locked':True}
        approvals[name] = {'source':source.relative_to(ROOT).as_posix(),'sha256':sha(source),'anchor':[ax,ay],'size':[w,h]}
        body = ['[gd_scene load_steps=%d format=3]' % (2+len(circles)),
                f'[ext_resource type="Texture2D" path="res://art/build/sprites/{name}.png" id="art"]']
        for i,circle in enumerate(circles):
            body += [f'[sub_resource type="CircleShape2D" id="C{i}"]',f'radius = {circle[2]}']
        body += [f'[node name="{name}" type="Node2D"]',f'metadata/w = {w}',f'metadata/h = {h}',f'metadata/base_width = {bw}',
                 f'metadata/solid = {str(solid).lower()}',f'metadata/image = "{name}.png"',f'metadata/anchor = Vector2({ax}, {ay})',
                 'metadata/locked = true','metadata/registration_pending = true',
                 '[node name="Sprite" type="Sprite2D" parent="."]','texture_filter = 1','texture = ExtResource("art")','centered = false',f'offset = Vector2({-ax}, {-ay})',
                 '[node name="Colliders" type="StaticBody2D" parent="."]','collision_layer = 0','collision_mask = 0']
        for i,(x,y,radius) in enumerate(circles):
            body += [f'[node name="Circle{i+1}" type="CollisionShape2D" parent="Colliders"]',f'position = Vector2({x}, {y})',f'shape = SubResource("C{i}")']
        if short.startswith('rune_rock_') or short=='altar_lit':
            teal = [(x,y) for y in range(h) for x in range(w) if im.getpixel((x,y))[3] and colours[im.getpixel((x,y))[:3]] in 'uop']
            cx,cy = (round(sum(x for x,y in teal)/len(teal)),round(sum(y for x,y in teal)/len(teal))) if teal else (ax,ay-h//2)
            socket = {'pixel':[cx,cy],'halo_radius':32.0,'energy':1.1,'pool_radius':48.0,'pool_energy':.62,'colour':[.48,.94,.86],'core_colour':[.8,1.,1.]}
            sockets[name] = [socket]
            body += ['[node name="Light1" type="Marker2D" parent="."]',f'position = Vector2({cx-ax}, {cy-ay})',f'metadata/socket = {literal(socket)}']
        (ROOT/'presentation/props'/(name+'.tscn')).write_text('\n\n'.join(body)+'\n')
    ground_dest = ROOT/'presentation/forest/hollow_trial_layered_ground.png'
    ground_dest.write_bytes((HERE/approved['native_asset']).read_bytes())
    placements = [dict(id='trial_altar',type=PREFIX+'altar_dark',x=256,y=180,flip=False,when='flag:cleared_hollow_trial',on_type=PREFIX+'altar_lit'),
                  dict(id='trial_chest',type=PREFIX+'chest_closed',x=256,y=136,flip=False,when='flag:trial_chest_opened',on_type=PREFIX+'chest_open'),
                  dict(id='entry_roots',type='root_hollow_barrier_open',x=256,y=350,flip=False,when='trial:sealed',on_type='root_hollow_barrier_closed')]
    for i,(x,y) in enumerate(layout['rim_slots_glowing_rocks']):
        placements.append(dict(id=f'rune_rock_{i+1}',type=PREFIX+f'rune_rock_{i%6+1}',x=x,y=y,flip=x>256))
    for i,(x,y) in enumerate(layout['rim_trees_outside']):
        placements.append(dict(id=f'rim_tree_{i+1}',type=PREFIX+f'tree_{i%2+1}'+('_small' if i>=6 else ''),x=x,y=y,flip=x>256))
    for i,(x,y) in enumerate([(62,196),(120,70),(244,40),(392,70),(452,196)]):
        placements.append(dict(id=f'rim_bush_{i+1}',type=PREFIX+f'bush_{i%4+1}',x=x,y=y,flip=x>256))
    for i,(x,y) in enumerate([(120,312),(392,312),(60,110),(452,110)]):
        placements.append(dict(id=f'rim_fern_{i+1}',type=PREFIX+f'fern_{i%2+1}',x=x,y=y,flip=x>256))
    for i,(x,y) in enumerate([(88,272),(428,272),(160,42),(352,42)]):
        placements.append(dict(id=f'rim_roots_{i+1}',type=PREFIX+f'roots_{i%2+1}',x=x,y=y,flip=x>256))
    resource_types = sorted({p['type'] for p in placements}|{p['on_type'] for p in placements if 'on_type' in p})
    data = json.loads((ROOT/'data/scenes/hollow_trial_layered_props.json').read_text())
    text = [f'[gd_scene load_steps={len(resource_types)+7} format=3]',
            '[ext_resource type="Script" path="res://presentation/maps/hollow_trial_view.gd" id="view"]',
            '[ext_resource type="Texture2D" path="res://presentation/forest/hollow_trial_layered_ground.png" id="ground"]',
            '[ext_resource type="Script" path="res://presentation/maps/hollow_trial_floor.gd" id="floor"]']
    text += ['[ext_resource type="Script" path="res://presentation/maps/hollow_trial_overlay.gd" id="overlay"]']
    for t in resource_types:
        text.append(f'[ext_resource type="PackedScene" path="res://presentation/props/{t}.tscn" id="{t}"]')
    text += ['[sub_resource type="RectangleShape2D" id="ExitRect"]','size = Vector2(56, 7)',
             '[sub_resource type="RectangleShape2D" id="FightRect"]','size = Vector2(288, 184)']
    text += ['[node name="hollow_trial_layered" type="Node2D"]','texture_filter = 1','script = ExtResource("view")',
             'metadata/version = 1','metadata/title = "THE HOLLOW TRIAL"','metadata/size = [512, 352]','metadata/boundary_radius = 25','metadata/boundary_spacing = 17',
             'metadata/default_entry = "south"','metadata/prop_margin = 40',f'metadata/trial = {literal(data["trial"])}','metadata/registration_pending = true',
             '[node name="Ground" type="Sprite2D" parent="."]','texture_filter = 1','texture = ExtResource("ground")','centered = false',
             '[node name="FloorEffects" type="Node2D" parent="."]','script = ExtResource("floor")',
             '[node name="Props" type="Node2D" parent="."]','y_sort_enabled = true']
    for p in placements:
        text += [f'[node name="{p["id"]}" parent="Props" instance=ExtResource("{p["type"]}")]',f'position = Vector2({p["x"]}, {p["y"]})',
                 f'metadata/flip = {str(p["flip"]).lower()}']
        if 'when' in p:
            text += [f'metadata/when = "{p["when"]}"',f'metadata/on_type = "{p["on_type"]}"']
    outline = ', '.join(str(v) for pt in layout['outline'] for v in pt)
    text += ['[node name="Overlay" type="Node2D" parent="."]','script = ExtResource("overlay")',
             '[node name="Walkable" type="Polygon2D" parent="."]','visible = false',f'polygon = PackedVector2Array({outline})',
             '[node name="Entries" type="Node2D" parent="."]','[node name="south" type="Marker2D" parent="Entries"]','position = Vector2(256, 328)',
             '[node name="Checkpoints" type="Node2D" parent="."]','[node name="hollow_trial_layered_entry" type="Marker2D" parent="Checkpoints"]','position = Vector2(256, 312)',
             '[node name="Exits" type="Node2D" parent="."]','[node name="to_hollow" type="Area2D" parent="Exits"]','position = Vector2(228, 345)','collision_layer = 0','collision_mask = 0','metadata/target_scene = "root_hollow_layered"','metadata/target_entry = "shortcut"',
             '[node name="Rect" type="CollisionShape2D" parent="Exits/to_hollow"]','position = Vector2(28, 3.5)','shape = SubResource("ExitRect")',
             '[node name="Npcs" type="Node2D" parent="."]','[node name="Objects" type="Node2D" parent="."]','[node name="altar" type="Marker2D" parent="Objects"]','position = Vector2(256, 180)','metadata/kind = "altar"',
             '[node name="Stand" type="Marker2D" parent="Objects/altar"]','position = Vector2(0, 24)',
             '[node name="trial_chest" type="Marker2D" parent="Objects"]','position = Vector2(256, 136)','metadata/kind = "chest"',
             '[node name="Stand" type="Marker2D" parent="Objects/trial_chest"]','position = Vector2(0, 18)',
             '[node name="Encounters" type="Node2D" parent="."]','[node name="hollow_trial" type="Node2D" parent="Encounters"]','metadata/title = "THE HOLLOW TRIAL"','metadata/leash = 999','metadata/managed = true',
             '[node name="Zone" type="Area2D" parent="Encounters/hollow_trial"]','collision_layer = 0','collision_mask = 0','[node name="Rect" type="CollisionShape2D" parent="Encounters/hollow_trial/Zone"]','position = Vector2(256, 184)','shape = SubResource("FightRect")',
             '[node name="SpawnPoints" type="Node2D" parent="."]']
    for i,(x,y) in enumerate(layout['spawn_points']):
        text += [f'[node name="Spawn{i+1}" type="Marker2D" parent="SpawnPoints"]',f'position = Vector2({x}, {y})']
    text += ['[node name="AuthoringCamera" type="Camera2D" parent="."]','position = Vector2(256, 176)']
    scene_path = ROOT/'presentation/maps/hollow_trial_layered.tscn'
    prior = HERE/'scene_registration.json'
    if scene_path.exists():
        assert prior.exists() and json.loads(prior.read_text()).get('generated_scene_sha256')==sha(scene_path),'Scene has external edits; preserve them instead of regenerating'
    scene_path.write_text('\n\n'.join(text)+'\n')
    prop_scene_hashes = {name:sha(ROOT/'presentation/props'/(name+'.tscn')) for name in definitions}
    (HERE/'scene_registration.json').write_text(json.dumps({'status':'CLAUDE REGISTRATION REQUIRED; do not treat suggested colliders as live core data','generated_scene_sha256':sha(scene_path),'prop_scene_sha256':prop_scene_hashes,'props':definitions,'placements':placements,'light_sockets':sockets,'approved_art':approvals},indent=2)+'\n')
    (HERE/'PROPS_APPROVAL.json').write_text(json.dumps({'approved':'2026-10-31','timezone':'Asia/Singapore','owner_message':'yes thats good start making the scene',
        'scope':'20 original prop designs; small tree copies are layout-derived implementation variants for owner scene review',
        'props':{k:v for k,v in approvals.items() if not k.endswith('_small')},
        'derived_variants':{k:dict(v,method='nearest-neighbour45% copy of approved tree to keep canopy outside fight floor') for k,v in approvals.items() if k.endswith('_small')}},indent=2)+'\n')
    print('Prepared20 approved props +2 downsized tree copies,32 placements,ground and registration handoff; no core/data writes')


if __name__=='__main__':
    main()
