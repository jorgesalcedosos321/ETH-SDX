global class CloseStalePledgedOpportunitiesScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new CloseStalePledgedOpportunitiesBatch(), 200);
    }
}
