import bpy

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

bpy.ops.import_scene.gltf(filepath="/Users/mac/Downloads/Meshy_AI_Meshy_Merged_Animations.glb")

# Blender 5.x에서 Action.fcurves → Action.layers[].strips[].channelbag 구조로 변경됨
armature_obj = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        armature_obj = obj
        break

print(f"Armature: {armature_obj}")

if armature_obj and armature_obj.animation_data and armature_obj.animation_data.action:
    action = armature_obj.animation_data.action
    print(f"Action: {action.name}")

    # Blender 5.x NLA/Action API
    if hasattr(action, 'fcurves'):
        fcurves = action.fcurves
    else:
        # Blender 5.x 슬롯/레이어 구조
        fcurves = []
        for layer in action.layers:
            for strip in layer.strips:
                if hasattr(strip, 'channelbag'):
                    for cb in strip.channelbag_for_slot_get(action.slots[0]) if action.slots else []:
                        fcurves.extend(cb.fcurves)

    print(f"fcurves count: {len(fcurves)}")
    for fcurve in fcurves:
        if 'Hips' in fcurve.data_path and 'location' in fcurve.data_path:
            print(f"  Hips location axis={fcurve.array_index}")
            if fcurve.array_index in [0, 1]:
                first_val = fcurve.keyframe_points[0].co.y
                for kp in fcurve.keyframe_points:
                    kp.co.y = first_val
                    kp.handle_left.y = first_val
                    kp.handle_right.y = first_val
                print(f"    -> Fixed to {first_val:.3f}")

out_path = "/Users/mac/Documents/duck/RichardApp/RichardApp/Views/anima_richard.usdz"
bpy.ops.wm.usd_export(filepath=out_path, export_animation=True, export_materials=True)
print(f"DONE: {out_path}")
