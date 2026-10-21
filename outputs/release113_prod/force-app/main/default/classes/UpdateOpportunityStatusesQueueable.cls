//SFESWCSD-113
/**
 * Updates the stage of opportunities when Database.executeBatch cannot be used, for example when the payment trigger runs
 * inside another batch such as GenerateHistoricOppsBatch.
 */
public inherited sharing class UpdateOpportunityStatusesQueueable implements Queueable {
    private final Map<String, Set<Id>> opportunityIdsByStatus;

    public UpdateOpportunityStatusesQueueable(Map<String, Set<Id>> opportunityIdsByStatus) {
        this.opportunityIdsByStatus = opportunityIdsByStatus == null ? new Map<String, Set<Id>>() : opportunityIdsByStatus;
    }

    public void execute(QueueableContext context) {
        Map<Id, String> statusByOpportunityId = new Map<Id, String>();
        for (String status : opportunityIdsByStatus.keySet()) {
            for (Id opportunityId : opportunityIdsByStatus.get(status)) {
                statusByOpportunityId.put(opportunityId, status);
            }
        }
        if (statusByOpportunityId.isEmpty()) {
            return;
        }

        List<Opportunity> opportunities = [SELECT Id, StageName FROM Opportunity WHERE Id IN :statusByOpportunityId.keySet()];
        for (Opportunity opportunity : opportunities) {
            opportunity.StageName = statusByOpportunityId.get(opportunity.Id);
        }

        Database.SaveResult[] results = Database.update(opportunities, false);
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                for (Database.Error error : result.getErrors()) {
                    System.debug(LoggingLevel.ERROR, '###UpdateOpportunityStatusesQueueable error ' + error.getStatusCode() + ': ' + error.getMessage()
                            + ' Fields: ' + error.getFields());
                }
            }
        }
    }
}
