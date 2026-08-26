@IsTest
private class ValidationServiceTest {
    @IsTest
    static void validatesRequiredDonorFields() {
        assertValidationError(null, 'Request cannot be null.');
        assertValidationError(new DonationRequest(), 'Donor Type is required.');

        DonationRequest corporate = validRequest();
        corporate.donorType = ApiConstants.DONOR_CORPORATE;
        corporate.accountName = null;
        assertValidationError(
            corporate,
            'Account name is required for corporate donors.'
        );

        DonationRequest individual = validRequest();
        individual.firstName = null;
        assertValidationError(individual, 'First Name is required.');

        individual = validRequest();
        individual.lastName = null;
        assertValidationError(individual, 'Last Name is required.');

        individual = validRequest();
        individual.email = 'invalid-email';
        assertValidationError(individual, 'Email is required.');
    }

    @IsTest
    static void validatesDonationPaymentSponsorshipAndConsent() {
        DonationRequest request = validRequest();
        request.donationAmount = 0;
        assertValidationError(request, 'Amount must be greater than zero.');

        request = validRequest();
        request.paymentType = null;
        assertValidationError(request, 'Payment Type is required.');

        request = validRequest();
        request.campaignId = null;
        assertValidationError(request, 'Campaign is required.');

        request = validRequest();
        request.paymentMethod = null;
        assertValidationError(request, 'Payment Method is required.');

        request = validRequest();
        request.donationType = ApiConstants.DONATION_SPONSORSHIP;
        request.sponsorshipType = null;
        assertValidationError(request, 'Sponsorship Type is required.');

        request = validRequest();
        request.personalDataConsent = false;
        assertValidationError(request, 'Personal Data Consent is required.');
    }

    @IsTest
    static void acceptsValidRequestAndEmail() {
        ValidationService.validate(validRequest());
        Assert.isTrue(ValidationService.isValidEmail('donor@example.org'));
        Assert.isFalse(ValidationService.isValidEmail(null));
    }

    private static DonationRequest validRequest() {
        DonationRequest request = new DonationRequest();
        request.donorType = ApiConstants.DONOR_INDIVIDUAL;
        request.donationType = ApiConstants.DONATION_ONE_OFF;
        request.firstName = 'Valid';
        request.lastName = 'Donor';
        request.email = 'valid.donor@example.org';
        request.donationAmount = 25;
        request.paymentType = ApiConstants.PAYMENT_ONE_TIME;
        request.campaignId = 'VALIDATION-CAMPAIGN';
        request.paymentMethod = ApiConstants.PAYMENT_CARD;
        request.personalDataConsent = true;
        return request;
    }

    private static void assertValidationError(
        DonationRequest request,
        String expectedMessage
    ) {
        try {
            ValidationService.validate(request);
            Assert.fail('Expected a DonationValidationException.');
        } catch (DonationValidationException ex) {
            Assert.areEqual(expectedMessage, ex.getMessage());
        }
    }
}
