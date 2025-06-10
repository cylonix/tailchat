.PHONY: test generate_localization geneate

cat=cat
ifeq ($(OS),Windows_NT)
	cat=type
endif

# Workaround plugin resolution issue with synthetic package:
# https://github.com/flutter/flutter/issues/70840
localization:
	flutter gen-l10n \
		--arb-dir=lib/l10n \
		--template-arb-file=app_en.arb \
		--output-dir=lib/gen/l10n \
		--untranslated-messages-file=flutter_gen_error.txt \
		--no-nullable-getter \
		--no-synthetic-package
	@echo "error output:"
	@${cat} flutter_gen_error.txt

app-icons:
	dart run flutter_launcher_icons

generate: localization

android-debug-key:
	keytool -list -v -keystore ~/.android/debug.keystore \
		-alias androiddebugkey -storepass android -keypass android

test:
#    flutter test --no-pub test/${TEST}

.PHONY: apk aab debug-apk
apk:
	flutter build apk --split-per-abi --target-platform android-arm64
debug-apk:
	flutter build apk --split-per-abi --target-platform android-arm64 \
		--debug
aab:
	flutter build appbundle

.PHONY: test-app-links
test-app-links:
	@echo "Testing app links..."
	adb shell pm get-app-links io.cylonix.tailchat
	@echo "\nTesting intent..."
	adb shell am start -a android.intent.action.VIEW \
        -c android.intent.category.BROWSABLE \
        -d "https://cylonix.io/tailchat/add"

.PHONY: deb
debhelper golang-go:
	@if dpkg-query -Wf'$${db:Status-abbrev}' $@ 2>/dev/null |  \
		grep -q '^i'; then                                     \
			echo $@ has been installed;                        \
		else                                                   \
			sudo apt-get update && sudo apt-get install -y $@; \
		fi
deb: debhelper golang-go
	rm -rf linux/packaging/debian/tailchat
	cd linux/packaging; dpkg-buildpackage -rfakeroot -uc -b
	mv linux/tailchat* build/linux/x64/release/.
	@ls -l build/linux/x64/release/tailchat*