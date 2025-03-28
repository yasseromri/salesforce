list <Case> cases = [
    SELECT Id
      FROM Case];
List<Contact> contacts=[
    select Id
      from Contact 
];
List <Individual> Individuals=[ 
  select Id
      from Individual
];
delete cases;
delete contacts;
delete  Individuals;
    