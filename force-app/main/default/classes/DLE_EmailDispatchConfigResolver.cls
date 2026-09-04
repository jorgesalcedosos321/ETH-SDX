/**
 * Resolves an event key to its DLE_Email_Dispatch_Config__mdt configuration.
 *
 * Uses Custom Metadata getInstance(), so there is no SOQL cost. Results (including
 * misses) are cached for the life of the transaction.
 */
public with sharing class DLE_EmailDispatchConfigResolver {

    /** Test seam: when set, lookups are served from this map and metadata is never read. */
    @TestVisible
    private static Map<String, DLE_EmailDispatchConfig> mock;

    private static final Map<String, DLE_EmailDispatchConfig> CACHE =
            new Map<String, DLE_EmailDispatchConfig>();

    public static DLE_EmailDispatchConfig get(String developerName) {
        if (String.isBlank(developerName)) {
            return null;
        }
        String key = developerName.trim();

        if (mock != null) {
            return mock.get(key);
        }
        if (CACHE.containsKey(key)) {
            return CACHE.get(key);
        }

        DLE_Email_Dispatch_Config__mdt r = DLE_Email_Dispatch_Config__mdt.getInstance(key);
        DLE_EmailDispatchConfig cfg = (r == null)
                ? null
                : new DLE_EmailDispatchConfig(
                        r.DeveloperName,
                        r.Template_DeveloperName__c,
                        r.From_Address__c,
                        r.Is_Active__c,
                        r.Attachment_Provider_Class__c
                );
        CACHE.put(key, cfg);
        return cfg;
    }
}