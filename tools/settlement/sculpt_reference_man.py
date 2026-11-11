"""Low-poly family studies with independent clothing and hair.
Blender --background --python tools/settlement/sculpt_reference_man.py -- /tmp/pyramida-reference-woman woman
Omit the final variant for the approved male; child is also supported.
The editable body is complete; covered triangles are masked only when dressed.
"""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Vector
OUT=Path(sys.argv[sys.argv.index('--')+1]); OUT.mkdir(parents=True,exist_ok=True)
VARIANT=sys.argv[sys.argv.index('--')+2] if len(sys.argv)>sys.argv.index('--')+2 else 'man'
assert VARIANT in ('man','woman','child')
ASSET='reference_'+VARIANT
N=8
BODY_WIDTH=.88
ARM_INSET=.18*(1-BODY_WIDTH)-(.026 if VARIANT=='woman' else 0)
CENTRES=[(0,0,0),(0,0,.46),(0,0,.837),(-.192,0,.61),(-.282,0,.53),(.192,0,.61),(.282,0,.53),(-.105,0,.34),(-.105,0,.19),(.105,0,.34),(.105,0,.19)]
NAMES=['Root','Torso','Head','LeftArm','LeftElbow','RightArm','RightElbow','LeftLeg','LeftKnee','RightLeg','RightKnee']
PARENTS=[-1,0,1,1,3,1,5,0,7,0,9]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def ease(a,b,t):
    t=max(0,min(1,(t-a)/(b-a))); return t*t*(3-2*t)

def ring(z,rx,ry,x=0,y=0,square=1):
    def sp(v): return math.copysign(abs(v)**square,v)
    return [(x+rx*sp(math.cos(i*math.tau/N)),y+ry*sp(math.sin(i*math.tau/N)),z) for i in range(N)]

def binding(p,part):
    x,y,z=p
    # Bind in the original authoring proportions after narrowing the mesh.
    if part in (1,2): x+=math.copysign(1,x)*ARM_INSET
    elif part!=3: x/=BODY_WIDTH
    if part==3: return {2:1.0}
    if part in [1,2]:
        upper,lower=(3,4) if part==1 else (5,6)
        elbow=ease(-.025,.025,(abs(x)-.282)*.75-(z-.53)*.66)
        # Anchor the root of the capsule to the torso and blend into the arm.
        # Rotating the arm must never peel its shoulder cap out of the body.
        shoulder=ease(-.030,.040,(abs(x)-.192)*.75-(z-.61)*.66)
        return {1:1-shoulder,upper:shoulder*(1-elbow),lower:shoulder*elbow}
    torso=ease(.36,.54,z); leg=1-ease(.275,.405,z)
    result={0:(1-torso)*(1-leg),1:torso*(1-leg)}
    side=ease(-.03,.03,x); knee=1-ease(.19,.24,z)
    for upper,lower,fraction in [(7,8,1-side),(9,10,side)]:
        result[upper]=leg*fraction*(1-knee); result[lower]=leg*fraction*knee
    return result

class Surface:
    def __init__(self): self.verts=[]; self.faces=[]; self.tags=[]
    def ring(self,points,tag=0):
        ids=list(range(len(self.verts),len(self.verts)+len(points))); self.verts.extend(points); self.tags.extend([tag]*len(points)); return ids
    def bridge(self,a,b):
        i=j=0
        while i<len(a) or j<len(b):
            advance_a=(i+1)/len(a) if i<len(a) else 2
            advance_b=(j+1)/len(b) if j<len(b) else 2
            if abs(advance_a-advance_b)<1e-8:
                self.faces.append((a[i%len(a)],a[(i+1)%len(a)],b[(j+1)%len(b)],b[j%len(b)])); i+=1; j+=1
            elif advance_a<advance_b:
                self.faces.append((a[i%len(a)],a[(i+1)%len(a)],b[j%len(b)])); i+=1
            else:
                self.faces.append((a[i%len(a)],b[(j+1)%len(b)],b[j%len(b)])); j+=1
    def cap(self,a): self.faces.append(tuple(reversed(a)))
    def loft(self,sections,tag=0,close_start=False,close_end=False):
        previous=None; first=None
        for points in sections:
            current=self.ring(points,tag)
            if previous is not None: self.bridge(previous,current)
            else: first=current
            previous=current
        if close_start: self.cap(first)
        if close_end: self.cap(previous)
        return first,previous

def box_ring(z,rx,ry):
    # Broad front/back with generous rounded-corner chamfers.
    bevel=min(rx,ry)*.60
    return [(rx,ry-bevel,z),(rx-bevel,ry,z),(0,ry,z),(-rx+bevel,ry,z),(-rx,ry-bevel,z),
            (-rx,-ry+bevel,z),(-rx+bevel,-ry,z),(0,-ry,z),(rx-bevel,-ry,z),(rx,-ry+bevel,z)]

def split_top(side,z,rx,ry):
    return [(x if x*side>0 else 0,y,z) for x,y,z in box_ring(z,rx,ry)]

def top_edge(x,y):
    # Low underarms keep the separate crop top clear of the swinging arms.
    return max(.50,.60+.15*x-.22*(abs(x)/.18)**4*(1-abs(y)/.108))

body=Surface()
# Straight-sided torso with enough front-to-back depth to read in profile.
torso_sections=[(.275,.16,.09),(.44,.18,.108),(.59,.18,.108),(.63,.166,.099),(.655,.135,.082),(.655,.05,.052),(.727,.05,.052)]
if VARIANT=='woman':
    torso_sections.insert(2,(.49,.18,.108))
    torso_sections[3]=(.60,.18,.108)
body.loft([[(x,y,top_edge(x,y) if VARIANT=='woman' and z==.60 else z) for x,y,z in box_ring(z,rx,ry)] for z,rx,ry in torso_sections],close_end=True)
for side in [-1,1]:
    # Constant-width lower leg with a rounded end, no heel or forward toes.
    body.loft([split_top(side,.275,.16,.09)]+[ring(z,rx,ry,side*.105,0) for z,rx,ry in [(.255,.067,.067),(.23,.059,.058),(.19,.055,.05),(.17,.055,.05),(.06,.055,.05),(.025,.045,.041),(.008,.018,.016)]],close_end=True)
for side in [-1,1]:
    sections=[]
    # Short capsule-like arms with nearly constant thickness and round ends.
    for x,z,r in [(.105,.61,.036),(.19,.60,.048),(.255,.543,.046),(.27,.53,.048),(.285,.517,.045),(.33,.477,.046),(.357,.453,.028),(.364,.446,.008)]:
        normal=Vector((side*.66,0,.75))
        sections.append([tuple(Vector((side*(x+.012),0,z))+normal*(math.cos(i*math.tau/N)*r)+Vector((0,1,0))*(math.sin(i*math.tau/N)*r)) for i in range(N)])
    body.loft(sections,1 if side<0 else 2,True,True)
HEAD_SIZE=1.08 if VARIANT=='child' else 1.0
body.loft([ring(.837+math.sin(a)*.155*HEAD_SIZE,math.cos(a)*.155*HEAD_SIZE,math.cos(a)*.137*HEAD_SIZE,y=-.004) for a in [-1.35,-.70,0,.70,1.35]],3,True,True)

# Short dhoti-inspired wrap: high thigh hems and an overlapping diagonal fold.
# Keep the two leg openings, but lose the long cylindrical shorts silhouette.
shorts=Surface()
shorts.loft([box_ring(z,rx,ry) for z,rx,ry in [(.30,.178,.112),(.36,.188,.125),(.435,.195,.128),(.455,.195,.128),(.455,.183,.114),(.435,.183,.114)]],4)
for side in [-1,1]:
    shorts.loft([split_top(side,.30,.178,.112)]+[ring(z,rx,ry,side*.105,0,square=.85) for z,rx,ry in [(.275,.084,.087),(.245,.078,.081),(.245,.070,.073),(.259,.070,.073)]],4)
# A small overlapping front fold gives the wrap a readable diagonal at game scale.
fold=shorts.ring([(-.115,.134,.443),(.13,.134,.443),(.055,.117,.242),(-.025,.123,.276)],5)
if VARIANT=='man': shorts.faces.append(tuple(fold))
extras=[]
if VARIANT=='woman':
    shorts=Surface()
    shorts.loft([box_ring(z,rx,ry) for z,rx,ry in [(.245,.202,.143),(.30,.195,.136),(.435,.195,.128),(.455,.195,.128),(.455,.183,.114),(.435,.183,.114)]],4)
    top=Surface()
    # Coral rims close the space between the garment shell and masked skin.
    inner_low=box_ring(.49,.1801,.1081)
    outer_low=box_ring(.49,.189,.118)
    inner_high=[(x,y,top_edge(x*.18/.1801,y*.108/.1081)) for x,y,_ in inner_low]
    outer_high=[(x,y,p[2]) for (x,y,_),p in zip(outer_low,inner_high)]
    top.loft([inner_low,outer_low,outer_high,inner_high],4)
    extras.append(('Top',top,(.95,.40,.39,1)))
if VARIANT!='man':
    hair=Surface()
    # Head shell with a swept front edge; keep the featureless face open.
    cap=[]
    for row in range(3):
        points=[]
        for i in range(12):
            theta=i*math.tau/12
            a=(.18+.26*math.sin(theta)-.12*math.cos(theta)) if row==0 else (.85 if row==1 else 1.40)
            points.append((math.cos(theta)*math.cos(a)*.168*HEAD_SIZE,
                           -.004+math.sin(theta)*math.cos(a)*.151*HEAD_SIZE,
                           .837+math.sin(a)*.167*HEAD_SIZE))
        cap.append(points)
    hair.loft(cap,3,False,True)
    if VARIANT=='woman':
        # A short, broad curtain behind the head, ending above the shoulders.
        rows=[]
        for z,rx,ry in [(.87,.167,.151),(.77,.163,.153),(.695,.147,.150)]:
            rows.append(hair.ring([(rx*math.cos(a),-.004+ry*math.sin(a),z) for a in [math.pi+i*math.pi/6 for i in range(7)]],3))
        for a,b in zip(rows,rows[1:]):
            for i in range(6): hair.faces.append((a[i],a[i+1],b[i+1],b[i]))
    extras.append(('Hair',hair,(.018,.020,.028,1)))

# Narrow the torso, hips and wrap together; move intact arms inward so their
# thickness and elbow hinges remain unchanged. Keep the round head's size.
for source in [body,shorts]+[source for _,source,_ in extras]:
    source.verts=[(x-math.copysign(1,x)*ARM_INSET if tag in (1,2) else x if tag==3 else x*BODY_WIDTH,y,z)
                  for (x,y,z),tag in zip(source.verts,source.tags)]
CENTRES=[(x-math.copysign(1,x)*ARM_INSET if i in (3,4,5,6) else x*BODY_WIDTH,y,z)
         for i,(x,y,z) in enumerate(CENTRES)]
cloth_color=(.95,.40,.39,1) if VARIANT=='woman' else (.78,.45,.06,1) if VARIANT=='child' else (.68,.23,.055,1)
objects=[]; payload=dict(variant=VARIANT,scale=.70 if VARIANT=='child' else 1.0,centres=[[x,z,-y] for x,y,z in CENTRES])
for name,source,color in [('Body',body,(.055,.065,.16,1)),('Shorts',shorts,cloth_color)]+extras:
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(source.verts,[],source.faces); mesh.update()
    ob=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(ob)
    bm=bmesh.new(); bm.from_mesh(mesh); bm.verts.ensure_lookup_table()
    layer=bm.verts.layers.int.new('part')
    for i,v in enumerate(bm.verts): v[layer]=source.tags[i]
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bmesh.ops.triangulate(bm,faces=list(bm.faces)); bm.normal_update(); bm.verts.ensure_lookup_table()
    data=dict(vertices=[],normals=[],colors=[],bones=[],weights=[],surfaces=[[],[]] if name=='Body' else [[]])
    skin_weights={}
    # Split render vertices by face for true flat normals; retain welded editable geometry.
    for f in bm.faces:
        covered=name=='Body' and (all(v[layer]==0 and .25499<=v.co.z<=.44001 for v in f.verts) or (VARIANT=='woman' and all(v[layer]==0 and v.co.z>=.48999 and v.co.z<=top_edge(v.co.x/BODY_WIDTH,v.co.y)+.00001 for v in f.verts)))
        for v in [f.verts[0],f.verts[2],f.verts[1]]:
            p=v.co; n=f.normal
            weights=sorted(binding(p,v[layer]).items(),key=lambda pair:-pair[1])[:4]
            total=sum(w for _,w in weights); weights=[(bone,w/total) for bone,w in weights]
            skin_weights[v]=weights
            data['surfaces'][int(covered)].append(len(data['vertices']))
            data['vertices'].append([p.x,p.z,-p.y]); data['normals'].append([n.x,n.z,-n.y])
            data['colors'].append([.88,.88,.88,1] if v[layer]==5 else [1,1,1,1])
            data['bones'].append([bone for bone,_ in weights]+[0]*(4-len(weights)))
            data['weights'].append([w for _,w in weights]+[0.]*(4-len(weights)))
    bm.verts.index_update()
    all_weights={v.index:weights for v,weights in skin_weights.items()}
    bm.to_mesh(mesh); bm.free()
    for polygon in mesh.polygons: polygon.use_smooth=False
    mat=bpy.data.materials.new(name); mat.diffuse_color=color; mesh.materials.append(mat)
    for bone_name in NAMES: ob.vertex_groups.new(name=bone_name)
    for index,weights in all_weights.items():
        for bone,weight in weights:
            if weight>0: ob.vertex_groups[NAMES[bone]].add([index],weight,'REPLACE')
    objects.append(ob); payload[name.lower()]=data
    print(f'{name}: {len(mesh.vertices)} welded vertices, {sum(map(len,data["surfaces"]))//3} triangles')
arm_data=bpy.data.armatures.new('Reference male rig'); arm=bpy.data.objects.new('Armature',arm_data); bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm; arm.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
for i,name in enumerate(NAMES):
    bone=arm_data.edit_bones.new(name); bone.head=CENTRES[i]; bone.tail=Vector(CENTRES[i])+Vector((0,0,.06))
    if PARENTS[i]>=0: bone.parent=arm_data.edit_bones[NAMES[PARENTS[i]]]
bpy.ops.object.mode_set(mode='OBJECT')
for ob in objects:
    modifier=ob.modifiers.new('Character rig','ARMATURE'); modifier.object=arm; ob.parent=arm
if VARIANT=='child': arm.scale=(.70,.70,.70)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(ASSET+'.blend')))
(OUT/(ASSET+'.json')).write_text(json.dumps(payload,separators=(',',':')))
print('PASS: low-poly '+VARIANT+' with independent outfit and hair')
