//SFESWCSD-92
/**
 * Updates the ArifPay notify URL for a Recurring Donation after the intake
 * transaction has committed (callouts are not allowed after DML). Best-effort:
 * a failure is logged and never rolls back the donation.
 */
public class ArifPayNotifyUrlQueueable
    implements Queueable, Database.AllowsCallouts {

    private String sessionUuid;
    private String notifyUrl;

    public ArifPayNotifyUrlQueueable(String sessionUuid, String notifyUrl) {
        this.sessionUuid = sessionUuid;
        this.notifyUrl = notifyUrl;
    }

    public void execute(QueueableContext context) {
        try {
            RecurringDonationService.changeRecurringDonationNotifyURL(
                this.sessionUuid,
                this.notifyUrl
            );
        } catch (Exception ex) {
            System.debug('###ArifPayNotifyUrlQueueable error:' + ex.getMessage());
            Database.insert(
                Utils.logJsons(
                    'uuid:' + this.sessionUuid + ' / error:' + ex.getMessage(),
                    'Log ArifPay Notify URL Change',
                    true
                ),
                false
            );
        }
    }
}
