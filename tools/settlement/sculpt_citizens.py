"""Run with Blender --background --python this_file -- /tmp/pyramida-citizens.

Build a joined, rounded outer surface. Clothes are material regions of that
surface, not intersecting shells over a complete naked body. Godot's companion
generator attaches the surface to the same articulated rig used for animation.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

OUT = Path(sys.argv[sys.argv.index("--") + 1])
OUT.mkdir(parents=True, exist_ok=True)


def ellipsoid(name, position, radii):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=position)
    ob = bpy.context.object
    ob.name = name
    ob.scale = radii
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return ob


def capsule(name, a, b, radius):
    a, b = Vector(a), Vector(b)
    pieces = [ellipsoid(name, a, (radius,) * 3), ellipsoid(name, b, (radius,) * 3)]
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=(b-a).length, location=(a+b)/2)
    cylinder = bpy.context.object
    cylinder.rotation_mode = "QUATERNION"
    cylinder.rotation_quaternion = (b-a).to_track_quat("Z", "Y")
    pieces.append(cylinder)
    return pieces


def joined_surface(pieces):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in pieces:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.join()
    ob = bpy.context.object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    remesh = ob.modifiers.new("Joined shoulders and belly", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.014
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = ob.modifiers.new("Soft silhouette", "SMOOTH")
    smooth.factor = 0.85
    smooth.iterations = 5
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    decimate = ob.modifiers.new("Game mesh", "DECIMATE")
    decimate.ratio = 0.42
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    return ob


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


def weights(v, variant, head=False):
    if head:
        return [(2, 1.0)]
    x, _, z = v
    # Root / torso blend keeps the belly soft while preserving the hip pivot.
    torso = smoothstep(0.30, 0.53, z)
    result = {0: 1-torso, 1: torso}
    if z > 0.36:
        # Follow the sloping shoulder/arm junction. A fixed X threshold would
        # accidentally bind the broad belly to the arms and pinch the shirt.
        inner = 0.18 + 0.065*(1-smoothstep(0.50, 0.65, z))
        arm = smoothstep(inner, inner+0.035, abs(x))
        upper, lower = (3, 4) if x < 0 else (5, 6)
        elbow = 1-smoothstep(0.47, 0.56, z)
        result = {k: w*(1-arm) for k, w in result.items()}
        result[upper] = arm*(1-elbow)
        result[lower] = arm*elbow
    else:
        leg = 1-smoothstep(0.26, 0.36, z)
        right = smoothstep(-0.035, 0.035, x)
        knee = 1-smoothstep(0.15, 0.22, z)
        result = {k: w*(1-leg) for k, w in result.items()}
        for upper, lower, side in [(7, 8, 1-right), (9, 10, right)]:
            result[upper] = leg*side*(1-knee)
            result[lower] = leg*side*knee
    result = sorted(result.items(), key=lambda item: -item[1])[:4]
    total = sum(w for _, w in result)
    return [(bone, weight/total) for bone, weight in result if weight > 0.000001]


def garment_region(p, variant):
    x, _, z = p
    # Arm skin remains exposed. The waist/neckline cuts are real shared edges.
    if abs(x) > 0.285 or abs(x) > 0.235 and z > 0.47:
        return 0
    if variant == 0:
        return int(0.205 < z < 0.365)
    if variant == 1:
        return int(z > 0.235 and z < 0.655)
    if variant == 2:
        return int(z > 0.235 and z < 0.61 - x*0.28)
    return int(0.235 < z < 0.44 or 0.535 < z < 0.655)


def export_mesh(objects, variant):
    vertices, normals, bone_ids, bone_weights = [], [], [], []
    surfaces = [[], [], []]  # skin, cloth, hair
    for ob, fixed_material, is_head in objects:
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        if fixed_material is None:
            for z in [0.205, 0.235, 0.365, 0.44, 0.47, 0.535, 0.655]:
                bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                    dist=0.00001, plane_co=(0, 0, z), plane_no=(0, 0, 1))
            for x in [-0.285, -0.235, 0.235, 0.285]:
                bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                    dist=0.00001, plane_co=(x, 0, 0), plane_no=(1, 0, 0))
            if variant == 2:
                bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                    dist=0.00001, plane_co=(0, 0, 0.61), plane_no=(0.28, 0, 1))
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bm.normal_update()
        bm.verts.ensure_lookup_table()
        for v in bm.verts:
            v.index = len(vertices)
            p = ob.matrix_world @ v.co
            n = ob.matrix_world.to_3x3() @ v.normal
            n.normalize()
            # Blender Z-up to Godot Y-up, with forward toward -Z.
            vertices.append([p.x, p.z, -p.y])
            normals.append([n.x, n.z, -n.y])
            weighted = weights(p, variant, is_head)
            bone_ids.append([i for i, _ in weighted] + [0]*(4-len(weighted)))
            bone_weights.append([w for _, w in weighted] + [0.0]*(4-len(weighted)))
        for f in bm.faces:
            material = fixed_material if fixed_material is not None else garment_region(f.calc_center_median(), variant)
            # Blender's CCW faces become Godot's clockwise faces.
            surfaces[material].extend([f.verts[0].index, f.verts[2].index, f.verts[1].index])
        bm.free()
    payload = dict(vertices=vertices, normals=normals, bones=bone_ids, weights=bone_weights, surfaces=surfaces)
    (OUT / f"citizen_{variant}.json").write_text(json.dumps(payload, separators=(",", ":")))
    print(f"Citizen {variant}: {len(vertices)} vertices, {sum(map(len,surfaces))//3} triangles")


for variant in range(4):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    pieces = [ellipsoid("Belly", (0, 0.025, 0.475), (0.25, 0.185, 0.205)),
              ellipsoid("Chest", (0, 0, 0.605), (0.205, 0.145, 0.13)),
              ellipsoid("Neck", (0, 0, 0.735), (0.065, 0.065, 0.08))]
    for side in [-1, 1]:
        pieces += capsule("Upper arm", (side*0.205, 0, 0.645), (side*0.295, 0, 0.515), 0.057)
        pieces += capsule("Forearm", (side*0.295, 0, 0.515), (side*0.335, 0.012, 0.415), 0.053)
        pieces += capsule("Thigh", (side*0.11, 0, 0.29), (side*0.11, 0, 0.185), 0.073)
        pieces += capsule("Shin", (side*0.11, 0, 0.185), (side*0.11, 0.008, 0.09), 0.072)
    if variant != 0:
        bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.268, radius2=0.215, depth=0.235, location=(0, 0, 0.3525))
        skirt = bpy.context.object
        skirt.scale.y = 0.76
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        pieces.append(skirt)
    body = joined_surface(pieces)
    head = ellipsoid("Small round head", (0, 0, 0.845), (0.137, 0.125, 0.15))
    hair = ellipsoid("Hair cap", (0, -0.018, 0.949), (0.14, 0.125, 0.063))
    ornaments = []
    if variant in [1, 3]:
        ornaments.append(ellipsoid("Small bun", (0.108, -0.067, 0.947), (0.065, 0.06, 0.068)))
    else:
        ornaments.append(ellipsoid("Hair tuft", (-0.052, 0.01, 0.987), (0.065, 0.075, 0.04)))
    export_mesh([(body, None, False), (head, 0, True), (hair, 2, True)] + [(ob, 2, True) for ob in ornaments], variant)
