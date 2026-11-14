#!/bin/bash
# 编译 RightClick（宿主 App + Finder 同步扩展）并签名打包。
# 用法：
#   bash build.sh                                                   # ad-hoc 签名（仅自测，扩展无法被系统注册）
#   CODE_SIGN_IDENTITY="Apple Development: 你的名字 (TEAMID)" bash build.sh   # 正式签名
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
TARGET="arm64-apple-macosx15.0"

BUILD="$ROOT/build"
APP="$BUILD/RightClick.app"
APPEX="$APP/Contents/PlugIns/RightClickFinder.appex"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APPEX/Contents/MacOS"

echo "==> 编译扩展（Finder Sync）"
swiftc -emit-executable -parse-as-library -application-extension \
  -module-name FinderSyncExt \
  -target "$TARGET" -sdk "$SDK" \
  "$ROOT/FinderSyncExt/FinderSync.swift" "$ROOT/FinderSyncExt/main.m" \
  -framework FinderSync -framework Cocoa \
  -o "$APPEX/Contents/MacOS/RightClickFinder"

echo "==> 编译宿主 App"
swiftc -emit-executable \
  -target "$TARGET" -sdk "$SDK" \
  "$ROOT/RightClick/main.swift" \
  -framework Cocoa \
  -o "$APP/Contents/MacOS/RightClick"

echo "==> 写入 Info.plist"
cp "$ROOT/Info-RightClick.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Info-FinderSyncExt.plist" "$APPEX/Contents/Info.plist"

echo "==> 复制模板到扩展 Resources"
mkdir -p "$APPEX/Contents/Resources"
for f in Word.docx Excel.xlsx PPT.pptx TXT.txt Markdown.md XML.xml RTF.rtf; do
  cp "$ROOT/Templates/$f" "$APPEX/Contents/Resources/"
done
# Office 模板可能带扩展属性，签名前必须清理，否则 codesign 拒绝
xattr -cr "$APPEX/Contents/Resources/"

# 临时例外 entitlement 需要当前用户主目录的绝对路径，
# 构建时从模板生成，避免把个人路径写死进仓库。
ENT_TMP="$BUILD/FinderSync.entitlements"
sed "s|__HOME__|$HOME|g" "$ROOT/FinderSync.entitlements.template" > "$ENT_TMP"

# 默认 ad-hoc（-）；有开发者证书时用 CODE_SIGN_IDENTITY 传入身份
IDENTITY="${CODE_SIGN_IDENTITY:--}"
echo "==> 签名（身份: $IDENTITY，先签扩展，再签宿主）"
codesign --force --sign "$IDENTITY" --entitlements "$ENT_TMP" "$APPEX"
codesign --force --sign "$IDENTITY" --entitlements "$ROOT/RightClick.entitlements" "$APP"

echo "==> 完成：$APP"
codesign --verify --verbose=2 "$APP" 2>&1 | tail -2
