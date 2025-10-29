# Backend Environment Variables Required

## Current status

The iOS implementation is complete and the following flows work as expected:

- ✅ Cognito Hosted UI authentication
- ✅ Authorization code retrieval
- ✅ API calls with the expected JSON payloads
- ✅ Keychain integration
- ✅ Automatic token refresh

## Issue

The backend (`https://api.shota256.me`) currently returns:

```json
{
  "code": "INTERNAL_ERROR",
  "message": "Unexpected error",
  "details": {
    "reason": "Cognito domain not configured (set COGNITO_DOMAIN)"
  }
}
```

## Required action

Configure the following environment variables in the backend application:

```bash
COGNITO_DOMAIN=https://us-east-1mfd4o5tgy.auth.us-east-1.amazoncognito.com
COGNITO_CLIENT_ID=p4tu620p2eriv24tb1897d49s
COGNITO_REDIRECT_URI=safepocket://auth/callback
```

### Deployment-specific examples

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

#### Local development (.env file)
```bash
COGNITO_DOMAIN=https://us-east-1mfd4o5tgy.auth.us-east-1.amazoncognito.com
COGNITO_CLIENT_ID=p4tu620p2eriv24tb1897d49s
COGNITO_REDIRECT_URI=safepocket://auth/callback
```

## Validation steps

After configuring the environment variables, verify the setup with:

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

Expected result:
- ❌ `"reason": "Cognito domain not configured"` → environment variables missing
- ✅ `"code": "INVALID_ARGUMENT"` or a Cognito-specific error → environment variables are set correctly

## Example request from iOS

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

## Next steps

After updating the environment variables:
1. Restart the backend service.
2. Retry the login flow in the iOS app.
3. Confirm the account list appears once authentication succeeds.
4. Verify that token refresh works end-to-end.

## Contact

Once the backend configuration is complete, the iOS team can run end-to-end tests.
