@tool
extends EditorPlugin
## wiwiwi's own small Android export settings.
##
## Full-screen ads (owners, 20 Nov 2026): Google's ad screen (AdActivity) kept out of the phone's camera
## hole / notch, so a strip of the game showed through beside the ad and it looked cut off. On export
## this gives AdActivity a theme that draws over the cutout (shortEdges) on a black background.

var _export: AndroidTweaks

func _enter_tree() -> void:
	_export = AndroidTweaks.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null

class AndroidTweaks extends EditorExportPlugin:
	const RES := "res://android/build/res/"
	const THEME := """<?xml version="1.0" encoding="utf-8"?>
<!-- Written by addons/wiwiwi_android on every export: Google's ad screen fills the whole display. -->
<resources>
	<style name="WiwiwiAdTheme" parent="@android:style/Theme.Translucent.NoTitleBar.Fullscreen">
		<item name="android:windowBackground">#000000</item>
		<item name="android:windowIsTranslucent">false</item>
%s	</style>
</resources>
"""
	const CUTOUT := "\t\t<item name=\"android:windowLayoutInDisplayCutoutMode\">shortEdges</item>\n"

	func _get_name() -> String:
		return "WiwiwiAndroidTweaks"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		_write(RES + "values/wiwiwi_ads.xml", THEME % "")
		_write(RES + "values-v28/wiwiwi_ads.xml", THEME % CUTOUT)   # cutout mode exists from Android 9

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return """
<activity android:name="com.google.android.gms.ads.AdActivity"
	android:theme="@style/WiwiwiAdTheme"
	android:configChanges="keyboard|keyboardHidden|orientation|screenLayout|uiMode|screenSize|smallestScreenSize"
	android:exported="false"
	tools:replace="android:theme" />
"""

	func _write(path: String, text: String) -> void:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(text)
