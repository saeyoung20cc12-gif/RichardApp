import objc
from Foundation import NSURL
import ModelIO
url = NSURL.fileURLWithPath_("/Users/mac/Documents/duck/RichardApp/RichardApp/Views/_fianlrichard.glb")
asset = ModelIO.MDLAsset.alloc().initWithURL_(url)
print("Asset loaded:", asset)
out_url = NSURL.fileURLWithPath_("/Users/mac/Documents/duck/RichardApp/RichardApp/Views/_fianlrichard.usdz")
if asset:
    print("Can export USDZ:", ModelIO.MDLAsset.canExportFileExtension_("usdz"))
    asset.exportAssetToURL_(out_url)
    print("Exported!")
