/**
 * Resolves a DLE_Email_Dispatch_Config__mdt.Attachment_Provider_Class__c value to
 * an instantiated DLE_EmailAttachmentProvider, and asks it for a recipient's
 * attachments.
 *
 * The provider class is instance-supplied Apex (see DLE_EmailAttachmentProvider).
 * We instantiate it by name via Type.forName + newInstance and cache the instance
 * for the life of the transaction, so one dispatch instantiates it once.
 *
 * A blank class name means "no dynamic attachments". An unrecognised or
 * non-conforming class name is a configuration error and throws - the engine
 * lets that abort the whole dispatch rather than silently send attachment-less
 * emails.
 */
public with sharing class DLE_EmailAttachmentResolver {

    /** Test seam: when set, this instance is used and no reflection is attempted. */
    @TestVisible
    private static DLE_EmailAttachmentProvider mock;

    private static final Map<String, DLE_EmailAttachmentProvider> CACHE =
            new Map<String, DLE_EmailAttachmentProvider>();

    /**
     * @return the provider named by className, or null when className is blank.
     * @throws IllegalArgumentException when className names no Apex class, or a
     *         class that does not implement DLE_EmailAttachmentProvider / has no
     *         public no-arg constructor.
     */
    public static DLE_EmailAttachmentProvider provider(String className) {
        if (String.isBlank(className)) {
            return null;
        }
        if (mock != null) {
            return mock;
        }
        String key = className.trim();
        if (CACHE.containsKey(key)) {
            return CACHE.get(key);
        }

        Type t = Type.forName(key);
        if (t == null) {
            throw new IllegalArgumentException(
                    'Unknown DLE attachment provider class: ' + key);
        }
        Object instance;
        try {
            instance = t.newInstance();
        } catch (Exception e) {
            throw new IllegalArgumentException(
                    'DLE attachment provider class ' + key
                    + ' could not be instantiated (needs a public no-arg constructor): '
                    + e.getMessage());
        }
        if (!(instance instanceof DLE_EmailAttachmentProvider)) {
            throw new IllegalArgumentException(
                    'DLE attachment provider class ' + key
                    + ' does not implement DLE_EmailAttachmentProvider');
        }
        DLE_EmailAttachmentProvider p = (DLE_EmailAttachmentProvider) instance;
        CACHE.put(key, p);
        return p;
    }

    /**
     * @return the attachments the configured provider returns for this recipient,
     *         or null when no provider is configured.
     * @throws whatever the provider throws from getAttachments - the caller
     *         (DLE_EmailDispatchService) catches it per recipient.
     */
    public static List<Messaging.EmailFileAttachment> resolve(
            String className,
            Id whoId,
            Id whatId
    ) {
        DLE_EmailAttachmentProvider p = provider(className);
        if (p == null) {
            return null;
        }
        return p.getAttachments(whoId, whatId);
    }
}