//SFESWCSD-113
/**
 * Runs GenerateHistoricOppsBatch from a context where Database.executeBatch is not allowed, such as another batch or a future method.
 */
public inherited sharing class GenerateHistoricOppsQueueable implements Queueable {
    private final Set<Id> recurringDonationIds;
    private final String stageName;

    public GenerateHistoricOppsQueueable(Set<Id> recurringDonationIds) {
        this(recurringDonationIds, GenerateHistoricOppsBatch.DEFAULT_STAGE_NAME);
    }

    public GenerateHistoricOppsQueueable(Set<Id> recurringDonationIds, String stageName) {
        this.recurringDonationIds = recurringDonationIds == null ? new Set<Id>() : recurringDonationIds;
        this.stageName = stageName;
    }

    public void execute(QueueableContext context) {
        if (recurringDonationIds.isEmpty()) {
            return;
        }
        GenerateHistoricOppsBatch.run(recurringDonationIds, new Set<Id>(), stageName);
    }
}
