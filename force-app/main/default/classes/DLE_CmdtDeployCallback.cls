/**
 * Deploy callback for Custom Metadata changes made from the DLE admin app.
 *
 * The admin UI is fire-and-forget: it enqueues the deployment and refreshes its list a
 * few seconds later. This callback exists only so a failed deployment leaves a trace in
 * the debug log rather than disappearing silently.
 */
public class DLE_CmdtDeployCallback implements Metadata.DeployCallback {

    public void handleResult(
            Metadata.DeployResult result,
            Metadata.DeployCallbackContext context
    ) {
        Id jobId = (context == null) ? null : context.getCallbackJobId();

        if (result != null && result.status == Metadata.DeployStatus.Succeeded) {
            System.debug(LoggingLevel.INFO, 'DLE CMDT deploy ' + jobId + ' succeeded.');
            return;
        }

        String failures = (result != null && result.details != null)
                ? JSON.serialize(result.details.componentFailures)
                : '(no detail)';
        System.debug(LoggingLevel.ERROR, 'DLE CMDT deploy ' + jobId + ' failed: ' + failures);
    }
}