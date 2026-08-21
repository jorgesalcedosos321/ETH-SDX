/**
 * Service responsible for Campaign operations.
 */
public inherited sharing class CampaignService {
    /**
     * Returns the Campaign Id from the external campaign value.
     */
    //SFESWCSD-92
    public static Id getCampaignId(
        DonationRequest request
    ) {
        if (String.isBlank(request.campaign)) {
            return null;
        }

        List<Campaign> campaigns = [
            SELECT Id
            FROM Campaign
            WHERE Campaign_ID__c = :request.campaign
            LIMIT 1
        ];

        if (campaigns.isEmpty()) {
            throw new DonationException(
                'Campaign not found: ' + request.campaign
            );
        }

        return campaigns[0].Id;
    }
}