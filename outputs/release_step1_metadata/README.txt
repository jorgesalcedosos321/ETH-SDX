Step 1 (metadata) for eth-prod: 21 custom fields, Arifpay_Config__mdt, Sponsorship_Type__c merged with prod values, Opportunity stage Missed.
Dry-run validated against eth-prod on 2026-10-21: 25/25 components, 0 errors (prod does not allow NoTestRun; no Apex in the package so no tests run).
Deploy: cd outputs/release_step1_metadata && sf project deploy start --source-dir force-app --target-org eth-prod
