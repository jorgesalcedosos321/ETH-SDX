public with sharing class ContactHandler {
    final List<Contact> newRecords;
    final List<Contact> oldRecords;
    final Map<Id, Contact> oldMap; 
    
    public ContactHandler(List<Contact> newRecords, List<Contact> oldRecords, Map<Id, Contact> oldMap){
        this.newRecords = newRecords;
        this.oldRecords = oldRecords;
        this.oldMap = oldMap;
    }
        
    public void beforeInsert(){
        ContactService.setEmailField(newRecords);
    }
    
    public void afterInsert(){
        ContactService.calculateHouseholdMembersInAccount(newRecords);
        ContactService.sendBirthdayCard(newRecords, oldMap);
    }

    public void beforeUpdate(){        
        ContactService.setEmailField(newRecords);
    }
    
	public void afterUpdate(){
        ContactService.calculateHouseholdMembersInAccount(newRecords);
        ContactService.sendBirthdayCard(newRecords, oldMap);
    }
    
    public void afterDelete(){
        ContactService.calculateHouseholdMembersInAccount(oldRecords);
    }
}