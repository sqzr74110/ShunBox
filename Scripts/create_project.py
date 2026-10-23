from pathlib import Path
import hashlib
root=Path(__file__).resolve().parent.parent
objects={}
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def add(key,body): objects[uid(key)]=body; return uid(key)
products=[]; targets=[]; groups=[]
for name,folder,kind in [('ShunTools','ShunTools','application'),('ShunToolsTests','ShunToolsTests','bundle.unit-test'),('ShunToolsUITests','ShunToolsUITests','bundle.ui-testing')]:
    files=[]; builds=[]
    for file in sorted((root/folder).rglob('*.swift')):
        path=str(file.relative_to(root))
        ref=add(path, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = SOURCE_ROOT;')
        build=add('build'+path,f'isa = PBXBuildFile; fileRef = {ref};'); files.append(ref); builds.append(build)
    resourceBuilds=[]
    if name=='ShunTools':
        asset=add('asset', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = ShunTools/Resources/Assets.xcassets; sourceTree = SOURCE_ROOT;')
        files.append(asset)
        resourceBuilds.append(add('assetbuild', f'isa = PBXBuildFile; fileRef = {asset};'))
        for file in sorted((root/'ShunTools/Resources').glob('*.xcstrings')):
            path=str(file.relative_to(root));ref=add(path,f'isa = PBXFileReference; lastKnownFileType = text.json.xcstrings; path = "{path}"; sourceTree = SOURCE_ROOT;')
            files.append(ref);resourceBuilds.append(add('build'+path,f'isa = PBXBuildFile; fileRef = {ref};'))
        localized=[]
        for folder in sorted((root/'ShunTools/Resources').glob('*.lproj')):
            path=str((folder/'InfoPlist.strings').relative_to(root));code=folder.stem
            localized.append(add(path,f'isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = "{code}"; path = "{path}"; sourceTree = SOURCE_ROOT;'))
        variant=add('infostrings',f'isa = PBXVariantGroup; children = ({",".join(localized)},); name = InfoPlist.strings; sourceTree = "<group>";')
        files.append(variant);resourceBuilds.append(add('infostringsbuild',f'isa = PBXBuildFile; fileRef = {variant};'))
        privacy=add('privacy','isa = PBXFileReference; lastKnownFileType = text.xml; path = ShunTools/Resources/PrivacyInfo.xcprivacy; sourceTree = SOURCE_ROOT;')
        files.append(privacy);resourceBuilds.append(add('privacybuild',f'isa = PBXBuildFile; fileRef = {privacy};'))

    if name == 'ShunToolsTests':
        config=add('storekittest','isa = PBXFileReference; lastKnownFileType = text; path = ShunBox.storekit; sourceTree = SOURCE_ROOT;')
        files.append(config);resourceBuilds.append(add('storekittestbuild',f'isa = PBXBuildFile; fileRef = {config};'))
    resources=add('resources'+name, f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resourceBuilds)}{"," if resourceBuilds else ""}); runOnlyForDeploymentPostprocessing = 0;')
    group=add('group'+name,f'isa = PBXGroup; children = ({",".join(files)}{"," if files else ""}); name = {name}; sourceTree = "<group>";'); groups.append(group)
    ext='app' if kind=='application' else 'xctest'
    product=add('product'+name,f'isa = PBXFileReference; explicitFileType = {"wrapper.application" if ext=="app" else "wrapper.cfbundle"}; path = {name}.{ext}; sourceTree = BUILT_PRODUCTS_DIR;'); products.append(product)
    sources=add('sources'+name,f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)}{"," if builds else ""}); runOnlyForDeploymentPostprocessing = 0;')
    configs=[]
    for mode in ['Debug','Release']:
        settings='CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; GENERATE_INFOPLIST_FILE = YES; IPHONEOS_DEPLOYMENT_TARGET = 26.0; MARKETING_VERSION = 0.1.0; PRODUCT_NAME = "$(TARGET_NAME)"; SDKROOT = iphoneos; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; '
        settings+=f'PRODUCT_BUNDLE_IDENTIFIER = com.shuntools.{name}; '
        if name=='ShunTools': settings+='ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor; INFOPLIST_KEY_CFBundleDisplayName = "顺匣"; INFOPLIST_KEY_NSMicrophoneUsageDescription = "仅在你开始麦克风自检时录音，用于本机回放。"; INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription = "将处理后的图片保存到你的相册。"; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"; '
        elif name=='ShunToolsTests': settings+='TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ShunTools.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ShunTools"; BUNDLE_LOADER = "$(TEST_HOST)"; '
        else: settings+='TEST_TARGET_NAME = ShunTools; '
        settings+='SWIFT_OPTIMIZATION_LEVEL = '+('"-Onone"; ENABLE_TESTABILITY = YES; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG SIDELOAD"; DEBUG_INFORMATION_FORMAT = dwarf; ' if mode=='Debug' else '"-O"; SWIFT_ACTIVE_COMPILATION_CONDITIONS = SIDELOAD; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; ')
        configs.append(add(name+mode,f'isa = XCBuildConfiguration; buildSettings = {{{settings}}}; name = {mode};'))
    configlist=add('configs'+name,f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    deps=[]
    if name!='ShunTools':
        proxy=add('proxy'+name,f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("targetShunTools")}; remoteInfo = ShunTools;')
        deps.append(add('dep'+name,f'isa = PBXTargetDependency; target = {uid("targetShunTools")}; targetProxy = {proxy};'))
    targets.append(add('target'+name,f'isa = PBXNativeTarget; buildConfigurationList = {configlist}; buildPhases = ({sources},{resources},); buildRules = (); dependencies = ({",".join(deps)}{"," if deps else ""}); name = {name}; productName = {name}; productReference = {product}; productType = "com.apple.product-type.{kind}";'))
pg=add('products',f'isa = PBXGroup; children = ({",".join(products)},); name = Products; sourceTree = "<group>";')
main=add('main',f'isa = PBXGroup; children = ({",".join(groups+[pg])},); sourceTree = "<group>";')
cs=[add('project'+mode,f'isa = XCBuildConfiguration; buildSettings = {{CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0;}}; name = {mode};') for mode in ['Debug','Release']]
cl=add('projectconfigs',f'isa = XCConfigurationList; buildConfigurations = ({",".join(cs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
add('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2710; }}; buildConfigurationList = {cl}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh-Hans; hasScannedForEncodings = 0; knownRegions = ("zh-Hans", "zh-Hant", en, ja, ko, fr, de, es, "pt-BR", Base); mainGroup = {main}; productRefGroup = {pg}; projectDirPath = ""; projectRoot = ""; targets = ({",".join(targets)},);')
(root/'ShunTools.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+''.join(f'{key} = {{{value}}};\n' for key,value in objects.items())+'}; rootObject = '+uid('project')+'; }\n')
def ref(name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target"+name)}" BuildableName="{name}.{"app" if name=="ShunTools" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:ShunTools.xcodeproj"/>'
(root/'ShunTools.xcodeproj/xcshareddata/xcschemes/ShunTools.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2710" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref('ShunTools')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB"><Testables><TestableReference skipped="NO">{ref('ShunToolsTests')}</TestableReference><TestableReference skipped="NO">{ref('ShunToolsUITests')}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('ShunTools')}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('ShunTools')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
