import glob
import re

m = 'android/app/src/main/AndroidManifest.xml'
s = open(m, encoding='utf-8').read()

perms = '''    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
'''
svc = '''        <service android:name="com.ryanheise.audioservice.AudioService" android:foregroundServiceType="mediaPlayback" android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>
'''
assert '<application' in s and '</application>' in s
s = s.replace('<application', perms + '    <application', 1)
s = s.replace('</application>', svc + '    </application>', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="نوا"', s, count=1)
open(m, 'w', encoding='utf-8').write(s)

files = glob.glob('android/app/src/main/kotlin/**/MainActivity.kt', recursive=True)
assert files, 'MainActivity.kt not found'
f = files[0]
first = open(f, encoding='utf-8').read().splitlines()[0]
assert first.startswith('package '), first
open(f, 'w', encoding='utf-8').write(
    first + '\n\nimport com.ryanheise.audioservice.AudioServiceActivity\n\nclass MainActivity : AudioServiceActivity()\n'
)
print('patched', m, f)
