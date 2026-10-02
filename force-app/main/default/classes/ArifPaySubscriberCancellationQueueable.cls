//SFESWCSD-92
public class ArifPaySubscriberCancellationQueueable
    implements Queueable, Database.AllowsCallouts {

    private String sessionUuid;
    private List<String> phoneNumbers;

    public ArifPaySubscriberCancellationQueueable(
        String sessionUuid,
        List<String> phoneNumbers
    ) {
        this.sessionUuid = sessionUuid;
        this.phoneNumbers = phoneNumbers;
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

        if (!phoneNumbers.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(
                new ArifPaySubscriberCancellationQueueable(sessionUuid, phoneNumbers)
            );
        }
    }
}
