import bpy

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath="/Users/mac/Downloads/Meshy_AI_Meshy_Merged_Animations.glb")

armature_obj = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        armature_obj = obj
        break

if armature_obj and armature_obj.animation_data and armature_obj.animation_data.action:
    action = armature_obj.animation_data.action
    print(f"Action: {action.name}, type={type(action)}")
    print(f"Action dir: {[x for x in dir(action) if not x.startswith('__')]}")

