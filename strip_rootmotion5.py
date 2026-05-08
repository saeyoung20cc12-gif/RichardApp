import bpy

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath="/Users/mac/Downloads/Meshy_AI_Meshy_Merged_Animations.glb")

armature_obj = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
action = armature_obj.animation_data.action

layer = action.layers[0]
strip = layer.strips[0]
print(f"Strip dir: {[x for x in dir(strip) if not x.startswith('__')]}")
print(f"Slots: {[s.name for s in action.slots]}")
