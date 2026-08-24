@isTest
private class CloseStalePledgedOpportunitiesBatchTest {
    @isTest
    static void closesOnlyStalePledgedOpportunities() {
        Opportunity staleOpp = new Opportunity(
            Name = 'Stale Pledged Opportunity',
            StageName = ApiConstants.STAGE_PLEDGED,
            CloseDate = Date.today()
        );
        insert staleOpp;
        Test.setCreatedDate(staleOpp.Id, Datetime.now().addHours(-25));

        Opportunity freshOpp = new Opportunity(
            Name = 'Fresh Pledged Opportunity',
            StageName = ApiConstants.STAGE_PLEDGED,
            CloseDate = Date.today()
        );
        insert freshOpp;

        Test.startTest();
        Database.executeBatch(new CloseStalePledgedOpportunitiesBatch(), 200);
        Test.stopTest();

        Opportunity updatedStaleOpp = [
            SELECT StageName
            FROM Opportunity
            WHERE Id = :staleOpp.Id
        ];

        Opportunity updatedFreshOpp = [
            SELECT StageName
            FROM Opportunity
            WHERE Id = :freshOpp.Id
        ];

        System.assertEquals(ApiConstants.STAGE_CLOSED_LOST, updatedStaleOpp.StageName);
        System.assertEquals(ApiConstants.STAGE_PLEDGED, updatedFreshOpp.StageName);
    }
}
