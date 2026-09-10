# ArifPay sandbox demonstration

`ArifPaySandboxProbeTest` uses mocked responses based on observed sandbox results.
It tests request construction, response parsing, HTTP 200 payment failures,
duplicate nonces, and invalid inputs. A passing mocked test does not prove gateway
availability or credential validity.

`arifpaySandboxProbe.apex` makes real sandbox requests using the public portal
key. It creates two sessions, simulates SUCCESS and FAIL, and checks duplicate
nonces. It logs only response summaries, not credentials or beneficiary details.
The helper is fixed to the sandbox host and routes. It does not exercise the
existing cancellation service or Salesforce webhook delivery.

## Validation result

Dry-run deployment to `eth-sdx`: both new classes compiled. Tests could not run
because the org's existing `RecurringDonationTrigger` references the missing
`RecurringDonationHandler.afterInsert(List<npe03__Recurring_Donation__c>)` method.
No metadata was saved. Resolve that org compilation issue before running tests.

## Deploy and run

Deploy only the two new classes:

```powershell
sf project deploy start --source-dir force-app/main/default/classes/ArifPaySandboxProbe.cls --source-dir force-app/main/default/classes/ArifPaySandboxProbeTest.cls --test-level RunSpecifiedTests --tests ArifPaySandboxProbeTest --target-org eth-sdx --wait 10
```

For real callouts, add an active Remote Site Setting for
`https://gateway.arifpay.org` in Salesforce Setup, then run:

```powershell
sf apex run --file scripts/apex/arifpaySandboxProbe.apex --target-org eth-sdx
```

Alternatively, paste the script into Developer Console > Execute Anonymous and
open the log. Search for `ARIFPAY SESSION`, `ARIFPAY PAYMENT`, and
`ARIFPAY DUPLICATE`.

Expected summaries (session IDs and payment URLs vary):

| Operation | httpStatus | error | message | transactionStatus |
| --- | --- | --- | --- | --- |
| Create | 200 | false | Sandbox session created | null |
| SUCCESS simulation | 200 | false | Sandbox payment successful | SUCCESS |
| FAIL simulation | 200 | true | Simulated failure | FAILED |
| Duplicate nonce | 400 | true | session already exist | null |

The script asserts these outcomes and stops if an outcome differs. Network or
non-JSON gateway errors surface as Apex exceptions. The example callback URLs
are placeholders; callback delivery is not part of this demonstration.
