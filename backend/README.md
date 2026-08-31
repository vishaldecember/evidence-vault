# Evidence Vault Backend

Backend implementation for Evidence Vault uses **Firebase**. This directory will hold rules, functions, and schemas in future sprints.

**Architecture is documented at the repository root:**

| Document | Purpose |
|---|---|
| [`../BACKEND_ARCHITECTURE.md`](../BACKEND_ARCHITECTURE.md) | Overview, ownership, sync, delete, risks |
| [`../FIRESTORE_DATA_MODEL.md`](../FIRESTORE_DATA_MODEL.md) | Firestore collections and fields |
| [`../STORAGE_STRUCTURE.md`](../STORAGE_STRUCTURE.md) | Firebase Storage layout |
| [`../AUTHENTICATION_FLOW.md`](../AUTHENTICATION_FLOW.md) | Auth lifecycle |
| [`../FIREBASE_SETUP.md`](../FIREBASE_SETUP.md) | Developer onboarding — FlutterFire CLI, packages |
| [`../BACKEND_ROADMAP.md`](../BACKEND_ROADMAP.md) | Implementation phases |

**MVP-0.9.3.2:** Firebase Auth integrated in Flutter app (`lib/services/auth/`). Rules and Functions remain future sprints.
