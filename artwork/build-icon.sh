#!/bin/bash
# 用苹果自己的管线渲染 OwnGoal.icon：
#   actool 编译 .icon → 装进临时 .app → 系统 IconServices 按 1024 渲染 → stripe-icon.png
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/owngoal-icon.XXXXXX")"
trap 'lsregister -u "$WORK/OwnGoal.app" >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT
lsregister() { /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister "$@"; }

APP="$WORK/OwnGoal.app/Contents"
mkdir -p "$APP/Resources" "$APP/MacOS"
xcrun actool "$HERE/OwnGoal.icon" --compile "$APP/Resources" --platform macosx \
  --minimum-deployment-target 26.0 --app-icon OwnGoal --target-device mac \
  --output-partial-info-plist "$WORK/partial.plist" >/dev/null
cat > "$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.owngoal.iconpreview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>OwnGoal</string>
<key>CFBundleIconName</key><string>OwnGoal</string>
<key>CFBundleIconFile</key><string>OwnGoal</string>
</dict></plist>
PLIST
printf '#!/bin/sh\n' > "$APP/MacOS/OwnGoal" && chmod +x "$APP/MacOS/OwnGoal"

cat > "$WORK/export.swift" <<'SWIFT'
import AppKit
let a = CommandLine.arguments
let icon = NSWorkspace.shared.icon(forFile: a[1])
let px = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
icon.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
SWIFT
swiftc -O "$WORK/export.swift" -o "$WORK/export"
"$WORK/export" "$WORK/OwnGoal.app" "$HERE/stripe-icon.png"
echo "wrote $HERE/stripe-icon.png"

# 无圆角方形版：ictool 导出时总会套上圆角遮罩，所以把图层缩到 2/3，
# 按 1536 导出再居中裁 1024，圆角和边缘反光都落在裁掉的部分
ICTOOL="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
cp -R "$HERE/OwnGoal.icon" "$WORK/square.icon"
python3 -I - "$WORK/square.icon/icon.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
for g in d["groups"]:
    for l in g["layers"]:
        l["position"] = {"scale": 1 / 1.5, "translation-in-points": [0, 0]}
json.dump(d, open(p, "w"), indent=2)
PY
"$ICTOOL" "$WORK/square.icon" --export-image --output-file "$WORK/big.png" --platform iOS \
  --rendition Default --width 1536 --height 1536 --scale 1 >/dev/null
sips -c 1024 1024 "$WORK/big.png" --out "$HERE/stripe-icon-square.png" >/dev/null
echo "wrote $HERE/stripe-icon-square.png"

# 软件源图标：方形版缩到 256，由 publish_repo.py 放到源根目录和 dists/<suite>
sips -Z 256 "$HERE/stripe-icon-square.png" --out "$HERE/../build_misc/repository/CydiaIcon.png" >/dev/null
echo "wrote build_misc/repository/CydiaIcon.png"
