//SFESWCSD-92
public inherited sharing class ValidationService {

    public static void validate(DonationRequest request) {

        if (request == null) {
            throw new DonationValidationException('Request cannot be null.');
        }

        validateDonor(request);
        validateDonation(request);
        validatePayment(request);
        validateSponsorship(request);
        validateConsent(request);

    }

    private static void validateDonor(DonationRequest request) {

        if (String.isBlank(request.donorType)) {
            throw new DonationValidationException('Donor Type is required.');
        }

        if (request.donorType.equalsIgnoreCase(ApiConstants.DONOR_CORPORATE)) {
            if (String.isBlank(request.accountName)) {
                throw new DonationValidationException(
                    'Account name is required for corporate donors.'
                );
            }
        } else {
            if (String.isBlank(request.firstName)) {
                throw new DonationValidationException('First Name is required.');
            }

            if (String.isBlank(request.lastName)) {
                throw new DonationValidationException('Last Name is required.');
            }

            if (String.isBlank(request.email)) {
                throw new DonationValidationException('Email is required.');
            }
        }

    }

    private static void validateDonation(DonationRequest request) {

        if (request.donationAmount == null || request.donationAmount <= 0) {
            throw new DonationValidationException('Amount must be greater than zero.');
        }

        if (String.isBlank(request.paymentType)) {
            throw new DonationValidationException('Payment Type is required.');
        }

        if (String.isBlank(request.campaign)) {
            throw new DonationValidationException('Campaign is required.');
        }

    }

    private static void validatePayment(DonationRequest request) {

        if (String.isBlank(request.paymentMethod)) {
            throw new DonationValidationException('Payment Method is required.');
        }

    }

    private static void validateSponsorship(DonationRequest request) {

        if (request.donationType != ApiConstants.DONATION_SPONSORSHIP) {
            return;
        }

        if (String.isBlank(request.sponsorshipType)) {
            throw new DonationValidationException('Sponsorship Type is required.');
        }

    }

    private static void validateConsent(DonationRequest request) {

        if (request.personalDataConsent == null ||
            !request.personalDataConsent) {

            throw new DonationValidationException(
                'Personal Data Consent is required.'
            );

        }

    }

}
