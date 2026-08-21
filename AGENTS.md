# Repository Guidelines

## Project Structure & Module Organization

Deployable Salesforce metadata lives under `force-app/main/default/`: Apex in `classes/`, triggers in `triggers/`, Visualforce in `pages/`, and Aura bundles in `aura/`. Keep source files beside their matching `*-meta.xml`. Org definitions are in `config/`, deployment manifests in `manifest/`, and Apex/SOQL examples in `scripts/`.

## Build, Test, and Development Commands

Install tooling with `npm install` (or `npm ci` in CI). Useful commands include:

- `npm run lint` — lint JavaScript in Aura and LWC bundles.
- `npm test` — run Lightning Web Component Jest tests.
- `npm run test:unit:coverage` — run Jest and produce coverage output.
- `npm run prettier:verify` — check formatting without changing files.
- `npm run prettier` — format supported Apex, JavaScript, markup, and metadata files.
- `sf project deploy start --manifest manifest/package.xml` — deploy the manifest to the configured org.
- `sf apex run test --test-level RunLocalTests --wait 20` — execute local Apex tests in an authorized org.

## Coding Style & Naming Conventions

Use the checked-in Prettier and ESLint configurations before committing. Preserve four-space indentation and omit trailing commas. Name Apex types in PascalCase (`PaymentTriggerService`), interfaces with an `I` prefix where established, and tests with a `Test` suffix. Use one trigger per object and delegate substantial logic to handlers or services. Keep Aura filenames aligned with the bundle name.

## Testing Guidelines

Apex tests are colocated in `classes/` and follow `*Test.cls`. Cover success, validation, bulk, and failure paths; wrap asynchronous work with `Test.startTest()` and `Test.stopTest()`. LWC tests should use `__tests__/*.test.js`. Salesforce requires 75% Apex coverage for production, but changed branches should be fully exercised.

## Commit & Pull Request Guidelines

The history currently contains only `first commit`, so no established message convention exists. Use concise, imperative subjects such as `Add callback validation tests`, and keep unrelated changes separate. Pull requests should explain the behavior change, identify affected metadata, list validation commands and target org type, and link the relevant issue. Include screenshots for visible Aura, LWC, or Visualforce changes, and call out permissions, named credentials, or deployment-order requirements.

## Security & Configuration

Never commit org credentials, access tokens, private keys, or customer data. Keep environment-specific values in Salesforce configuration or secure CI secrets, and review retrieved metadata before committing it.
