//SFESWCSD-113
@IsTest
private class UpdateOpportunityStatusesQueueableTest {

    //SFESWCSD-113
    private static List<Opportunity> createOpportunities(Integer count) {
        List<Opportunity> opportunities = new List<Opportunity>();
        for (Integer i = 0; i < count; i++) {
            opportunities.add(new Opportunity(
                    Name = 'Queueable Opportunity ' + i,
                    StageName = 'Prospecting',
                    CloseDate = Date.today().addDays(30)
            ));
        }
        insert opportunities;
        return opportunities;
    }

    //SFESWCSD-113
    @IsTest
    static void execute_updatesEachOpportunityWithItsStatus() {
        List<Opportunity> opportunities = createOpportunities(3);
        Map<String, Set<Id>> opportunityIdsByStatus = new Map<String, Set<Id>>{
                'Closed Won' => new Set<Id>{ opportunities[0].Id },
                'Declined' => new Set<Id>{ opportunities[1].Id },
                'Closed Lost' => new Set<Id>{ opportunities[2].Id }
        };

        Test.startTest();
        System.enqueueJob(new UpdateOpportunityStatusesQueueable(opportunityIdsByStatus));
        Test.stopTest();

        Map<Id, Opportunity> saved = new Map<Id, Opportunity>([SELECT StageName FROM Opportunity WHERE Id IN :opportunities]);
        System.assertEquals('Closed Won', saved.get(opportunities[0].Id).StageName);
        System.assertEquals('Declined', saved.get(opportunities[1].Id).StageName);
        System.assertEquals('Closed Lost', saved.get(opportunities[2].Id).StageName);
    }

    //SFESWCSD-113
    @IsTest
    static void execute_withoutOpportunities_changesNothing() {
        Opportunity untouched = createOpportunities(1)[0];

        Test.startTest();
        System.enqueueJob(new UpdateOpportunityStatusesQueueable(null));
        System.enqueueJob(new UpdateOpportunityStatusesQueueable(new Map<String, Set<Id>>()));
        Test.stopTest();

        System.assertEquals('Prospecting', [SELECT StageName FROM Opportunity WHERE Id = :untouched.Id].StageName);
    }

    //SFESWCSD-113
    @IsTest
    static void execute_invalidStatus_isLoggedAndKeepsTheCurrentStage() {
        Opportunity opportunity = createOpportunities(1)[0];

        Test.startTest();
        System.enqueueJob(new UpdateOpportunityStatusesQueueable(new Map<String, Set<Id>>{ 'Not A Stage' => new Set<Id>{ opportunity.Id } }));
        Test.stopTest();

        System.assertEquals('Not A Stage', [SELECT StageName FROM Opportunity WHERE Id = :opportunity.Id].StageName,
                'A failed update is only logged and the stage does not change.');
    }
}
