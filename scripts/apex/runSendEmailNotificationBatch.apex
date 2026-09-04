// Run this file as Anonymous Apex against the target org.
//
// IMPORTANT: This script uses the org's real data. Depending on TEMPLATE_KEY,
// the batch sends emails or creates Tasks. Always run the preview first.

String TEMPLATE_KEY = Utils.BIRTHDAY_EMAIL;
Boolean EXECUTE_FOR_REAL = false;
Integer BATCH_SIZE = 10;
Integer SAMPLE_SIZE = 20;

Set<String> supportedTemplateKeys = new Set<String>{
    Utils.ANNIVERSARY_EMAIL_1,
    Utils.BIRTHDAY_EMAIL,
    Utils.END_OF_YEAR_REPORT_P,
    Utils.LOYALTY_CALL_AFTER_6,
    Utils.MID_YEAR_REPORT_PDF,
    Utils.ONE_TIME_DONORS_LE,
    Utils.REMINDER_1,
    Utils.REMINDER_2,
    Utils.REMINDER_3
};

if (!supportedTemplateKeys.contains(TEMPLATE_KEY)) {
    throw new IllegalArgumentException(
        'Unsupported TEMPLATE_KEY: ' + TEMPLATE_KEY
    );
}

SendEmailNotificationBatch batch = new SendEmailNotificationBatch(TEMPLATE_KEY);

if (EXECUTE_FOR_REAL) {
    Id jobId = Database.executeBatch(batch, BATCH_SIZE);
    System.debug(LoggingLevel.WARN, 'REAL batch submitted. Job Id: ' + jobId);
} else {
    Database.QueryLocatorIterator records = batch.start(null).iterator();
    Integer candidateCount = 0;
    List<Id> sampleIds = new List<Id>();

    while (records.hasNext()) {
        sObject candidate = records.next();
        candidateCount++;
        if (sampleIds.size() < SAMPLE_SIZE) {
            sampleIds.add(candidate.Id);
        }
    }

    System.debug(LoggingLevel.WARN, 'PREVIEW ONLY - no emails or Tasks created.');
    System.debug(LoggingLevel.WARN, 'Template: ' + TEMPLATE_KEY);
    System.debug(LoggingLevel.WARN, 'Candidate records: ' + candidateCount);
    System.debug(LoggingLevel.WARN, 'Sample record Ids: ' + sampleIds);
    System.debug(
        LoggingLevel.WARN,
        'Review the candidates, then set EXECUTE_FOR_REAL = true to submit the batch.'
    );
}
