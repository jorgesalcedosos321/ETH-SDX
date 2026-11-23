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
        //SFEUCMSD-146 Opportunities whose payments changed again after this job was queued keep their current stage
        for (Id outdatedOpportunityId : PaymentTriggerService.getOpportunitiesWithOutdatedStage(statusByOpportunityId)) {
            statusByOpportunityId.remove(outdatedOpportunityId);
        }
        if (statusByOpportunityId.isEmpty()) {
            return;
        }

        List<Opportunity> opportunities = [SELECT Id, StageName, Name, CloseDate FROM Opportunity WHERE Id IN :statusByOpportunityId.keySet()]; //SFEUCMSD-134 Name and CloseDate are needed for the Payment Date
        List<Opportunity> closedWonOpportunities = new List<Opportunity>();
        for (Opportunity opportunity : opportunities) {
            opportunity.StageName = statusByOpportunityId.get(opportunity.Id);
            if (opportunity.StageName == 'Closed Won') {
                closedWonOpportunities.add(opportunity);
            }
        }
        //SFEUCMSD-134 The Payment Date travels in the same update as the stage, a later update could be overwritten by NPSP async jobs
        PaymentTriggerService.applyLatestPaymentDate(closedWonOpportunities);

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
