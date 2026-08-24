global class CloseStalePledgedOpportunitiesBatch implements Database.Batchable<SObject> {
    global Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime cutoff = Datetime.now().addHours(-24);

        return Database.getQueryLocator([
            SELECT Id, StageName
            FROM Opportunity
            WHERE StageName = :ApiConstants.STAGE_PLEDGED
            AND CreatedDate <= :cutoff
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        List<Opportunity> oppsToClose = new List<Opportunity>();

        for (Opportunity opp : scope) {
            opp.StageName = 'Closed Lost';
            oppsToClose.add(opp);
        }

        Database.SaveResult[] results = Database.update(oppsToClose, false);

        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                System.debug('Updated successfully: ' + sr.getId());
            } else {
                for (Database.Error err : sr.getErrors()) {
                    System.debug('Error updating Opportunity: ' + err.getStatusCode() + ' - ' + err.getMessage());
                    System.debug('Fields affected: ' + err.getFields());
                }
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        // Intentionally left blank. The batch can be scheduled to run periodically.
    }
}
