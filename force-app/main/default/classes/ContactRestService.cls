@RestResource(urlMapping='/contacts')
global with sharing class ContactRestService {
    
    @HttpGet
    global static List<Contact> getAllContacts() {
        return [SELECT Id, Name, Email, Phone FROM Contact LIMIT 100];
    }
}