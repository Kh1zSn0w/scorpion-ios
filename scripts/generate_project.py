#!/usr/bin/env python3
"""Generate a deterministic Xcode project using only Python's standard library."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def ident(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def quote(value):
    return json.dumps(str(value))

objects = []
def obj(name, content):
    objects.append(f'{ident(name)} = {{ {content} }};')
    return ident(name)

sources = sorted((ROOT / 'Scorpion').glob('*.swift'))
resources = [ROOT / 'Scorpion' / name for name in ('Mascot.js', 'scorpion.png', 'Assets.xcassets')]
refs, source_builds, resource_builds = [], [], []
for path in sources + resources:
    name = path.relative_to(ROOT).as_posix()
    kind = 'sourcecode.swift' if path.suffix == '.swift' else ('folder.assetcatalog' if path.suffix == '.xcassets' else ('image.png' if path.suffix == '.png' else 'sourcecode.javascript'))
    reference = obj('ref:' + name, f'isa = PBXFileReference; lastKnownFileType = {quote(kind)}; path = {quote(name)}; sourceTree = "<group>";')
    refs.append(reference)
    build = obj('build:' + name, f'isa = PBXBuildFile; fileRef = {reference};')
    (source_builds if path.suffix == '.swift' else resource_builds).append(build)

app = obj('app', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Scorpion.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = ({app},); name = Products; sourceTree = "<group>";')
obj('group', f'isa = PBXGroup; children = ({",".join(refs + [products])},); sourceTree = "<group>";')
obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(source_builds)},); runOnlyForDeploymentPostprocessing = 0;')
obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resource_builds)},); runOnlyForDeploymentPostprocessing = 0;')
obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')

for mode in ('Debug', 'Release'):
    project_settings = 'CLANG_ENABLE_MODULES = YES; IPHONEOS_DEPLOYMENT_TARGET = 15.0; SDKROOT = iphoneos; SWIFT_VERSION = 5.0;'
    target_settings = 'PRODUCT_NAME = Scorpion; PRODUCT_BUNDLE_IDENTIFIER = de.cronix.scorpion; INFOPLIST_FILE = Scorpion/Info.plist; TARGETED_DEVICE_FAMILY = 1; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = NO; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";'
    optimization = '-Onone' if mode == 'Debug' else '-O'
    obj('project:' + mode, f'isa = XCBuildConfiguration; buildSettings = {{ {project_settings} }}; name = {mode};')
    obj('target:' + mode, f'isa = XCBuildConfiguration; buildSettings = {{ {target_settings} SWIFT_OPTIMIZATION_LEVEL = {quote(optimization)}; }}; name = {mode};')
for scope in ('project', 'target'):
    obj(scope + ':configs', f'isa = XCConfigurationList; buildConfigurations = ({ident(scope + ":Debug")},{ident(scope + ":Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {ident("target:configs")}; buildPhases = ({ident("sources")},{ident("frameworks")},{ident("resources")},); buildRules = (); dependencies = (); name = Scorpion; productName = Scorpion; productReference = {app}; productType = "com.apple.product-type.application";')
obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; }}; buildConfigurationList = {ident("project:configs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = {ident("group")}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({ident("target")},);')
project = ROOT / 'Scorpion.xcodeproj'
project.mkdir(exist_ok=True)
(project / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + '\n}; rootObject = ' + ident('project') + '; }\n', encoding='utf-8')
schemes = project / 'xcshareddata' / 'xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
(schemes / 'Scorpion.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('target')}" BuildableName="Scorpion.app" BlueprintName="Scorpion" ReferencedContainer="container:Scorpion.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('target')}" BuildableName="Scorpion.app" BlueprintName="Scorpion" ReferencedContainer="container:Scorpion.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''', encoding='utf-8')
print('Generated Scorpion.xcodeproj')
