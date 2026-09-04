@IsTest
private class DLE_EmailTemplateAttachmentResolverTest {
    @IsTest
    static void convertsContentVersionsToEmailAttachments() {
        List<Messaging.EmailFileAttachment> attachments =
            DLE_EmailTemplateAttachmentResolver.toEmailFileAttachments(
                new List<ContentVersion>{
                    new ContentVersion(
                        Title = 'Donation receipt',
                        VersionData = Blob.valueOf('PDF content')
                    )
                }
            );

        Assert.areEqual(1, attachments.size());
        Assert.areEqual(
            'Donation receipt.pdf',
            DLE_EmailTemplateAttachmentResolver.fileName(
                'Donation receipt',
                'pdf'
            )
        );
        Assert.areEqual(
            'Terms.txt',
            DLE_EmailTemplateAttachmentResolver.fileName('Terms.txt', 'txt')
        );
    }

    @IsTest
    static void returnsNoAttachmentsForNullTemplate() {
        Assert.areEqual(
            0,
            DLE_EmailTemplateAttachmentResolver.resolve(null).size()
        );
    }
}
