//SFESWCSD-92
public class ArifPayRDCancellationQueueable
    implements Queueable, Database.AllowsCallouts {

    private String sessionUuid;
    private String status;

    public ArifPayRDCancellationQueueable(
        String sessionUuid,
        String status
    ) {
        this.sessionUuid = sessionUuid;
        this.status = status;
    }

    public void execute(QueueableContext context) {
        ArifPayCancellationService.cancelRecurringDonation(sessionUuid, status);
    }
}
