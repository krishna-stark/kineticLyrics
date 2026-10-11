#!/usr/bin/env python3
"""Compile/run pure native FFT fixtures using the project's cached Kotlin SDK.

Run from any directory: python3 app/tool/check_audio_spectrum.py
An Android/Flutter build must have populated ~/.gradle/caches first.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

app_root = Path(__file__).resolve().parents[1]
cache = Path.home() / '.gradle/caches/modules-2/files-2.1'


def cached(group, artifact, version=None):
    matches = list((cache / group / artifact).glob(
        f'{version or "*"}/*/{artifact}-*.jar'))
    if not matches:
        raise SystemExit(f'Missing cached {artifact}; build the Android app first.')
    return sorted(matches, key=lambda p: tuple(
        int(part) if part.isdigit() else 0
        for part in p.parents[1].name.split('.')))[-1]


compiler = cached('org.jetbrains.kotlin', 'kotlin-compiler-embeddable')
version = compiler.parents[1].name
stdlib = cached('org.jetbrains.kotlin', 'kotlin-stdlib', version)
classpath = [compiler, stdlib,
             cached('org.jetbrains.kotlin', 'kotlin-script-runtime', version),
             cached('org.jetbrains.kotlin', 'kotlin-reflect'),
             cached('org.jetbrains.kotlinx', 'kotlinx-coroutines-core-jvm'),
             cached('org.jetbrains', 'annotations')]
java_home = os.environ.get('JAVA_HOME')
java = str(Path(java_home) / 'bin/java') if java_home else shutil.which('java')
studio_java = Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java')
if studio_java.is_file() and not java_home:
    java = str(studio_java)
if not java:
    raise SystemExit('A Java runtime is required (Android Studio provides one).')
package = 'com/kineticlyrics/kinetic_lyrics'
source = app_root / f'android/app/src/main/kotlin/{package}/SpectrumAnalyzer.kt'
fixture = app_root / f'android/app/src/test/kotlin/{package}/SpectrumAnalyzerFixture.kt'
with tempfile.TemporaryDirectory(prefix='kinetic-spectrum-') as output:
    subprocess.run([java, '-cp', os.pathsep.join(map(str, classpath)),
                    'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler',
                    '-no-stdlib', '-no-reflect', '-classpath', str(stdlib),
                    '-d', output, str(source), str(fixture)], check=True)
    subprocess.run([java, '-cp', os.pathsep.join([str(stdlib), output]),
                    'com.kineticlyrics.kinetic_lyrics.SpectrumAnalyzerFixtureKt'], check=True)
