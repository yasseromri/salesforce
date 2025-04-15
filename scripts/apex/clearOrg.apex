list <Case> cases = [
    SELECT Id
      FROM Case];
List<Contact> contacts=[
    select Id
      from Contact 
];

List<Account> Accounts=[
    select Id
      from Account 
];

List <Individual> Individuals=[ 
  select Id
      from Individual
];
List <Contract> Contracts=[ 
  select Id
      from Contract
];
List <Opportunity> Opportunitys=[ 
  select Id
      from Opportunity
];
delete Opportunitys ;
delete Contracts;
delete cases;
delete contacts;
delete  Individuals;
delete Accounts ; 

    