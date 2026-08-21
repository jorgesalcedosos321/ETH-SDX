//SFESWCSD-92
public class ArifPayCancellationQueueable
    implements Queueable, Database.AllowsCallouts {

    private ArifPayCancellationRequest request;

    public ArifPayCancellationQueueable(
        ArifPayCancellationRequest request
    ) {
        this.request = request;
    }

    public void execute(QueueableContext context) {
        ArifPayCancellationService.cancelSubscription(
            this.request
        );
    }
}