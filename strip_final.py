import bpy

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath="/Users/mac/Downloads/Meshy_AI_Meshy_Merged_Animations.glb")

armature_obj = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
action = armature_obj.animation_data.action

strip = action.layers[0].strips[0]
slot = action.slots[0]

# channelbag: 특정 슬롯의 채널 묶음
channelbag = strip.channelbag(slot)

fixed = 0
for fcurve in channelbag.fcurves:
    if 'Hips' in fcurve.data_path and 'location' in fcurve.data_path:
        print(f"  Hips location axis={fcurve.array_index}, kf={len(fcurve.keyframe_points)}")
        # Blender Z-up: axis 0=X(좌우), axis 1=Y(앞뒤=루트모션), axis 2=Z(위아래)
        # 앞뒤(1)와 좌우(0) 루트모션 제거, 위아래(2) bounce는 유지
        if fcurve.array_index in [0, 1]:
            first_val = fcurve.keyframe_points[0].co.y
            for kp in fcurve.keyframe_points:
                kp.co.y = first_val
                kp.handle_left.y = first_val
                kp.handle_right.y = first_val
            fixed += 1
            print(f"    -> Stripped (fixed to {first_val:.4f})")

print(f"Root motion stripped from {fixed} fcurves")

out_path = "/Users/mac/Documents/duck/RichardApp/RichardApp/Views/anima_richard.usdz"
bpy.ops.wm.usd_export(filepath=out_path, export_animation=True, export_materials=True)
print(f"DONE → {out_path}")
