# Money Manager iOS

Native SwiftUI iOS client for the Money Manager backend.

## Requirements

- Xcode 15.4 or newer
- iOS 17+ target
- Money Manager server running at `http://localhost:8080`

From the repo root, start the backend with:

```sh
cd ../money-manager-server
docker compose up --build
```

## Build

```sh
xcodebuild -project MoneyManager.xcodeproj -target MoneyManager -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

## Build Tests

```sh
xcodebuild -project MoneyManager.xcodeproj -target MoneyManagerTests -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Running tests requires an installed and available iOS Simulator runtime/device in Xcode.

## On-device transaction classification

The bundled Core ML text classifier categorizes Revolut CSV rows on the phone before import. Only predictions at or above the app's confidence threshold are applied; uncertain rows stay `Other`. Manual category corrections are stored locally and take precedence for matching merchant descriptions.

Regenerate the checked-in model after changing its training seeds:

```sh
xcrun swift Tools/train_transaction_classifier.swift MoneyManager/Resources/TransactionCategoryClassifier.mlmodel
```
