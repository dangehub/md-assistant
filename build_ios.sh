flutter clean
flutter test
#flutter build ios --release 
#--split-debug-info=./debuginfo
#--obfuscate --split-debug-info=./debuginfo
flutter build ipa
#xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa --apiKey your_api_key --apiIssuer your_issuer_id