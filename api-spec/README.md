# App Store Connect API Spec

`openapi.json` is the official App Store Connect OpenAPI 3 specification (v4.3), downloaded from:

```
https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip
```

To update:

```sh
curl -L -o /tmp/asc-spec.zip https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip
unzip -p /tmp/asc-spec.zip openapi.oas.json > api-spec/openapi.json
```

Last downloaded: 2026-03-27 (v4.3)
