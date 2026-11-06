$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"
$env:PATH = "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin;D:\flutter\bin;$env:PATH"
$env:ANDROID_HOME = "D:\AndroidSDK"

Set-Location -Path "$PSScriptRoot/../android"
.\gradlew.bat assembleDebug --stacktrace
