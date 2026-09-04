/**
 * Instance-supplied hook that produces per-recipient file attachments for a
 * Donor Lifecycle Engine send.
 *
 * An org that needs personalized attachments (e.g. a PDF certificate rendered
 * from a Visualforce page) writes a class implementing this interface and names
 * it on DLE_Email_Dispatch_Config__mdt.Attachment_Provider_Class__c. The engine
 * instantiates that class once per dispatch (Type.forName + newInstance) and
 * calls getAttachments(whoId, whatId) for every eligible recipient, attaching the
 * result to that recipient's message.
 *
 * Implementations live in the subscriber org and may reference NPSP or
 * Visualforce pages freely - none of that belongs in this package. The class
 * must have a public no-arg constructor.
 *
 * If getAttachments throws for a recipient, the engine skips only that recipient
 * and records a Failed DLE_Email_Log__c row - no broken email is sent.
 *
 * Note: Visualforce getContentAsPDF() is capped per transaction (about 10), so
 * events that use a provider should be sent in small batches.
 */
public interface DLE_EmailAttachmentProvider {
    /**
     * @param whoId  Recipient - Contact, Lead or User.
     * @param whatId Related record for this recipient (may be null).
     * @return Attachments for this recipient's email; null or empty means none.
     */
    List<Messaging.EmailFileAttachment> getAttachments(Id whoId, Id whatId);
}