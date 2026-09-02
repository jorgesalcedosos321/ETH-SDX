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
        if (String.isBlank(request.campaignId)) {
            return null;
        }

        List<Campaign> campaigns = [
            SELECT Id
            FROM Campaign
            WHERE Campaign_ID__c = :request.campaignId
            LIMIT 1
        ];

        if (campaigns.isEmpty()) {
            return NULL;
            //throw new DonationException(
            //    'Campaign not found: ' + request.campaignId
            //);
        }

        return campaigns[0].Id;
    }
}