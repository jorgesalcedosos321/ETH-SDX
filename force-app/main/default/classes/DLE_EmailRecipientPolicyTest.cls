@IsTest
private class DLE_EmailRecipientPolicyTest {
  /** A portable rule: Title is a text field present and writable on both Contact and Lead. */
  private static void overrideWithTitleRule(String sobjectType) {
    DLE_EmailRecipientPolicy.rulesOverride = new List<DLE_Recipient_Suppression__mdt>{
      new DLE_Recipient_Suppression__mdt(
        Target_SObject__c = sobjectType,
        Field_API_Name__c = 'Title',
        Block_When_Value__c = 'BLOCKED'
      )
    };
  }

  @IsTest
  static void contactBlockedWhenFieldMatchesConfiguredValue() {
    overrideWithTitleRule('Contact');
    Contact blocked = new Contact(
      FirstName = 'DLE',
      LastName = 'Blocked',
      Title = 'BLOCKED'
    );
    Contact ok = new Contact(
      FirstName = 'DLE',
      LastName = 'Ok',
      Title = 'Donor'
    );
    insert new List<Contact>{ blocked, ok };

    Map<Id, DLE_EmailRecipientPolicy.Eligibility> res = DLE_EmailRecipientPolicy.evaluateWhoIds(
      new Set<Id>{ blocked.Id, ok.Id }
    );

    System.assertEquals(false, res.get(blocked.Id).allowed);
    System.assert(
      res.get(blocked.Id).reason.contains('Title'),
      res.get(blocked.Id).reason
    );
    System.assertEquals(true, res.get(ok.Id).allowed);
    System.assertEquals(null, res.get(ok.Id).reason);
  }

  @IsTest
  static void matchIsCaseInsensitive() {
    overrideWithTitleRule('Contact');
    Contact c = new Contact(
      FirstName = 'DLE',
      LastName = 'X',
      Title = 'blocked'
    );
    insert c;

    System.assertEquals(false, DLE_EmailRecipientPolicy.canSendTo(c.Id));
  }

  @IsTest
  static void differentValueDoesNotBlock() {
    overrideWithTitleRule('Contact');
    Contact c = new Contact(
      FirstName = 'DLE',
      LastName = 'X',
      Title = 'not blocked'
    );
    insert c;

    System.assertEquals(true, DLE_EmailRecipientPolicy.canSendTo(c.Id));
  }

  @IsTest
  static void leadRuleEvaluatedIndependently() {
    overrideWithTitleRule('Lead');
    Lead l = new Lead(
      FirstName = 'DLE',
      LastName = 'L',
      Company = 'C',
      Title = 'BLOCKED',
      Donation_Type__c = 'Recurring Donation' // Installment_Frequency__c defaults to Monthly, which requires it
    );
    insert l;

    System.assertEquals(false, DLE_EmailRecipientPolicy.canSendTo(l.Id));
  }

  @IsTest
  static void noActiveRulesAllowsEveryone() {
    DLE_EmailRecipientPolicy.rulesOverride = new List<DLE_Recipient_Suppression__mdt>();
    Contact c = new Contact(
      FirstName = 'DLE',
      LastName = 'X',
      Title = 'BLOCKED'
    );
    insert c;

    System.assertEquals(true, DLE_EmailRecipientPolicy.canSendTo(c.Id));
  }

  @IsTest
  static void ruleForMissingFieldIsIgnored() {
    DLE_EmailRecipientPolicy.rulesOverride = new List<DLE_Recipient_Suppression__mdt>{
      new DLE_Recipient_Suppression__mdt(
        Target_SObject__c = 'Contact',
        Field_API_Name__c = 'This_Field_Does_Not_Exist__c',
        Block_When_Value__c = 'true'
      )
    };
    Contact c = new Contact(
      FirstName = 'DLE',
      LastName = 'X',
      Title = 'BLOCKED'
    );
    insert c;

    System.assertEquals(true, DLE_EmailRecipientPolicy.canSendTo(c.Id));
  }

  @IsTest
  static void unsupportedTypeRejected() {
    // Account is a supported recipient type; Opportunity is not.
    Account a = new Account(Name = 'Acme');
    insert a;
    Opportunity o = new Opportunity(
      Name = 'DLE Unsupported',
      StageName = 'Prospecting',
      CloseDate = Date.today(),
      AccountId = a.Id
    );
    insert o;

    Map<Id, DLE_EmailRecipientPolicy.Eligibility> res = DLE_EmailRecipientPolicy.evaluateWhoIds(
      new Set<Id>{ o.Id }
    );

    System.assertEquals(false, res.get(o.Id).allowed);
    System.assert(
      res.get(o.Id).reason.contains('Unsupported'),
      res.get(o.Id).reason
    );
  }

  @IsTest
  static void accountAllowedWhenNoRuleTargetsIt() {
    overrideWithTitleRule('Contact');
    Account a = new Account(Name = 'DLE Allowed Org');
    insert a;

    Map<Id, DLE_EmailRecipientPolicy.Eligibility> res = DLE_EmailRecipientPolicy.evaluateWhoIds(
      new Set<Id>{ a.Id }
    );

    System.assertEquals(
      true,
      res.get(a.Id).allowed,
      'Account should be allowed when no rule targets it'
    );
  }

  @IsTest
  static void accountBlockedByAccountRule() {
    // Rules are data, so an Account rule needs no code change - only a row naming a field
    // that exists on Account. Description is portable, unlike any opt-out field.
    DLE_EmailRecipientPolicy.rulesOverride = new List<DLE_Recipient_Suppression__mdt>{
      new DLE_Recipient_Suppression__mdt(
        Target_SObject__c = 'Account',
        Field_API_Name__c = 'Description',
        Block_When_Value__c = 'BLOCKED'
      )
    };
    Account blocked = new Account(
      Name = 'DLE Blocked Org',
      Description = 'BLOCKED'
    );
    Account ok = new Account(Name = 'DLE Sendable Org', Description = 'Donor');
    insert new List<Account>{ blocked, ok };

    Map<Id, DLE_EmailRecipientPolicy.Eligibility> res = DLE_EmailRecipientPolicy.evaluateWhoIds(
      new Set<Id>{ blocked.Id, ok.Id }
    );

    System.assertEquals(false, res.get(blocked.Id).allowed);
    System.assertEquals(
      true,
      res.get(ok.Id).allowed,
      'Account not matching the rule value should be allowed'
    );
  }

  @IsTest
  static void deletedRecipientReportedAsNotFound() {
    overrideWithTitleRule('Contact');
    Contact c = new Contact(
      FirstName = 'DLE',
      LastName = 'Gone',
      Title = 'Donor'
    );
    insert c;
    Id gone = c.Id;
    delete c;

    Map<Id, DLE_EmailRecipientPolicy.Eligibility> res = DLE_EmailRecipientPolicy.evaluateWhoIds(
      new Set<Id>{ gone }
    );

    System.assertEquals(false, res.get(gone).allowed);
    System.assertEquals('Recipient not found', res.get(gone).reason);
  }

  @IsTest
  static void nullAndEmptyInputAreSafe() {
    System.assertEquals(
      0,
      DLE_EmailRecipientPolicy.evaluateWhoIds(null).size()
    );
    System.assertEquals(
      0,
      DLE_EmailRecipientPolicy.evaluateWhoIds(new Set<Id>()).size()
    );
  }
}