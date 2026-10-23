#!/usr/bin/env python3
"""Build a Release IPA for re-signing. Never uses a developer certificate."""
from pathlib import Path
import argparse, hashlib, plistlib, subprocess, tempfile, zipfile, shutil

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, default=root / 'dist')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='shunbox-release-') as temp:
    staging = Path(temp)
    subprocess.run(['xcodebuild', '-project', str(root/'ShunTools.xcodeproj'), '-scheme', 'ShunTools', '-configuration', 'Release', '-destination', 'generic/platform=iOS', '-derivedDataPath', str(staging/'build'), 'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'CODE_SIGN_IDENTITY=', 'DEVELOPMENT_TEAM=', 'GCC_GENERATE_DEBUGGING_SYMBOLS=NO', 'build'], check=True)
    app = staging/'Payload/ShunTools.app'
    shutil.copytree(staging/'build/Build/Products/Release-iphoneos/ShunTools.app', app)
    # Reject rather than publish any accidental provisioning profile.
    if list(app.rglob('*.mobileprovision')):
        raise RuntimeError('Refusing to package a provisioning profile')
    subprocess.run(['xattr', '-cr', str(app)], check=True)
    for path in app.rglob('*'):
        if path.is_file() and path.read_bytes()[:4] in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe'):
            subprocess.run(['codesign', '--remove-signature', str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for path in app.rglob('_CodeSignature'):
        shutil.rmtree(path)
    info = plistlib.loads((app/'Info.plist').read_bytes())
    name = f'ShunBox-{info["CFBundleShortVersionString"]}-unsigned.ipa'
    output = args.output/name
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(app.rglob('*')):
            if path.is_file() and path.name != '.DS_Store': archive.write(path, path.relative_to(staging))
    checksum = hashlib.sha256(output.read_bytes()).hexdigest()
    (args.output/'SHA256SUMS.txt').write_text(f'{checksum}  {name}\n')
    print(f'IPA requiring user signing: {output}\nSHA-256: {checksum}')
