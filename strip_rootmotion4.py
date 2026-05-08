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
    print(f"is_layered={action.is_action_layered}, is_legacy={action.is_action_legacy}")

    # Blender 5.x: 레이어 기반 Action API
    for layer in action.layers:
        print(f"Layer: {layer.name}")
        for strip in layer.strips:
            print(f"  Strip: {strip.name}, type={type(strip).__name__}")
            # KeyframeStrip에서 channelbag 접근
            if hasattr(strip, 'channels'):
                print(f"  channels: {strip.channels}")
            print(f"  strip dir: {[x for x in dir(strip) if not x.startswith('__')]}")

