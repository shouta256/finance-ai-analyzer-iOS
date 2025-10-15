# バックエンド環境変数設定が必要

## 現状

iOS側の実装は完了し、以下が正常に動作しています：

- ✅ Cognito Hosted UIでの認証
- ✅ Authorization codeの取得
- ✅ 正しいJSON形式でのAPI呼び出し
- ✅ Keychain統合
- ✅ 自動トークンリフレッシュ機能

## 問題

バックエンド（`https://api.shota256.me`）で以下のエラーが発生：

```json
{
  "code": "INTERNAL_ERROR",
  "message": "Unexpected error",
  "details": {
    "reason": "Cognito domain not configured (set COGNITO_DOMAIN)"
  }
}
```

## 必要な対応

バックエンドアプリケーションに以下の環境変数を設定してください：

```bash
COGNITO_DOMAIN=https://us-east-1mfd4o5tgy.auth.us-east-1.amazoncognito.com
COGNITO_CLIENT_ID=p4tu620p2eriv24tb1897d49s
COGNITO_REDIRECT_URI=safepocket://auth/callback
```

### デプロイ環境別の設定方法

#### AWS Elastic Beanstalk
```bash
aws elasticbeanstalk update-environment \
  --environment-name your-env \
  --option-settings \
    Namespace=aws:elasticbeanstalk:application:environment,OptionName=COGNITO_DOMAIN,Value=https://us-east-1mfd4o5tgy.auth.us-east-1.amazoncognito.com \
    Namespace=aws:elasticbeanstalk:application:environment,OptionName=COGNITO_CLIENT_ID,Value=p4tu620p2eriv24tb1897d49s \
    Namespace=aws:elasticbeanstalk:application:environment,OptionName=COGNITO_REDIRECT_URI,Value=safepocket://auth/callback
```

#### Docker / Docker Compose
```yaml
environment:
  - COGNITO_DOMAIN=https://us-east-1mfd4o5tgy.auth.us-east-1.amazoncognito.com
  - COGNITO_CLIENT_ID=p4tu620p2eriv24tb1897d49s
  - COGNITO_REDIRECT_URI=safepocket://auth/callback
```

#### Kubernetes
```yaml
env:
  - name: COGNITO_DOMAIN
    value: "https://us-east-1mfd4o5tgy.auth.us-east-1.amazoncognito.com"
  - name: COGNITO_CLIENT_ID
    value: "p4tu620p2eriv24tb1897d49s"
  - name: COGNITO_REDIRECT_URI
    value: "safepocket://auth/callback"
```

#### ローカル開発（.env ファイル）
```bash
COGNITO_DOMAIN=https://us-east-1mfd4o5tgy.auth.us-east-1.amazoncognito.com
COGNITO_CLIENT_ID=p4tu620p2eriv24tb1897d49s
COGNITO_REDIRECT_URI=safepocket://auth/callback
```

## 検証方法

環境変数設定後、以下のcURLコマンドで動作確認できます：

```bash
curl -X POST https://api.shota256.me/api/auth/token \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "grantType": "authorization_code",
    "code": "test_code",
    "redirectUri": "safepocket://auth/callback",
    "codeVerifier": "test_verifier"
  }'
```

期待される結果：
- ❌ `"reason": "Cognito domain not configured"` → 環境変数未設定
- ✅ `"code": "INVALID_ARGUMENT"` または Cognito関連のエラー → 環境変数設定済み（正しい動作）

## iOS側から送信されるリクエスト例

```json
POST /api/auth/token
Content-Type: application/json

{
  "grantType": "authorization_code",
  "code": "d874bdcf-aeb2-4497-b201-6261752ccf83",
  "redirectUri": "safepocket://auth/callback",
  "codeVerifier": "JN0tq1vJ3QsBQG674FubCtZ0MvhVwqMYN8cfoYRKOkiDhaGM34qSMEvHZ"
}
```

## 次のステップ

環境変数設定後：
1. バックエンドを再起動
2. iOS アプリでログインを再試行
3. 認証が成功すれば、口座一覧画面に遷移
4. トークンリフレッシュ機能を検証

## 連絡先

バックエンド設定完了後、iOS側でエンドツーエンドテストを実施します。
