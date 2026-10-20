"""Run in Blender's Scripting workspace; creates only this demo's collection.

Edit the saved .blend normally afterward. Export only the selected Crate as GLB.
Paths are relative to this saved script.
"""
import bpy
from pathlib import Path

source = Path(__file__).resolve().parent
source.mkdir(parents=True, exist_ok=True)
export_path = source.parents[1] / "assets" / "models" / "demo_crate.glb"
export_path.parent.mkdir(parents=True, exist_ok=True)

collection = bpy.data.collections.get("TemplateDemo")
if collection:
    for obj in list(collection.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
else:
    collection = bpy.data.collections.new("TemplateDemo")
    bpy.context.scene.collection.children.link(collection)

# A tiny hand-paintable base-color texture: wood planks and a dark frame.
image = bpy.data.images.get("CrateBaseColor") or bpy.data.images.new("CrateBaseColor", 64, 64)
pixels = []
for y in range(64):
    for x in range(64):
        frame = x < 5 or x >= 59 or y < 5 or y >= 59
        seam = x % 16 < 2
        grain = ((x * 7 + y * 3) % 11) / 120.0
        rgb = (0.19, 0.13, 0.09) if frame or seam else (0.43 + grain, 0.30 + grain, 0.18 + grain)
        pixels.extend((*rgb, 1.0))
image.pixels = pixels
image.filepath_raw = str(source / "crate_base_color.png")
image.file_format = "PNG"
image.save()
image.pack()
image.filepath = "//crate_base_color.png"

material = bpy.data.materials.get("CrateWood") or bpy.data.materials.new("CrateWood")
material.use_nodes = True
nodes = material.node_tree.nodes
nodes.clear()
texture = nodes.new("ShaderNodeTexImage")
texture.image = image
texture.interpolation = "Closest"
texture.location = (-300, 0)
shader = nodes.new("ShaderNodeBsdfPrincipled")
shader.inputs["Roughness"].default_value = 0.9
output = nodes.new("ShaderNodeOutputMaterial")
output.location = (320, 0)
material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])

bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.5))
crate = bpy.context.object
crate.name = "Crate"
for owner in list(crate.users_collection):
    owner.objects.unlink(crate)
collection.objects.link(crate)
crate.data.materials.append(material)
# Each face uses the entire square texture; this is intentionally easy to repaint.
uv = crate.data.uv_layers.active
for face in crate.data.polygons:
    for i, loop in enumerate(face.loop_indices):
        uv.data[loop].uv = ((0, 0), (1, 0), (1, 1), (0, 1))[i]

for obj in bpy.context.selected_objects:
    obj.select_set(False)
crate.select_set(True)
bpy.context.view_layer.objects.active = crate
bpy.ops.wm.save_as_mainfile(filepath=str(source / "demo_crate.blend"))
bpy.ops.export_scene.gltf(filepath=str(export_path), export_format="GLB", use_selection=True)
print("Template crate saved and exported:", export_path)
