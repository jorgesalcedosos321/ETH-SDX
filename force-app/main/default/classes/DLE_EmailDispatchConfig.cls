/**
 * Immutable view of a single DLE_Email_Dispatch_Config__mdt row, consumed by the
 * Donor Lifecycle Engine (DLE).
 */
public with sharing class DLE_EmailDispatchConfig {
    /** DLE_Email_Dispatch_Config__mdt.DeveloperName - the event key callers pass to the engine. */
    public final String developerName;
    /** Template_DeveloperName__c - DeveloperName of the Lightning Email Template to render. */
    public final String templateDevName;
    /** From_Address__c - Org-Wide Email Address Display Name or a verified email address. */
    public final String fromAddress;
    /** Is_Active__c - when false the engine skips this event entirely. */
    public final Boolean active;
    /**
     * Attachment_Provider_Class__c - API name of an instance-supplied Apex class
     * implementing DLE_EmailAttachmentProvider. Blank means no dynamic attachments.
     */
    public final String attachmentProviderClass;

    public DLE_EmailDispatchConfig(
            String developerName,
            String templateDevName,
            String fromAddress,
            Boolean active,
            String attachmentProviderClass
    ) {
        this.developerName = developerName;
        this.templateDevName = templateDevName;
        this.fromAddress = fromAddress;
        this.active = active;
        this.attachmentProviderClass = attachmentProviderClass;
    }
}