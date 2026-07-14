# ShareCheck TestFlight 配信手順

この手順では、Mac を手元で使用せず、GitHub Actions の `TestFlight Distribution` ワークフローから ShareCheck をビルドして App Store Connect にアップロードし、TestFlight で実機確認できる状態にします。

## 配信設定

| 項目 | 値 |
| --- | --- |
| App 名 | `ShareCheck` |
| Bundle ID | `com.ishiishikou.sharecheck` |
| SKU | `sharecheck-ios` |
| GitHub Environment | `testflight` |
| 配信先 | TestFlight 内部テスト |
| 実行方法 | GitHub Actions から手動実行 |

> `project.yml` には開発用のプレースホルダー Bundle ID が定義されています。TestFlight 用アーカイブでは、ワークフローが `APP_BUNDLE_ID` の値を `PRODUCT_BUNDLE_IDENTIFIER` に渡します。

## 全体の流れ

1. Apple Developer 側で Bundle ID を登録する。
2. App Store Connect に ShareCheck のアプリを作成する。
3. 配布用証明書、Provisioning Profile、App Store Connect API キーを準備する。
4. GitHub の `testflight` Environment に Secrets を登録する。
5. `TestFlight Distribution` ワークフローを手動実行する。
6. App Store Connect でビルドの処理完了を確認し、内部テスターへ配信する。

すでに完了している項目は飛ばして構いません。

## 1. Bundle ID を登録する

Apple Developer の Certificates, Identifiers & Profiles で、明示的な App ID を作成します。

- Description: `ShareCheck`
- Bundle ID: `com.ishiishikou.sharecheck`

ShareCheck で必要な Capability がある場合は、この App ID に追加します。

## 2. App Store Connect にアプリを作成する

App Store Connect で新しい iOS アプリを作成します。

- Name: `ShareCheck`
- Bundle ID: `com.ishiishikou.sharecheck`
- SKU: `sharecheck-ios`
- Primary Language: 運用する言語を選択

同じ Bundle ID のアプリがすでに存在する場合、この作業は不要です。

## 3. 署名素材を準備する

### Apple Distribution 証明書

App Store 配信用の Apple Distribution 証明書を作成し、秘密鍵を含む `.p12` ファイルとして書き出します。

必要なもの:

- `.p12` ファイル
- `.p12` の書き出し時に設定したパスワード

### App Store Provisioning Profile

次の条件で App Store 配信用 Provisioning Profile を作成します。

- Distribution method: App Store Connect
- App ID: `com.ishiishikou.sharecheck`
- Certificate: 上記の Apple Distribution 証明書

作成した `.mobileprovision` ファイルをダウンロードします。

### App Store Connect API キー

App Store Connect へのアップロード権限を持つ API キーを作成し、次を控えます。

- Key ID
- Issuer ID
- 秘密鍵ファイル `AuthKey_<KEY_ID>.p8`

秘密鍵ファイルは再ダウンロードできない場合があるため、安全な場所に保管します。

## 4. ファイルを Base64 に変換する

GitHub Secrets には、改行を含まない Base64 文字列を登録します。

### PowerShell

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("distribution.p12"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("ShareCheck_AppStore.mobileprovision"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_KEYID.p8"))
```

### Linux

```bash
base64 -w 0 distribution.p12
base64 -w 0 ShareCheck_AppStore.mobileprovision
base64 -w 0 AuthKey_KEYID.p8
```

### macOS

```bash
base64 < distribution.p12 | tr -d '\n'
base64 < ShareCheck_AppStore.mobileprovision | tr -d '\n'
base64 < AuthKey_KEYID.p8 | tr -d '\n'
```

## 5. GitHub Environment と Secrets を登録する

GitHub リポジトリの Settings から `testflight` Environment を作成し、次の Environment Secrets を登録します。

| Secret 名 | 内容 |
| --- | --- |
| `APP_BUNDLE_ID` | `com.ishiishikou.sharecheck` |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect Issuer ID |
| `APP_STORE_CONNECT_API_PRIVATE_KEY_BASE64` | `.p8` ファイルの Base64 文字列 |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | `.p12` ファイルの Base64 文字列 |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | `.p12` のパスワード |
| `IOS_PROVISIONING_PROFILE_BASE64` | `.mobileprovision` ファイルの Base64 文字列 |

注意事項:

- 証明書、秘密鍵、Provisioning Profile、Base64 文字列をリポジトリへ commit しない。
- Secrets の値を Issue、Pull Request、Actions のログ、チャットへ貼らない。
- Repository Secrets ではなく、ワークフローが参照する `testflight` Environment に登録する。

## 6. GitHub Actions を実行する

1. GitHub の Actions を開く。
2. `TestFlight Distribution` を選択する。
3. `Run workflow` を押す。
4. 実行するブランチを選択する。
5. 入力値を確認して実行する。

入力項目:

| 入力 | 設定方法 |
| --- | --- |
| `marketing_version` | 初回例: `1.0` |
| `build_number` | 通常は空欄。GitHub Actions の run number が使われる |
| `bundle_id` | 通常は空欄。`APP_BUNDLE_ID` Secret が使われる |

ワークフローは次を順番に実行します。

1. XcodeGen で Xcode プロジェクトを生成
2. 配布用証明書を一時 Keychain にインストール
3. Provisioning Profile をインストール
4. Release 構成で Archive を作成
5. IPA を Export
6. App Store Connect へアップロード
7. 一時的な署名素材を削除

## 7. TestFlight で内部テストする

アップロード成功後、App Store Connect の TestFlight でビルドの処理が完了することを確認します。

必要に応じて、App Store Connect 上で次の項目に回答します。

- 輸出コンプライアンス
- 暗号化の使用状況
- テストに必要な情報

処理済みのビルドを内部テストグループへ追加し、実機の TestFlight アプリから ShareCheck をインストールします。

## 再実行時のルール

- 同じ marketing version を使う場合でも、build number は前回より大きい値にする。
- `build_number` を空欄にすると、GitHub Actions の run number が使用される。
- 修正後は同じワークフローを再度手動実行する。
- push だけでは TestFlight 配信を開始しない。

## トラブルシューティング

### `Missing required value` または Secret 不足

`testflight` Environment に必要な Secrets がすべて登録されているか確認します。Secret 名は大文字・小文字を含めて完全一致が必要です。

### Provisioning Profile の Team ID 不一致

`IOS_PROVISIONING_PROFILE_BASE64` に登録した Profile と `APPLE_TEAM_ID` が同じ Apple Developer Team に属しているか確認します。

### 証明書を import できない

次を確認します。

- `.p12` に秘密鍵が含まれている
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` が正しい
- Base64 文字列が途中で改行・欠落していない

### Archive または Export で署名エラー

次の組み合わせが一致しているか確認します。

- Bundle ID
- Apple Developer Team
- Apple Distribution 証明書
- App Store Provisioning Profile

### App Store Connect へのアップロードに失敗する

次を確認します。

- API Key ID と Issuer ID が正しい
- `.p8` が対象 API キーの秘密鍵である
- API キーにアップロード権限がある
- App Store Connect のアプリと Bundle ID が一致している
- build number が既存ビルドより大きい

## セキュリティ

GitHub Actions は実行時に署名素材を一時ファイルへ復元し、処理終了時に削除します。ローカルファイルや復元後の署名素材を成果物として保存しないでください。
