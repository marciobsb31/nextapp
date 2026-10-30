# PDV Market

Aplicativo Flutter da pasta atual. A autoridade de estoque, preço, contrato e porta é a API em `D:\pdvmarket`.

```powershell
$env:Path = "D:\sdks\flutter\bin;" + $env:Path
flutter pub get
flutter test
flutter run -d chrome --web-port 6001
```

No emulador Android o endereço `localhost` vira `10.0.2.2`. Homologação:

```powershell
flutter run --dart-define=API_BASE_URL=https://seu-servidor
```

O diagnóstico dos contratos está em `docs/diagnostico-plataforma.md`.
