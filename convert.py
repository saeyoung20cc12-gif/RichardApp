import bpy
import sys

# Clear existing objects
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# Import GLB
bpy.ops.import_scene.gltf(filepath="/Users/mac/Downloads/Meshy_AI_Meshy_Merged_Animations.glb")

# Export USDZ
bpy.ops.wm.usd_export(
    filepath="/Users/mac/Documents/duck/RichardApp/RichardApp/Views/anima_richard.usdz",
    export_animation=True,
    export_materials=True
)
print("USDZ EXPORT COMPLETE")
