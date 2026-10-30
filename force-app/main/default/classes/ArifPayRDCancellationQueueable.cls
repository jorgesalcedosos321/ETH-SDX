//SFESWCSD-92
public class ArifPayRDCancellationQueueable
    implements Queueable, Database.AllowsCallouts {

    private List<String> sessionUuids;
    private String status;

    public ArifPayRDCancellationQueueable(
        String sessionUuid,
        String status
    ) {
        this(new List<String>{sessionUuid}, status);
    }

    // One job covers every closed RD: it cancels one session UUID per run and
    // chains itself for the rest, so a trigger/batch only ever enqueues once.
    public ArifPayRDCancellationQueueable(
        List<String> sessionUuids,
        String status
    ) {
        this.sessionUuids = sessionUuids;
        this.status = status;
    }

    public void execute(QueueableContext context) {
        if (sessionUuids == null || sessionUuids.isEmpty()) {
            return;
        }

        String sessionUuid = sessionUuids.remove(0);
        ArifPayRDCancellationQueueable continuation = sessionUuids.isEmpty()
            ? null
            : new ArifPayRDCancellationQueueable(sessionUuids, status);

        // A queueable may enqueue only one job. If the cancellation finds active
        // subscribers it uses that slot and hands the continuation to the
        // subscriber job, which enqueues it once it has finished.
        ArifPayCancellationService.pendingContinuation = continuation;
        Integer enqueuedBefore = Limits.getQueueableJobs();
        try {
            ArifPayCancellationService.cancelRecurringDonation(sessionUuid, status);
        } catch (Exception e) {
            Database.insert(
                Utils.logJsons(
                    'cancelRecurringDonation failed for uuid:' + sessionUuid +
                        ' / error:' + e.getMessage(),
                    'Log ArifPay Cancellation',
                    true
                ),
                false
            );
        }
        ArifPayCancellationService.pendingContinuation = null;

        if (continuation != null && Limits.getQueueableJobs() == enqueuedBefore && !Test.isRunningTest()) {
            System.enqueueJob(continuation);
        }
    }
}
