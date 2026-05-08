import bpy

# 기존 오브젝트 삭제
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# GLB 임포트
bpy.ops.import_scene.gltf(filepath="/Users/mac/Downloads/Meshy_AI_Meshy_Merged_Animations.glb")

# Armature 찾기
armature_obj = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        armature_obj = obj
        break

if armature_obj and armature_obj.animation_data and armature_obj.animation_data.action:
    action = armature_obj.animation_data.action
    print(f"Action found: {action.name}, fcurves: {len(action.fcurves)}")

    for fcurve in action.fcurves:
        # Hips 뼈의 location 채널만 처리
        if 'Hips' in fcurve.data_path and 'location' in fcurve.data_path:
            print(f"  Hips location axis={fcurve.array_index}, keyframes={len(fcurve.keyframe_points)}")
            # Blender 기준 X(0), Y(1) = 앞뒤/좌우 루트 모션 제거
            # Z(2) = 위아래 바운스 → 유지
            if fcurve.array_index in [0, 1]:
                # 첫 프레임 값(기준 위치)으로 모든 키프레임 고정
                first_val = fcurve.keyframe_points[0].co.y
                for kp in fcurve.keyframe_points:
                    kp.co.y = first_val
                    kp.handle_left.y = first_val
                    kp.handle_right.y = first_val
                print(f"    -> Root motion removed (fixed to {first_val:.3f})")
else:
    print("No animation found on armature")

# USDZ로 내보내기 (애니메이션 포함)
out_path = "/Users/mac/Documents/duck/RichardApp/RichardApp/Views/anima_richard.usdz"
bpy.ops.wm.usd_export(
    filepath=out_path,
    export_animation=True,
    export_materials=True
)
print(f"DONE: {out_path}")
