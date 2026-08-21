({
	showToast : function(component, event, helper) {
        var iserror = component.get("v.isError");
        var message = component.get("v.conversionMessage");
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": !iserror ? "Success!" : "Error!",
            "type":  !iserror ? "success" : "error",
            "message": message
        });
        toastEvent.fire();
    }, 
    redirectPage : function(component, event, helper) {
        window.setTimeout(() => {
            window.location.reload();
    	}, 3000);     	
    },
	fillOpportunityRecordTypes: function(component, event, helper) {
        var rts = component.get("c.getOpportunityRTs");
        rts.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var oppRts = response.getReturnValue();
                var opts = oppRts.map(opt => ({ value: opt.Id, label: opt.Name }));
                component.set("v.options", opts);
                component.set("v.selectedOptionValue", opts[0].value);
            } else if (state === "ERROR") {
                var errors = response.getError();
                component.set("v.conversionMessage", errors ? errors[0].message : "An unknown error occurred.");
            }
        });
        $A.enqueueAction(rts);
    },
	fillLead: function(component, event, helper) {
        var action = component.get("c.getLeadData");
        var leadId = component.get("v.recordId");
        action.setParams({
            "leadId": leadId
        });

        // Set up a callback to handle the response
        action.setCallback(this, function(response) {
            var state = response.getState();
            console.log('state init JSON.stringify:' + JSON.stringify(response));
            if (state === "SUCCESS") {
                var lead = response.getReturnValue();
                // Set the Lead data into the component's attribute
                component.set("v.lead", lead);
            } else if (state === "ERROR") {
                var errors = response.getError();
                component.set("v.conversionMessage", errors ? errors[0].message : "An unknown error occurred.");
            }
        });
        $A.enqueueAction(action);
    },
})