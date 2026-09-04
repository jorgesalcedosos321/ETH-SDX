/**
 * Loads Salesforce Files related to an EmailTemplate and converts their latest
 * published versions into email file attachments.
 */
public with sharing class DLE_EmailTemplateAttachmentResolver {
    public static List<Messaging.EmailFileAttachment> resolve(Id templateId) {
        if (templateId == null) {
            return new List<Messaging.EmailFileAttachment>();
        }

        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :templateId
        ]) {
            contentDocumentIds.add(link.ContentDocumentId);
        }
        if (contentDocumentIds.isEmpty()) {
            return new List<Messaging.EmailFileAttachment>();
        }

        return toEmailFileAttachments([
            SELECT Title, FileExtension, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
                AND IsLatest = true
            ORDER BY Title
        ]);
    }

    @TestVisible
    private static List<Messaging.EmailFileAttachment> toEmailFileAttachments(
        List<ContentVersion> versions
    ) {
        List<Messaging.EmailFileAttachment> attachments =
            new List<Messaging.EmailFileAttachment>();
        for (ContentVersion version : versions) {
            Messaging.EmailFileAttachment attachment =
                new Messaging.EmailFileAttachment();
            attachment.setFileName(fileName(version.Title, version.FileExtension));
            attachment.setBody(version.VersionData);
            attachments.add(attachment);
        }
        return attachments;
    }

    @TestVisible
    private static String fileName(String title, String extension) {
        if (
            String.isNotBlank(extension) &&
            !title.toLowerCase().endsWith('.' + extension.toLowerCase())
        ) {
            return title + '.' + extension;
        }
        return title;
    }
}
