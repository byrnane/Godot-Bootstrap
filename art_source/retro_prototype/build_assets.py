"""Explicit first creation / export of the retro prototype's editable assets.

Execute with runpy in Blender, then call create_new(), export_existing(), or
extend_zombie_copy(). Merely importing this file never edits the scene.
"""
from pathlib import Path
import math
import random
import struct
import json

import bpy
from mathutils import Vector, Euler, Matrix

SOURCE = Path(__file__).resolve().parent
PROJECT = SOURCE.parents[1]
BLEND = SOURCE / "Retro_Prototype.blend"
EXPORT = PROJECT / "assets/models/retro_prototype"
TEXTURES = SOURCE / "textures"
ZOMBIE_ORIGINAL = SOURCE / "zombie/Zombie_Rigged.original.blend"
ZOMBIE_WORK = SOURCE / "zombie/Zombie_Rigged.prototype.blend"
ASSETS = ("player", "arms", "pistol", "medkit", "ammo", "crate", "locker",
          "pipe", "wall", "floor", "doorframe")
FPS = 24


def _activate(obj):
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _collection(name):
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    col['retro_asset'] = name
    return col


def _mesh(col, name, verts, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    mesh.materials.append(mat)
    # Box/cylindrical islands intentionally share the tile: no bake dependency.
    uv = mesh.uv_layers.new(name='UVMap')
    for poly in mesh.polygons:
        normal = poly.normal
        axis = max(range(3), key=lambda a: abs(normal[a]))
        axes = [a for a in range(3) if a != axis]
        points = [mesh.vertices[mesh.loops[i].vertex_index].co for i in poly.loop_indices]
        lo = [min(v[a] for v in points) for a in axes]
        size = [max(v[a] for v in points) - lo[k] for k, a in enumerate(axes)]
        for i, v in zip(poly.loop_indices, points):
            uv.data[i].uv = tuple(.02 + .96 * (v[a] - lo[k]) / max(size[k], .0001)
                                 for k, a in enumerate(axes))
    return obj


def _box(col, name, center, size, mat, bevel=0):
    x, y, z = (s / 2 for s in size)
    cx, cy, cz = center
    verts = [(cx+a*x, cy+b*y, cz+c*z) for a,b,c in
             [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
              (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    obj = _mesh(col, name, verts,
                [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)], mat)
    if bevel:
        modifier = obj.modifiers.new('Small worn corners', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 1
        modifier.affect = 'EDGES'
    return obj


def _limb(col, name, a, b, radii, mat, sides=6):
    a, b = Vector(a), Vector(b)
    direction = (b-a).normalized()
    basis = direction.cross(Vector((0,1,0)))
    if basis.length < .1:
        basis = direction.cross(Vector((1,0,0)))
    basis.normalize()
    other = direction.cross(basis).normalized()
    verts = []
    for p,r in [(a,radii[0]),(b,radii[1])]:
        verts.extend(tuple(p + r * (math.cos(t*math.tau/sides)*basis +
                                   math.sin(t*math.tau/sides)*other)) for t in range(sides))
    faces = [tuple(reversed(range(sides))), tuple(range(sides,2*sides))]
    faces += [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    return _mesh(col,name,verts,faces,mat)


def _material(name, rgb, seed, pattern='wear'):
    randomizer = random.Random(seed)
    size = 128
    image = bpy.data.images.new(name + '_128', width=size, height=size, alpha=True)
    pixels = []
    spots = [(randomizer.randrange(size),randomizer.randrange(size),randomizer.randrange(1,5))
             for _ in range(160)]
    for y in range(size):
        for x in range(size):
            grain = randomizer.choice([-.075,-.035,0,.025,.055])
            stain = -.11 if any(abs(x-sx)+abs(y-sy)<r for sx,sy,r in spots) else 0
            if pattern == 'wood':
                grain += -.13 if x % 31 < 2 else .015*math.sin(x*1.8+y*.04)
            elif pattern == 'tile':
                grain += -.18 if x % 64 < 2 or y % 64 < 2 else 0
            elif pattern == 'cloth':
                grain += -.025 if (x+y)%3 == 0 else 0
            pixels.extend([max(.015,min(.98,c+grain+stain)) for c in rgb] + [1])
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(TEXTURES / (name + '.png'))
    image.file_format = 'PNG'
    image.save()
    image.pack()
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    shader = nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value = .88
    tex = nodes.new('ShaderNodeTexImage')
    tex.image = image
    tex.interpolation = 'Closest'
    mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
    mat.diffuse_color = (*rgb,1)
    return mat


def _rig(col, name, specs):
    data = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name,data)
    col.objects.link(obj)
    _activate(obj)
    bpy.ops.object.mode_set(mode='EDIT')
    for name,head,tail,parent in specs:
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = head,tail
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.show_in_front = True
    return obj


def _bind(obj, rig, bone):
    obj.parent = rig
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
    modifier = obj.modifiers.new('Armature','ARMATURE')
    modifier.object = rig


def _action(owner, name):
    owner.animation_data_create()
    owner.animation_data.action = None
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    slot = action.slots.new(id_type='OBJECT',name=owner.name)
    owner.animation_data.action = action
    owner.animation_data.action_slot = slot
    return action


def _finish_action(owner, action, end):
    action.use_frame_range = True
    action.frame_start = 1
    action.frame_end = end
    track = owner.animation_data.nla_tracks.new()
    track.name = action.name.split('|')[-1]
    strip = track.strips.new(action.name,1,action)
    strip.action_slot = owner.animation_data.action_slot
    strip.action_frame_start, strip.action_frame_end = 1,end
    strip.extrapolation = 'NOTHING'
    track.mute = True
    owner.animation_data.action = None


def _pose_action(rig, name, end, frames):
    """Key XYZ-degree inputs using each bone's existing rotation representation."""
    original_pose = [(bone, _capture_transform(bone)) for bone in rig.pose.bones]
    action = _action(rig, name)
    try:
        for frame, values in frames:
            for bone in rig.pose.bones:
                rotation, location = values.get(bone.name, ((0, 0, 0), (0, 0, 0)))
                _insert_pose_channels(bone, rotation, location, frame)
        _finish_action(rig, action, end)
    finally:
        for bone, transform in original_pose:
            _restore_transform(bone, transform)


def _human(m):
    col = _collection('player')
    specs = [('root',(0,0,0),(0,0,.15),None),
             ('pelvis',(0,0,.85),(0,0,1.02),'root'),
             ('spine',(0,0,1.02),(0,0,1.35),'pelvis'),
             ('head',(0,0,1.39),(0,0,1.68),'spine')]
    for s,sign in [('L',1),('R',-1)]:
        specs += [(f'upper_arm.{s}',(sign*.23,0,1.34),(sign*.36,.015,1.08),'spine'),
                  (f'forearm.{s}',(sign*.36,.015,1.08),(sign*.40,.05,.85),f'upper_arm.{s}'),
                  (f'hand.{s}',(sign*.40,.05,.85),(sign*.40,.08,.75),f'forearm.{s}'),
                  (f'thigh.{s}',(sign*.11,0,.87),(sign*.12,.015,.48),'pelvis'),
                  (f'shin.{s}',(sign*.12,.015,.48),(sign*.12,0,.10),f'thigh.{s}'),
                  (f'foot.{s}',(sign*.12,0,.10),(sign*.12,.17,.07),f'shin.{s}')]
    specs += [('weapon_socket',(.40,.08,.80),(.40,.20,.80),'hand.L')]
    rig = _rig(col,'PlayerRig',specs)
    rig.data.bones['weapon_socket'].use_deform = False
    def box(name,c,size,mat,bone,bevel=.015):
        obj=_box(col,name,c,size,mat,bevel); _bind(obj,rig,bone); return obj
    box('Torso_olive_jacket',(0,0,1.20),(.43,.24,.40),m['cloth'],'spine')
    box('Pelvis_trousers',(0,0,.88),(.31,.23,.21),m['cloth'],'pelvis')
    box('Belt',(0,0,.985),(.34,.25,.055),m['dark'],'pelvis',.004)
    box('Belt_buckle',(0,.132,.984),(.06,.012,.035),m['metal'],'pelvis',.003)
    box('Neck',(0,0,1.43),(.115,.13,.12),m['skin'],'head')
    box('Head',(0,.012,1.56),(.205,.19,.26),m['skin'],'head',.025)
    box('Hair_cap',(0,-.012,1.678),(.21,.175,.044),m['dark'],'head',.012)
    box('Hair_back',(0,-.083,1.61),(.206,.045,.17),m['dark'],'head',.01)
    box('Nose',(0,.119,1.585),(.04,.04,.055),m['skin'],'head',.006)
    for x in [-.052,.052]:
        box('Eye', (x,.110,1.624),(.035,.008,.015),m['dark'],'head',0)
    # Front pocket seams, not detached floating details.
    for x in [-.11,.11]:
        box('Jacket_pocket',(x,.125,1.27),(.125,.012,.105),m['cloth'],'spine',.005)
    for s,sign in [('L',1),('R',-1)]:
        for name,radii,mat in [('upper_arm',(.095,.075),'cloth'),('forearm',(.072,.052),'cloth'),
                              ('hand',(.054,.044),'skin'),('thigh',(.105,.08),'cloth'),
                              ('shin',(.08,.065),'cloth')]:
            bone=rig.data.bones[f'{name}.{s}']
            obj=_limb(col,f'{name}.{s}',bone.head_local,bone.tail_local,radii,m[mat])
            _bind(obj,rig,f'{name}.{s}')
        box(f'Boot.{s}',(sign*.12,.065,.064),(.15,.29,.128),m['dark'],f'foot.{s}',.02)
    _add_player_weapon_actions(rig)
    _pose_action(rig,'player|Death',37,[(1,{}),(12,{'spine':((25,0,0),(0,0,0))}),
                 (30,{'root':((88,0,0),(0,.13,0))}),(37,{'root':((88,0,0),(0,.13,0))})])
    return rig


def _arms(m):
    col=_collection('arms')
    specs=[('root',(0,0,-.32),(0,.1,-.32),None)]
    for s,sign in [('L',-1),('R',1)]:
        specs += [(f'forearm.{s}',(sign*.28,-.12,-.30),(sign*.12,.35,-.19),'root'),
                  (f'hand.{s}',(sign*.12,.35,-.19),(sign*.09,.49,-.18),f'forearm.{s}')]
    specs += [('weapon_socket',(.09,.47,-.18),(.09,.60,-.18),'hand.R')]
    rig=_rig(col,'ArmsRig',specs)
    for s in ['L','R']:
        for name,radii,mat in [('forearm',(.085,.055),'cloth'),('hand',(.06,.044),'skin')]:
            bone=rig.data.bones[f'{name}.{s}']
            obj=_limb(col,f'FP_{name}.{s}',bone.head_local,bone.tail_local,radii,m[mat],8)
            _bind(obj,rig,f'{name}.{s}')
    _pose_action(rig,'arms|Idle',49,[(1,{}),(25,{'root':((0,0,.6),(0,0,.003))}),(49,{})])
    _pose_action(rig,'arms|Fire',9,[(1,{}),(3,{'root':((7,0,0),(0,-.045,.012))}),(9,{})])
    _pose_action(rig,'arms|Reload',49,[(1,{}),(12,{'root':((-18,0,12),(0,-.09,-.09)),
                     'forearm.L':((0,0,-38),(0,0,0))}),
                     (30,{'root':((-18,0,12),(0,-.09,-.09)),
                          'forearm.L':((0,0,12),(0,0,0))}),(49,{})])


def _pistol(m):
    col=_collection('pistol')
    root=bpy.data.objects.new('Pistol',None); col.objects.link(root)
    # Origin: center of grip at its top; muzzle along Blender +Y / Godot -Z.
    for name,c,size,mat,bev in [
        ('Frame',(0,.045,.035),(.050,.19,.055),'metal',.006),
        ('Slide',(0,.070,.080),(.057,.235,.048),'metal',.005),
        ('Grip',(0,-.030,-.048),(.052,.073,.13),'dark',.007),
        ('Muzzle',(0,.191,.078),(.025,.006,.022),'dark',.002),
        ('Front_sight',(0,.145,.109),(.012,.018,.012),'dark',.001),
        ('Rear_sight_L',(-.019,-.028,.109),(.009,.018,.012),'dark',.001),
        ('Rear_sight_R',(.019,-.028,.109),(.009,.018,.012),'dark',.001),
        ('Trigger_guard_bottom',(0,.022,-.059),(.018,.07,.012),'metal',.003),
        ('Trigger_guard_front',(0,.056,-.023),(.018,.012,.070),'metal',.003),
        ('Trigger',(0,.017,-.012),(.012,.011,.036),'dark',.003),
        ('Magazine',(0,-.030,-.116),(.055,.076,.018),'metal',.003)]:
        obj=_box(col,name,c,size,m[mat],bev); obj.parent=root
    for name,end,poses in [('Idle',49,[(1,(0,0,0),(0,0,0)),(25,(0,0,.002),(0,0,0)),(49,(0,0,0),(0,0,0))]),
                          ('Fire',9,[(1,(0,0,0),(0,0,0)),(3,(0,-.026,.007),(10,0,0)),(9,(0,0,0),(0,0,0))]),
                           ('Reload',49,[(1,(0,0,0),(0,0,0)),(12,(0,-.07,-.08),(-18,0,15)),
                                         (32,(0,-.07,-.08),(-18,0,15)),(49,(0,0,0),(0,0,0))])]:
        action=_action(root,'pistol|'+name)
        for frame,location,rotation in poses:
            root.location=location; root.rotation_euler=tuple(math.radians(v) for v in rotation)
            root.keyframe_insert('location',frame=frame); root.keyframe_insert('rotation_euler',frame=frame)
        _finish_action(root,action,end)
    root.location=(0,0,0); root.rotation_euler=(0,0,0)


def _props(m):
    col=_collection('medkit')
    _box(col,'Medical_case',(0,0,.12),(.34,.23,.24),m['ivory'],.025)
    _box(col,'Medical_red_vertical',(0,-.119,.12),(.045,.009,.15),m['red'],.001)
    _box(col,'Medical_red_horizontal',(0,-.120,.12),(.15,.01,.045),m['red'],.001)
    for x in [-.065,.065]: _box(col,'Handle_foot',(x,0,.256),(.025,.035,.035),m['dark'],.003)
    _box(col,'Handle',(0,0,.277),(.15,.035,.02),m['dark'],.003)
    col=_collection('ammo')
    _box(col,'Ammo_tin',(0,0,.085),(.25,.16,.17),m['cloth'],.009)
    _box(col,'Ammo_lid',(0,0,.177),(.264,.17,.025),m['metal'],.005)
    _box(col,'Ammo_label',(0,-.084,.09),(.14,.007,.065),m['ivory'],.001)
    for x in [-.035,0,.035]:
        _box(col,'Bullet_symbol',(x,-.089,.09),(.014,.003,.04),m['dark'],0)
    col=_collection('crate')
    _box(col,'Crate',(0,0,.40),(.8,.8,.8),m['wood'],.012)
    for z in [.08,.72]:
        for y in [-.409,.409]: _box(col,'Crate_brace',(0,y,z),(.83,.035,.10),m['wood'],.004)
        for x in [-.409,.409]: _box(col,'Crate_brace_side',(x,0,z),(.035,.83,.10),m['wood'],.004)
    col=_collection('locker')
    _box(col,'Locker_shell',(0,0,.9),(.65,.45,1.8),m['metal'],.015)
    _box(col,'Locker_door',(0,.235,.92),(.59,.022,1.67),m['cloth'],.006)
    for z in [1.37,1.42,1.47,1.52]: _box(col,'Vent',(0,.25,z),(.35,.006,.018),m['dark'],0)
    _box(col,'Handle',(.21,.264,.96),(.025,.027,.14),m['dark'],.005)
    col=_collection('pipe')
    _limb(col,'Pipe',(0,0,0),(0,0,2.5),(.075,.075),m['metal'],8)
    for z in [.12,1.25,2.38]: _limb(col,'Pipe_collar',(0,0,z-.035),(0,0,z+.035),(.095,.095),m['dark'],8)
    col=_collection('wall')
    _box(col,'Wall',(0,0,1.4),(3,.20,2.8),m['plaster'],.004)
    for y in [-.106,.106]:
        _box(col,'Wall_baseboard',(0,y,.12),(3,.025,.24),m['metal'],.001)
        _box(col,'Wall_lower_band',(0,y,.55),(3,.012,.65),m['cloth'],.001)
    col=_collection('floor')
    _box(col,'Floor',(0,0,-.06),(3,3,.12),m['floor'],0)
    col=_collection('doorframe')
    for x in [-.62,.62]: _box(col,'Door_jamb',(x,0,1.05),(.12,.28,2.1),m['metal'],.006)
    _box(col,'Door_lintel',(0,0,2.16),(1.36,.28,.12),m['metal'],.006)


def _capture_transform(target):
    return (target.rotation_mode, target.location.copy(),
            target.rotation_euler.copy(), target.rotation_quaternion.copy(),
            tuple(target.rotation_axis_angle), target.scale.copy())


def _restore_transform(target, state):
    target.rotation_mode = state[0]
    target.location = state[1]
    target.rotation_euler = state[2]
    target.rotation_quaternion = state[3]
    target.rotation_axis_angle = state[4]
    target.scale = state[5]


def _capture_animation(owner):
    data = owner.animation_data
    if not data:
        return None
    return (data.action, data.action_slot, data.use_nla, data.use_tweak_mode,
            data.action_blend_type, data.action_extrapolation, data.action_influence,
            [(track, track.mute, track.is_solo,
              [(strip, strip.mute) for strip in track.strips])
             for track in data.nla_tracks])


def _restore_animation(owner, state):
    if state is None:
        return
    data = owner.animation_data
    data.use_tweak_mode = False
    data.action = state[0]
    if state[0] is not None:
        data.action_slot = state[1]
    data.use_nla = state[2]
    data.action_blend_type = state[4]
    data.action_extrapolation = state[5]
    data.action_influence = state[6]
    for track, muted, solo, strips in state[7]:
        track.mute = muted
        track.is_solo = solo
        for strip, strip_muted in strips:
            strip.mute = strip_muted
    data.use_tweak_mode = state[3]


def _capture_export_context():
    objects = []
    keys = []
    for obj in bpy.context.scene.objects:
        bones = []
        pose_position = None
        if obj.type == 'ARMATURE':
            pose_position = obj.data.pose_position
            bones = [(bone, _capture_transform(bone)) for bone in obj.pose.bones]
        objects.append((obj, _capture_transform(obj), _capture_animation(obj),
                        pose_position, bones, obj.hide_get(), obj.select_get()))
        if obj.type == 'MESH' and obj.data.shape_keys:
            key = obj.data.shape_keys
            keys.append((key, _capture_animation(key),
                         [(block, block.value) for block in key.key_blocks]))
    return {'objects': objects, 'keys': keys,
            'frame': bpy.context.scene.frame_current,
            'subframe': bpy.context.scene.frame_subframe,
            'active': bpy.context.view_layer.objects.active,
            'mode': bpy.context.object.mode if bpy.context.object else 'OBJECT'}


def _restore_export_context(state):
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    for obj, transform, animation, pose_position, bones, hidden, selected in state['objects']:
        _restore_animation(obj, animation)
        if pose_position is not None:
            obj.data.pose_position = pose_position
    for key, animation, blocks in state['keys']:
        _restore_animation(key, animation)
    # Evaluate the original timeline first; then restore its exact manual pose.
    bpy.context.scene.frame_set(state['frame'], subframe=state['subframe'])
    for obj, transform, animation, pose_position, bones, hidden, selected in state['objects']:
        _restore_transform(obj, transform)
        for bone, bone_transform in bones:
            _restore_transform(bone, bone_transform)
        obj.hide_set(hidden)
        obj.select_set(selected)
    for key, animation, blocks in state['keys']:
        for block, value in blocks:
            block.value = value
    bpy.context.view_layer.objects.active = state['active']
    bpy.context.view_layer.update()
    if state['mode'] != 'OBJECT' and state['active'] is not None:
        bpy.ops.object.mode_set(mode=state['mode'])


def _export(col, filepath, apply_modifiers=False):
    state = _capture_export_context()
    try:
        if bpy.context.object and bpy.context.object.mode != 'OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')
        bpy.ops.object.select_all(action='DESELECT')
        for obj in col.all_objects:
            obj.hide_set(False)
            obj.select_set(True)
        bpy.context.view_layer.objects.active = next(iter(col.all_objects), None)
        bpy.context.scene.frame_set(1)
        bpy.ops.export_scene.gltf(filepath=str(filepath), export_format='GLB',
            use_selection=True, use_active_scene=True, export_yup=True,
            export_apply=apply_modifiers, export_rest_position_armature=True,
            export_animations=True, export_animation_mode='NLA_TRACKS',
            export_frame_range=False, export_force_sampling=True,
            export_def_bones=False, export_cameras=False, export_lights=False,
            export_materials='EXPORT', export_image_format='AUTO')
    finally:
        _restore_export_context(state)


def _read_glb(path):
    with open(path,'rb') as stream:
        magic,version,_length=struct.unpack('<4sII',stream.read(12))
        if magic!=b'glTF' or version!=2: raise RuntimeError(f'Not GLB2: {path}')
        size,kind=struct.unpack('<II',stream.read(8))
        if kind!=0x4E4F534A: raise RuntimeError(f'No JSON chunk: {path}')
        return json.loads(stream.read(size).decode('utf8').rstrip('\0 '))


def export_existing(open_saved=False):
    """Export current editable objects; never reconstruct or save over the source.

    open_saved=True explicitly discards the current scene by loading BLEND.
    The default requires that file already be open, so unsaved edits are exported.
    """
    if open_saved:
        bpy.ops.wm.open_mainfile(filepath=str(BLEND))
    if Path(bpy.data.filepath).resolve()!=BLEND.resolve():
        raise RuntimeError(f'Open {BLEND} first (or explicitly pass open_saved=True)')
    missing=[name for name in ASSETS if name not in bpy.data.collections]
    if missing: raise RuntimeError(f'Missing asset collections: {missing}')
    EXPORT.mkdir(parents=True,exist_ok=True)
    state = _capture_export_context()
    report={}
    try:
        for name in ASSETS:
            path=EXPORT/(name+'.glb')
            _export(bpy.data.collections[name],path,apply_modifiers=True)
            data=_read_glb(path)
            report[name]={'meshes':len(data.get('meshes',[])),
                          'animations':[a.get('name') for a in data.get('animations',[])],
                          'bytes':path.stat().st_size}
        required={'player':{'Idle','Walk','Fire','Reload','Death'},
                  'arms':{'Idle','Fire','Reload'},'pistol':{'Idle','Fire','Reload'}}
        for name,clips in required.items():
            missing=clips-set(report[name]['animations'])
            if missing: raise RuntimeError(f'{name}: exported clips missing: {missing}')
        (SOURCE/'export_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    finally:
        _restore_export_context(state)
    print(json.dumps(report,indent=2))
    return report


def create_new():
    """FIRST CREATION ONLY. Refuse all existing sources, textures and exports."""
    protected=[BLEND,*[EXPORT/(name+'.glb') for name in ASSETS]]
    if BLEND.exists() or TEXTURES.exists() or any(p.exists() for p in protected):
        raise FileExistsError('Prototype output exists. Use export_existing(); preserve manual edits.')
    if bpy.data.is_dirty:
        raise RuntimeError('Save the current Blender file before creating assets in a separate scene.')
    # Keep the live MCP addon and the user's other scenes intact.
    scene = bpy.data.scenes.new('RetroPrototypeAssets')
    bpy.context.window.scene = scene
    TEXTURES.mkdir(parents=True)
    bpy.context.scene.render.fps=FPS
    bpy.context.scene.render.engine='BLENDER_EEVEE'
    bpy.context.scene.unit_settings.system='METRIC'
    palette={
        'skin':('Skin_ochre',(.54,.45,.34),'wear'),
        'cloth':('Cloth_olive',(.29,.32,.23),'cloth'),
        'dark':('Rubber_charcoal',(.13,.14,.12),'wear'),
        'metal':('Steel_rust',(.35,.32,.27),'wear'),
        'ivory':('Medical_ivory',(.72,.70,.58),'wear'),
        'red':('Medical_oxide',(.49,.16,.12),'wear'),
        'wood':('Crate_wood',(.40,.32,.20),'wood'),
        'plaster':('Plaster_dirty',(.48,.48,.40),'wear'),
        'floor':('Floor_tiles',(.31,.32,.29),'tile')}
    mats={key:_material(name,color,i,pattern) for i,(key,(name,color,pattern)) in enumerate(palette.items())}
    _human(mats); _arms(mats); _pistol(mats); _props(mats)
    bpy.context.scene['asset_contract']='Blender +Y forward -> Godot -Z; meters; feet Z=0; in-place clips'
    bpy.context.scene['authoring_note']='Preserve edits. Re-export this file; never rerun first creation over it.'
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    # Convert external references to portable paths, keep packed originals.
    for image in bpy.data.images:
        if image.source=='FILE' and image.filepath: image.filepath=bpy.path.relpath(image.filepath)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    return export_existing()


def extend_zombie_copy():
    """Create a separate working copy and add three clips once. Original is untouched.

    Refuses to overwrite an existing prototype source; later edits use ordinary
    Blender tools plus export_zombie_current(). Existing clips are left intact.
    """
    if ZOMBIE_WORK.exists(): raise FileExistsError('Zombie working file exists: edit/export that file.')
    if not ZOMBIE_ORIGINAL.exists(): raise FileNotFoundError(ZOMBIE_ORIGINAL)
    if bpy.data.is_dirty: raise RuntimeError('Save current Blender file first.')
    bpy.ops.wm.open_mainfile(filepath=str(ZOMBIE_ORIGINAL))
    rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
    if len(rigs)!=1: raise RuntimeError(f'Expected one zombie armature, found {len(rigs)}')
    rig=rigs[0]
    required={'root','pelvis','spine','chest','head'}
    if not required.issubset(rig.pose.bones.keys()): raise RuntimeError('Unexpected zombie skeleton')
    # New tracks for existing actions make all original clips explicit to exporter.
    existing_actions=[]
    for action in bpy.data.actions:
        if action.name.startswith('Zombie_'):
            existing_actions.append(action)
    rig.animation_data_create()
    original_action=rig.animation_data.action
    original_slot=rig.animation_data.action_slot
    represented={track.name for track in rig.animation_data.nla_tracks}
    for action in existing_actions:
        if action.name in represented: continue
        slots=[s for s in action.slots if s.target_id_type=='OBJECT']
        if not slots: raise RuntimeError(f'Original action has no object slot: {action.name}')
        track=rig.animation_data.nla_tracks.new(); track.name=action.name
        strip=track.strips.new(action.name,1,action); strip.action_slot=slots[0]
        strip.extrapolation='NOTHING'; track.mute=True
    _add_zombie_actions(rig)
    # Preserve original Actions and texture datablocks; added tracks start muted.
    rig.animation_data.action=original_action
    if original_action: rig.animation_data.action_slot=original_slot
    for image in bpy.data.images:
        if image.size[0] and not image.packed_file: image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(ZOMBIE_WORK))
    return export_zombie_current()


def export_zombie_current():
    if Path(bpy.data.filepath).resolve()!=ZOMBIE_WORK.resolve():
        raise RuntimeError(f'Open the editable zombie working copy: {ZOMBIE_WORK}')
    rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
    if len(rigs)!=1: raise RuntimeError('Expected exactly one zombie rig')
    rig=rigs[0]
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and
            (o.parent==rig or any(mod.type=='ARMATURE' and mod.object==rig for mod in o.modifiers))]
    if not meshes: raise RuntimeError('No meshes bound to zombie rig')
    col=bpy.data.collections.new('__temporary_zombie_export')
    bpy.context.scene.collection.children.link(col)
    for obj in [rig,*meshes]: col.objects.link(obj)
    EXPORT.mkdir(parents=True,exist_ok=True)
    path=EXPORT/'zombie.glb'
    try: _export(col,path)
    finally: bpy.data.collections.remove(col)
    data=_read_glb(path)
    clips=[a.get('name') for a in data.get('animations',[])]
    required={'Zombie_Walk','Zombie_Attack','Zombie_Bite','Zombie_Idle','Zombie_Hit','Zombie_Death'}
    if not required.issubset(clips): raise RuntimeError(f'Zombie clips missing: {required-set(clips)}')
    return {'path':str(path),'animations':clips,'meshes':len(data.get('meshes',[]))}


def _add_zombie_actions(rig):
    _pose_action(rig,'Zombie_Idle',49,[(1,{}),(25,{'chest':((2,0,0),(0,0,0)),
                             'head':((0,0,2),(0,0,0))}),(49,{})])
    _pose_action(rig,'Zombie_Hit',13,[(1,{}),(4,{'chest':((-13,0,-7),(0,0,0)),
                           'head':((-10,0,5),(0,0,0))}),(13,{})])
    _pose_action(rig,'Zombie_Death',37,[(1,{}),(10,{'chest':((17,0,5),(0,0,0))}),
                           (28,{'root':((88,0,0),(0,0,0))}),
                           (37,{'root':((88,0,0),(0,0,0))})])


def repair_zombie_rotation_compatibility(backup_confirmed=False):
    """Repair the generated copy after the old Euler-generator defect.

    No file saves, no mesh/rig rebuild, no changes to original action curves.
    Caller first saves a recoverable .blend backup outside this function.
    Only the three generated actions/tracks are replaced; the old versions
    remain as fake-user Backup_Euler_* Actions in the same editable file.
    """
    if backup_confirmed is not True:
        raise RuntimeError('Save a recoverable working-file backup before repair.')
    current = bpy.data.filepath.replace('\\', '/').lower()
    expected = str(ZOMBIE_WORK).replace('\\', '/').lower()
    if current != expected:
        raise RuntimeError('Repair only the editable Zombie_Rigged.prototype.blend copy.')
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE']
    if len(rigs) != 1 or rigs[0].name != 'Zombie_Rig':
        raise RuntimeError('Unexpected zombie rig; no repair performed.')
    rig = rigs[0]
    if len(rig.pose.bones) != 49:
        raise RuntimeError('Unexpected bone count; no repair performed.')
    originals = ['Zombie_Walk', 'Zombie_Attack', 'Zombie_Bite']
    generated = ['Zombie_Idle', 'Zombie_Hit', 'Zombie_Death']
    for name in originals:
        action = bpy.data.actions.get(name)
        if action is None:
            raise RuntimeError('Missing original action: ' + name)
        paths = [curve.data_path for layer in action.layers for strip in layer.strips
                 if strip.type == 'KEYFRAME' for bag in strip.channelbags for curve in bag.fcurves]
        if not any(path.endswith('rotation_quaternion') for path in paths):
            raise RuntimeError('Original action does not match inspected quaternion source: ' + name)
        if any(path.endswith('rotation_euler') for path in paths):
            raise RuntimeError('Unexpected original Euler curves; preserve and investigate: ' + name)
    old_actions = []
    for name in generated:
        action = bpy.data.actions.get(name)
        if action is None:
            raise RuntimeError('Missing generated action: ' + name)
        if bpy.data.actions.get('Backup_Euler_' + name):
            raise RuntimeError('Generated-action backup already exists; refusing repeat repair.')
        old_actions.append(action)
    data = rig.animation_data
    if data is None:
        raise RuntimeError('Missing zombie animation data.')
    tracks = []
    for track in data.nla_tracks:
        if any(strip.action in old_actions for strip in track.strips):
            if any(strip.action not in old_actions for strip in track.strips):
                raise RuntimeError('Mixed original/generated NLA track; no repair performed.')
            tracks.append(track)
    data.use_tweak_mode = False
    data.action = None
    data.use_nla = False
    backups = []
    for action in old_actions:
        action.name = 'Backup_Euler_' + action.name
        action.use_fake_user = True
        backups.append(action.name)
    for track in tracks:
        data.nla_tracks.remove(track)
    for track in data.nla_tracks:
        track.mute = True
        track.is_solo = False
    # The inspected original has QUATERNION on all 49 bones.
    for bone in rig.pose.bones:
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_euler = (0, 0, 0)
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.rotation_axis_angle = (0, 0, 1, 0)
        bone.location = (0, 0, 0)
        bone.scale = (1, 1, 1)
    _add_zombie_actions(rig)
    data.action = None
    data.use_nla = False
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    return {'replaced_generated': generated, 'retained_backups': backups,
            'untouched_originals': originals, 'bone_rotation_mode': 'QUATERNION',
            'next_step': 'Preview original Walk and generated clips, save working copy, export separately.'}


def _insert_pose_channels(bone, rotation, location, frame):
    quaternion = Euler(tuple(math.radians(v) for v in rotation), 'XYZ').to_quaternion()
    if bone.rotation_mode == 'QUATERNION':
        bone.rotation_quaternion = quaternion
        rotation_path = 'rotation_quaternion'
    elif bone.rotation_mode == 'AXIS_ANGLE':
        axis, angle = quaternion.to_axis_angle()
        bone.rotation_axis_angle = (angle, axis.x, axis.y, axis.z)
        rotation_path = 'rotation_axis_angle'
    else:
        bone.rotation_euler = quaternion.to_euler(bone.rotation_mode)
        rotation_path = 'rotation_euler'
    bone.location = location
    bone.keyframe_insert(rotation_path, frame=frame, group=bone.name)
    bone.keyframe_insert('location', frame=frame, group=bone.name)


def _pose_matrix(head, tail):
    head, tail = Vector(head), Vector(tail)
    y_axis = (tail - head).normalized()
    x_axis = y_axis.cross(Vector((0, 0, 1)))
    if x_axis.length < .0001:
        x_axis = Vector((1, 0, 0))
    x_axis.normalize()
    z_axis = x_axis.cross(y_axis).normalized()
    matrix = Matrix((x_axis, y_axis, z_axis)).transposed().to_4x4()
    matrix.translation = head
    return matrix


def _elbow_for_lengths(shoulder, wrist, pole, upper_length, lower_length):
    shoulder, wrist, pole = Vector(shoulder), Vector(wrist), Vector(pole)
    direction = wrist - shoulder
    distance = direction.length
    if distance < .0001 or distance >= upper_length + lower_length:
        raise RuntimeError('Player wrist target outside the unchanged arm reach.')
    direction.normalize()
    along = (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2 * distance)
    height = math.sqrt(max(0, upper_length * upper_length - along * along))
    bend = pole - shoulder
    bend -= direction * bend.dot(direction)
    bend.normalize()
    return shoulder + direction * along + bend * height


def _player_hold_pose(rig, recoil=0.0, lowered=0.0, support_drop=0.0):
    """Natural two-hand hold in armature coordinates, unchanged limb lengths."""
    targets = {}
    for suffix, shoulder, elbow_pole, wrist, knuckles in [
        ('L', (.23, 0, 1.34), (.30, .17, 1.16), (.16, .40, 1.28), (.16, .52, 1.28)),
        ('R', (-.23, 0, 1.34), (-.28, .18, 1.14), (.07, .39, 1.26), (.12, .49, 1.28))]:
        wrist, knuckles = Vector(wrist), Vector(knuckles)
        shift = Vector((0, -.025 * recoil - .10 * lowered, .014 * recoil - .15 * lowered))
        if suffix == 'R':
            shift += Vector((.015 * support_drop, -.02 * support_drop, -.07 * support_drop))
        wrist += shift
        knuckles += shift
        if lowered:
            knuckles.z += .04 * lowered
        upper = rig.data.bones['upper_arm.' + suffix]
        forearm = rig.data.bones['forearm.' + suffix]
        elbow = _elbow_for_lengths(shoulder, wrist, elbow_pole, upper.length, forearm.length)
        hand_length = rig.data.bones['hand.' + suffix].length
        knuckles = wrist + (knuckles - wrist).normalized() * hand_length
        targets['upper_arm.' + suffix] = _pose_matrix(shoulder, elbow)
        targets['forearm.' + suffix] = _pose_matrix(elbow, wrist)
        targets['hand.' + suffix] = _pose_matrix(wrist, knuckles)
        if suffix == 'L':
            direction = (knuckles - wrist).normalized()
            grip = wrist + direction * .052 + Vector((0, 0, .045))
            targets['weapon_socket'] = _pose_matrix(grip, grip + direction * .12)
    pose = {}
    for name in ['upper_arm.L', 'forearm.L', 'hand.L',
                 'upper_arm.R', 'forearm.R', 'hand.R', 'weapon_socket']:
        bone = rig.data.bones[name]
        parent_matrix = targets.get(bone.parent.name, bone.parent.matrix_local)
        basis = bone.convert_local_to_pose(targets[name], bone.matrix_local,
            parent_matrix=parent_matrix, parent_matrix_local=bone.parent.matrix_local, invert=True)
        rotation = tuple(math.degrees(value) for value in basis.to_quaternion().to_euler('XYZ'))
        pose[name] = (rotation, tuple(basis.to_translation()))
    return pose


def _player_weapon_frames(rig, clip):
    hold = _player_hold_pose(rig)
    if clip == 'Idle':
        return [(1, hold), (25, _player_hold_pose(rig, recoil=.05)), (49, hold)]
    if clip == 'Walk':
        return [(frame, _player_hold_pose(rig)) for frame in [1, 7, 13, 19, 25]]
    if clip == 'Fire':
        return [(1, hold), (3, _player_hold_pose(rig, recoil=1)), (13, hold)]
    if clip == 'Reload':
        return [(1, hold), (15, _player_hold_pose(rig, lowered=1, support_drop=1)),
                (31, _player_hold_pose(rig, lowered=1, support_drop=.3)), (49, hold)]
    raise RuntimeError('Unsupported player weapon clip: ' + clip)


def _add_player_weapon_actions(rig):
    for clip, end in [('Idle', 49), ('Walk', 25), ('Fire', 13), ('Reload', 49)]:
        frames = _player_weapon_frames(rig, clip)
        if clip == 'Walk':
            enriched = []
            for (frame, pose), phase in zip(frames, [0, math.pi / 2, math.pi, 3 * math.pi / 2, 2 * math.pi]):
                pose = dict(pose)
                pose['pelvis'] = ((0, 0, 0), (0, .012 * abs(math.sin(phase)), 0))
                for suffix, sign in [('L', 1), ('R', -1)]:
                    swing = math.sin(phase) * sign
                    pose['thigh.' + suffix] = ((25 * swing, 0, 0), (0, 0, 0))
                    pose['shin.' + suffix] = ((-max(0, -swing) * 35, 0, 0), (0, 0, 0))
                enriched.append((frame, pose))
            frames = enriched
        elif clip == 'Idle':
            frames[1][1]['spine'] = ((1, 0, 0), (0, .004, 0))
        _pose_action(rig, 'player|' + clip, end, frames)


def _move_player_weapon_socket(rig):
    _activate(rig)
    bpy.ops.object.mode_set(mode='EDIT')
    socket = rig.data.edit_bones['weapon_socket']
    socket.parent = rig.data.edit_bones['hand.L']
    socket.head = (.40, .08, .80)
    socket.tail = (.40, .20, .80)
    socket.roll = 0
    socket.use_deform = False
    bpy.ops.object.mode_set(mode='OBJECT')


def patch_player_weapon_pose(backup_confirmed=False):
    """Replace only own upper-body animation curves, preserve mesh/legs/Death."""
    if backup_confirmed is not True:
        raise RuntimeError('Save a recoverable Retro_Prototype.blend backup first.')
    if bpy.data.filepath.replace('\\', '/').lower() != str(BLEND).replace('\\', '/').lower():
        raise RuntimeError('Open the editable Retro_Prototype.blend source.')
    rig = bpy.data.objects.get('PlayerRig')
    if rig is None or rig.type != 'ARMATURE' or len(rig.data.bones) != 17:
        raise RuntimeError('Expected the unchanged 17-bone PlayerRig.')
    upper_names = ['upper_arm.L', 'forearm.L', 'hand.L',
                   'upper_arm.R', 'forearm.R', 'hand.R', 'weapon_socket']
    for obj in bpy.data.objects:
        if obj.type == 'MESH' and obj.vertex_groups.get('weapon_socket'):
            raise RuntimeError('Socket has mesh weights; preserve and investigate before reparenting.')
    actions = []
    for clip in ['Idle', 'Walk', 'Fire', 'Reload']:
        action = bpy.data.actions.get('player|' + clip)
        if action is None or len(action.slots) != 1:
            raise RuntimeError('Missing or unexpected own player action: ' + clip)
        if bpy.data.actions.get('Backup_Weapon_' + action.name):
            raise RuntimeError('Weapon-pose backup already exists; refusing repeat patch.')
        actions.append((clip, action))
    data = rig.animation_data
    data.use_tweak_mode = False
    data.action = None
    data.use_nla = False
    _move_player_weapon_socket(rig)
    replacements = {}
    backups = []
    for clip, old_action in actions:
        original_name = old_action.name
        old_action.name = 'Backup_Weapon_' + original_name
        old_action.use_fake_user = True
        backups.append(old_action.name)
        action = old_action.copy()
        action.name = original_name
        action.use_fake_user = True
        for layer in action.layers:
            for strip in layer.strips:
                if strip.type != 'KEYFRAME':
                    continue
                for bag in strip.channelbags:
                    for curve in list(bag.fcurves):
                        if any(curve.data_path.startswith('pose.bones["' + name + '"].') for name in upper_names):
                            bag.fcurves.remove(curve)
        data.action = action
        data.action_slot = action.slots[0]
        for frame, pose in _player_weapon_frames(rig, clip):
            for name, values in pose.items():
                _insert_pose_channels(rig.pose.bones[name], values[0], values[1], frame)
        data.action = None
        for track in data.nla_tracks:
            for strip in track.strips:
                if strip.action == old_action:
                    strip.action = action
                    strip.action_slot = action.slots[0]
        replacements[clip] = action
    data.action = replacements['Idle']
    data.action_slot = replacements['Idle'].slots[0]
    data.use_nla = False
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    return {'replaced_upper_body': list(replacements), 'backups': backups,
            'unchanged': 'all meshes, skin weights, leg/spine curves and Death action',
            'socket_parent': 'hand.L', 'socket_forward_axis': '+Y (gun local X rotation +PI/2 in Godot)',
            'next_step': 'Inspect playback, save source, then export_existing() in a separate call.'}
