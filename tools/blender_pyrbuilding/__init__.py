"""Blender import/export extension for Town Building blueprints."""

from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from bpy.props import StringProperty
from bpy.types import Operator, Panel
from bpy_extras.io_utils import ExportHelper, ImportHelper
from mathutils import Euler, Matrix, Vector

from . import pyrbuilding_codec as codec

bl_info = {
    "name": "Town Building Blueprint",
    "author": "Town contributors",
    "version": (0, 1, 0),
    "blender": (4, 2, 0),
    "location": "File > Import-Export",
    "description": "Round-trip Town .pyrbuilding construction assets",
    "category": "Import-Export",
}

COLLECTION_FORMAT_KEY = "pyrbuilding_format"
PART_ID_KEY = "pyr_part_id"
COORDINATE_CHANGE = Matrix(((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0)))


def _json_property(value) -> str:
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False, allow_nan=False)


def _read_json_property(owner, key: str, fallback):
    try:
        return json.loads(str(owner.get(key, _json_property(fallback))))
    except (TypeError, ValueError, json.JSONDecodeError):
        return fallback


def _pyr_vector(value) -> Vector:
    return Vector(codec.pyramida_to_blender(value))


def _to_pyr_vector(value: Vector) -> list[float]:
    return [round(component, 6) for component in codec.blender_to_pyramida(value)]


def _pyr_rotation_to_blender(rotation_degrees) -> Matrix:
    source_rotation = Euler(
        tuple(math.radians(float(value)) for value in rotation_degrees), "XYZ"
    ).to_matrix()
    return COORDINATE_CHANGE @ source_rotation @ COORDINATE_CHANGE.inverted()


def _blender_rotation_to_pyr(rotation_matrix: Matrix) -> list[float]:
    source_rotation = COORDINATE_CHANGE.inverted() @ rotation_matrix @ COORDINATE_CHANGE
    return [round(math.degrees(value), 6) for value in source_rotation.to_euler("XYZ")]


def _unit_box_mesh(name: str):
    vertices = [
        (-0.5, -0.5, -0.5), (-0.5, -0.5, 0.5),
        (-0.5, 0.5, -0.5), (-0.5, 0.5, 0.5),
        (0.5, -0.5, -0.5), (0.5, -0.5, 0.5),
        (0.5, 0.5, -0.5), (0.5, 0.5, 0.5),
    ]
    faces = [
        (0, 4, 6, 2), (1, 3, 7, 5), (0, 1, 5, 4),
        (2, 6, 7, 3), (0, 2, 3, 1), (4, 5, 7, 6),
    ]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    return mesh


def _log_mesh(name: str, length: float, start_radius: float, end_radius: float, sides: int):
    sides = max(3, min(int(sides), 16))
    half_length = length * 0.5
    vertices = []
    for z_value, radius in ((-half_length, start_radius), (half_length, end_radius)):
        for side in range(sides):
            angle = math.tau * side / sides
            vertices.append((math.cos(angle) * radius, math.sin(angle) * radius, z_value))
    faces = []
    for side in range(sides):
        next_side = (side + 1) % sides
        faces.append((side, next_side, sides + next_side, sides + side))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple(range(sides, sides * 2)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    return mesh


def _octahedron_mesh(name: str, radius: float, height: float):
    half_height = height * 0.5
    vertices = [
        (0.0, 0.0, half_height),
        (radius, 0.0, 0.0), (0.0, radius, 0.0),
        (-radius, 0.0, 0.0), (0.0, -radius, 0.0),
        (0.0, 0.0, -half_height),
    ]
    faces = [
        (0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1),
        (5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4),
    ]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    return mesh


def _material(material_id: str):
    name = f"Town | {material_id}"
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = codec.MATERIAL_COLOURS.get(material_id, (0.5, 0.5, 0.5, 1.0))
    material.roughness = 0.92
    return material


def _part_object(part: dict):
    geometry = part.get("geometry", {})
    primitive = geometry.get("primitive", "log" if part.get("kind") == "log" else "box")
    part_id = str(part["id"])
    if primitive == "log":
        start = _pyr_vector(geometry.get("start", (0.0, 0.0, 0.0)))
        end = _pyr_vector(geometry.get("end", (0.0, 0.5, 0.0)))
        direction = end - start
        length = direction.length
        if length <= 1.0e-7:
            raise ValueError(f"Log {part_id} has identical endpoints")
        mesh = _log_mesh(
            part_id, length,
            float(geometry.get("start_radius", 0.085)),
            float(geometry.get("end_radius", 0.075)),
            int(geometry.get("sides", 6)),
        )
        obj = bpy.data.objects.new(part_id, mesh)
        obj.location = (start + end) * 0.5
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized())
        obj["pyr_log_half_length"] = length * 0.5
        obj["pyr_start_radius"] = float(geometry.get("start_radius", 0.085))
        obj["pyr_end_radius"] = float(geometry.get("end_radius", 0.075))
        obj["pyr_sides"] = int(geometry.get("sides", 6))
    elif primitive == "sphere":
        radius = float(geometry.get("radius", 0.11))
        height = float(geometry.get("height", radius * 1.5))
        obj = bpy.data.objects.new(part_id, _octahedron_mesh(part_id, radius, height))
        obj.location = _pyr_vector(geometry.get("centre", (0.0, 0.0, 0.0)))
        scale = geometry.get("scale", (1.0, 1.0, 1.0))
        obj.scale = (float(scale[0]), float(scale[2]), float(scale[1]))
        obj.rotation_mode = "XYZ"
        obj.rotation_euler = _pyr_rotation_to_blender(
            geometry.get("rotation_degrees", (0.0, 0.0, 0.0))
        ).to_euler("XYZ")
        obj["pyr_sphere_radius"] = radius
        obj["pyr_sphere_height"] = height
        obj["pyr_sides"] = int(geometry.get("sides", 7))
    else:
        obj = bpy.data.objects.new(part_id, _unit_box_mesh(part_id))
        obj.location = _pyr_vector(geometry.get("centre", (0.0, 0.0, 0.0)))
        size = geometry.get("size", (0.46, 0.46, 0.46))
        obj.scale = (float(size[0]), float(size[2]), float(size[1]))
        obj.rotation_mode = "XYZ"
        obj.rotation_euler = _pyr_rotation_to_blender(
            geometry.get("rotation_degrees", (0.0, 0.0, 0.0))
        ).to_euler("XYZ")

    obj.data.materials.append(_material(str(part.get("material", "wood"))))
    obj[PART_ID_KEY] = part_id
    obj["pyr_kind"] = str(part.get("kind", "block"))
    obj["pyr_material"] = str(part.get("material", "wood"))
    obj["pyr_resource"] = str(part.get("resource", ""))
    obj["pyr_orientation"] = str(part.get("orientation", "x"))
    obj["pyr_visual_variant"] = int(part.get("visual_variant", 0))
    obj["pyr_decorative"] = bool(part.get("decorative", False))
    obj["pyr_primitive"] = str(primitive)
    obj["pyr_part_order"] = int(part.get("_import_order", 0))
    sub_unit = [int(value) for value in part.get("sub_unit", (0, 0, 0))]
    obj["pyr_sub_unit"] = sub_unit
    reference = codec.geometry_reference(part)
    sub_centre = codec.sub_unit_centre(sub_unit)
    offset = tuple(reference[index] - sub_centre[index] for index in range(3))
    obj["pyr_anchor_offset"] = list(codec.pyramida_to_blender(offset))
    return obj


def import_blueprint(filepath: str, context):
    blueprint = codec.load_blueprint(filepath)
    collection = bpy.data.collections.new(f"Town | {blueprint.get('display_name', blueprint['id'])}")
    context.scene.collection.children.link(collection)
    collection[COLLECTION_FORMAT_KEY] = codec.FORMAT_ID
    collection["pyr_source_path"] = str(Path(filepath).resolve())
    collection["pyr_id"] = str(blueprint["id"])
    collection["pyr_display_name"] = str(blueprint.get("display_name", blueprint["id"]))
    collection["pyr_bounds_world_units"] = [int(value) for value in blueprint["bounds_world_units"]]
    collection["pyr_recipe_mode"] = str(blueprint.get("recipe_mode", "derived"))
    collection["pyr_recipe"] = _json_property(blueprint.get("recipe", {}))
    collection["pyr_workshop_recipes"] = _json_property(blueprint.get("workshop_recipes", []))
    for part_index, source_part in enumerate(blueprint["parts"]):
        part = dict(source_part)
        part["_import_order"] = part_index
        collection.objects.link(_part_object(part))
    return collection


def _blueprint_collection(context):
    active = context.view_layer.objects.active
    if active is not None:
        for collection in active.users_collection:
            if collection.get(COLLECTION_FORMAT_KEY) == codec.FORMAT_ID:
                return collection
    candidates = [
        collection for collection in bpy.data.collections
        if collection.get(COLLECTION_FORMAT_KEY) == codec.FORMAT_ID
    ]
    if len(candidates) == 1:
        return candidates[0]
    raise ValueError("Select one object belonging to the Town Building you want to export")


def _local_dimensions(obj) -> Vector:
    corners = [Vector(corner) for corner in obj.bound_box]
    minimum = Vector(tuple(min(corner[axis] for corner in corners) for axis in range(3)))
    maximum = Vector(tuple(max(corner[axis] for corner in corners) for axis in range(3)))
    scale = obj.matrix_world.to_scale()
    return Vector(tuple((maximum[axis] - minimum[axis]) * abs(scale[axis]) for axis in range(3)))


def _export_geometry(obj, primitive: str) -> dict:
    location, rotation, scale = obj.matrix_world.decompose()
    if primitive == "log":
        half_length = float(obj.get("pyr_log_half_length", 0.25))
        start = obj.matrix_world @ Vector((0.0, 0.0, -half_length))
        end = obj.matrix_world @ Vector((0.0, 0.0, half_length))
        radius_scale = (abs(scale.x) + abs(scale.y)) * 0.5
        return {
            "primitive": "log",
            "start": _to_pyr_vector(start),
            "end": _to_pyr_vector(end),
            "start_radius": round(float(obj.get("pyr_start_radius", 0.085)) * radius_scale, 6),
            "end_radius": round(float(obj.get("pyr_end_radius", 0.075)) * radius_scale, 6),
            "sides": int(obj.get("pyr_sides", 6)),
        }
    rotation_matrix = rotation.to_matrix()
    if primitive == "sphere":
        base_radius = float(obj.get("pyr_sphere_radius", 0.11))
        base_height = float(obj.get("pyr_sphere_height", base_radius * 1.5))
        return {
            "primitive": "sphere",
            "centre": _to_pyr_vector(location),
            "radius": base_radius,
            "height": base_height,
            "scale": [round(abs(scale.x), 6), round(abs(scale.z), 6), round(abs(scale.y), 6)],
            "rotation_degrees": _blender_rotation_to_pyr(rotation_matrix),
            "sides": int(obj.get("pyr_sides", 7)),
        }
    dimensions = _local_dimensions(obj)
    return {
        "primitive": "box",
        "centre": _to_pyr_vector(location),
        "size": [round(dimensions.x, 6), round(dimensions.z, 6), round(dimensions.y, 6)],
        "rotation_degrees": _blender_rotation_to_pyr(rotation_matrix),
    }


def _part_from_object(obj, bounds) -> dict:
    primitive = str(obj.get("pyr_primitive", "box"))
    geometry = _export_geometry(obj, primitive)
    reference = codec.geometry_reference({"kind": obj.get("pyr_kind", "block"), "geometry": geometry})
    anchor_offset = codec.blender_to_pyramida(obj.get("pyr_anchor_offset", (0.0, 0.0, 0.0)))
    anchor = tuple(reference[index] - anchor_offset[index] for index in range(3))
    sub_unit = codec.nearest_sub_unit(anchor, bounds)
    obj["pyr_sub_unit"] = sub_unit
    return {
        "id": str(obj[PART_ID_KEY]),
        "kind": str(obj.get("pyr_kind", "block")),
        "material": str(obj.get("pyr_material", "wood")),
        "resource": str(obj.get("pyr_resource", "")),
        "decorative": bool(obj.get("pyr_decorative", False)),
        "sub_unit": sub_unit,
        "orientation": str(obj.get("pyr_orientation", "x")),
        "visual_variant": int(obj.get("pyr_visual_variant", 0)),
        "geometry": geometry,
    }


def export_blueprint(filepath: str, context):
    collection = _blueprint_collection(context)
    bounds = [int(value) for value in collection["pyr_bounds_world_units"]]
    part_objects = [obj for obj in collection.all_objects if PART_ID_KEY in obj]
    part_objects.sort(key=lambda obj: (int(obj.get("pyr_part_order", 0)), str(obj[PART_ID_KEY])))
    blueprint = {
        "format": codec.FORMAT_ID,
        "format_version": 2,
        "id": str(collection["pyr_id"]),
        "display_name": str(collection["pyr_display_name"]),
        "bounds_world_units": bounds,
        "recipe_mode": str(collection.get("pyr_recipe_mode", "derived")),
        "parts": [_part_from_object(obj, bounds) for obj in part_objects],
    }
    if blueprint["recipe_mode"] == "explicit":
        blueprint["recipe"] = _read_json_property(collection, "pyr_recipe", {})
    workshop_recipes = _read_json_property(collection, "pyr_workshop_recipes", [])
    if workshop_recipes:
        blueprint["workshop_recipes"] = workshop_recipes
    codec.write_blueprint(filepath, blueprint)
    collection["pyr_source_path"] = str(Path(filepath).resolve())
    return blueprint


class PYRAMIDA_OT_import_building(Operator, ImportHelper):
    bl_idname = "import_scene.pyrbuilding"
    bl_label = "Import Town Building"
    bl_options = {"REGISTER", "UNDO"}
    filename_ext = ".pyrbuilding"
    filter_glob: StringProperty(default="*.pyrbuilding", options={"HIDDEN"})

    def execute(self, context):
        try:
            collection = import_blueprint(self.filepath, context)
            self.report({"INFO"}, f"Imported {len(collection.objects)} Town Building parts")
            return {"FINISHED"}
        except Exception as error:
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}


class PYRAMIDA_OT_export_building(Operator, ExportHelper):
    bl_idname = "export_scene.pyrbuilding"
    bl_label = "Export Town Building"
    filename_ext = ".pyrbuilding"
    filter_glob: StringProperty(default="*.pyrbuilding", options={"HIDDEN"})

    def execute(self, context):
        try:
            blueprint = export_blueprint(self.filepath, context)
            self.report({"INFO"}, f"Exported {len(blueprint['parts'])} Town Building parts")
            return {"FINISHED"}
        except Exception as error:
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}


class PYRAMIDA_OT_snap_parts(Operator):
    bl_idname = "object.pyrbuilding_snap_parts"
    bl_label = "Snap Town Parts to Sub-Units"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        moved = 0
        for obj in context.selected_objects:
            if PART_ID_KEY not in obj:
                continue
            collection = next(
                (value for value in obj.users_collection if value.get(COLLECTION_FORMAT_KEY) == codec.FORMAT_ID),
                None,
            )
            if collection is None:
                continue
            bounds = [int(value) for value in collection["pyr_bounds_world_units"]]
            offset = Vector(obj.get("pyr_anchor_offset", (0.0, 0.0, 0.0)))
            anchor = obj.location - offset
            sub_unit = codec.nearest_sub_unit(codec.blender_to_pyramida(anchor), bounds)
            snapped_anchor = _pyr_vector(codec.sub_unit_centre(sub_unit))
            obj.location += snapped_anchor - anchor
            obj["pyr_sub_unit"] = sub_unit
            moved += 1
        self.report({"INFO"}, f"Snapped {moved} Town Building parts")
        return {"FINISHED"}


class PYRAMIDA_PT_building(Panel):
    bl_label = "Town Building"
    bl_idname = "PYRAMIDA_PT_building"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Town"

    def draw(self, context):
        layout = self.layout
        obj = context.object
        if obj is None or PART_ID_KEY not in obj:
            layout.label(text="Select an imported Building part")
            return
        layout.label(text=f"Part: {obj[PART_ID_KEY]}")
        layout.label(text=f"Kind: {obj.get('pyr_kind', 'block')}")
        layout.label(text=f"Sub-Unit: {list(obj.get('pyr_sub_unit', (0, 0, 0)))}")
        layout.operator(PYRAMIDA_OT_snap_parts.bl_idname)


def _menu_import(self, _context):
    self.layout.operator(PYRAMIDA_OT_import_building.bl_idname, text="Town Building (.pyrbuilding)")


def _menu_export(self, _context):
    self.layout.operator(PYRAMIDA_OT_export_building.bl_idname, text="Town Building (.pyrbuilding)")


CLASSES = (
    PYRAMIDA_OT_import_building,
    PYRAMIDA_OT_export_building,
    PYRAMIDA_OT_snap_parts,
    PYRAMIDA_PT_building,
)


def register():
    for class_type in CLASSES:
        bpy.utils.register_class(class_type)
    bpy.types.TOPBAR_MT_file_import.append(_menu_import)
    bpy.types.TOPBAR_MT_file_export.append(_menu_export)


def unregister():
    bpy.types.TOPBAR_MT_file_export.remove(_menu_export)
    bpy.types.TOPBAR_MT_file_import.remove(_menu_import)
    for class_type in reversed(CLASSES):
        bpy.utils.unregister_class(class_type)
