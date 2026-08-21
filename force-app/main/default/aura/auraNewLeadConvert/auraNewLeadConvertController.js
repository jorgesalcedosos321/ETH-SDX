({
    loadLeadData : function(component, event, helper) {
        //alert("a");
        component.set("v.loading", true);        
        helper.fillOpportunityRecordTypes(component, event, helper);
        helper.fillLead(component, event, helper);
        component.set("v.loading", false);        
    },
    convertLead : function(component, event, helper) {
        component.set("v.loading", true);
        var actionConvertion = component.get("c.convertLeadById");
        var selectedOptionValue = component.get("v.selectedOptionValue");
        var createOpps = component.get("v.showRT");
        
        // Get the Lead ID and custom field values
        actionConvertion.setParams({ "leadId": component.get("v.recordId"), "createOpps": createOpps, "oppRT": selectedOptionValue });

        // Set up a callback to handle the response
        actionConvertion.setCallback(this, function(response) {
            var state = response.getState();
            console.log('state:' + state);
            console.log('state JSON.stringify:' + JSON.stringify(response));
            //console.log('response.getReturnValue():' + response.getReturnValue());
            
            if (state === "SUCCESS") {
                // If successful, update the message
                component.set("v.isError", false);
                component.set("v.conversionMessage", response.getReturnValue());                
                helper.showToast(component, event, helper);
                helper.redirectPage(component, event, helper);
                component.set("v.disableButton", true);                
                //component.set("v.isAlreadyConverted", true);
            } else if (state === "ERROR") {
                var errors = response.getError();
                component.set("v.conversionMessage", errors ? errors[0].message : "An unknown error occurred.");
                component.set("v.isError", true);
                helper.showToast(component, event, helper);
            }
            component.set("v.loading", false);
        });

        $A.enqueueAction(actionConvertion);
    }
})