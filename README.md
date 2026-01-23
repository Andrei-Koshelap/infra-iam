# infra-iam

Identity and Access Management
IAM = AD + Keycloak (+ if required TARA)

[User / Browser]
        |
        v
┌────────────────┐
│   IAM module   │
│                │
│  AD / Azure AD │
│        ↓       │
│    Keycloak    │
└───────┬────────┘
        |
        | OIDC login
        v
┌────────────────┐
│      TIM       │
│  (auth facade) │
│  - OIDC client │
│  - session/JWT │
└───────┬────────┘
        |
        | JWTTOKEN (cookie)
        v
┌────────────────┐
│     Ruuter     │
│  (API gateway) │
│  - JWT check   │
│  - policy      │
└───────┬────────┘
        |
        v
┌────────────────┐
│   Backends     │
└────────────────┘
