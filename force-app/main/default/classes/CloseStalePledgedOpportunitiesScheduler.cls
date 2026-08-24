//String cron = '0 0 * * * ?'; // every hour
//System.schedule('Close stale pledged opps hourly', cron, new CloseStalePledgedOpportunitiesScheduler());
global class CloseStalePledgedOpportunitiesScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new CloseStalePledgedOpportunitiesBatch(), 200);
    }
}
