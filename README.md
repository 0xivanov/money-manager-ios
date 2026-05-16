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
