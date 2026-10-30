//SFESWCSD-92
public class ArifPaySubscriberCancellationQueueable
    implements Queueable, Database.AllowsCallouts {

    private String sessionUuid;
    private List<String> phoneNumbers;
    // Remaining RD cancellations to run after the last subscriber is done
    private ArifPayRDCancellationQueueable continuation;

    public ArifPaySubscriberCancellationQueueable(
        String sessionUuid,
        List<String> phoneNumbers
    ) {
        this(sessionUuid, phoneNumbers, null);
    }

    public ArifPaySubscriberCancellationQueueable(
        String sessionUuid,
        List<String> phoneNumbers,
        ArifPayRDCancellationQueueable continuation
    ) {
        this.sessionUuid = sessionUuid;
        this.phoneNumbers = phoneNumbers;
        this.continuation = continuation;
    }

    public void execute(QueueableContext context) {
        if (phoneNumbers.isEmpty()) {
            return;
        }

        String phoneNumber = phoneNumbers.remove(0);

        try {
            ArifPayCancellationService.deactivateSubscriber(
                sessionUuid,
                phoneNumber
            );
        } catch (Exception e) {
            Database.insert(
                Utils.logJsons(
                    'deactivateSubscriber failed for uuid:' + sessionUuid +
                        ' / phone:' + phoneNumber +
                        ' / error:' + e.getMessage(),
                    'Log ArifPay Cancellation',
                    true
                ),
                false
            );
        }

        if (Test.isRunningTest()) {
            return;
        }
        if (!phoneNumbers.isEmpty()) {
            System.enqueueJob(
                new ArifPaySubscriberCancellationQueueable(sessionUuid, phoneNumbers, continuation)
            );
        } else if (continuation != null) {
            System.enqueueJob(continuation);
        }
    }
}
