list <Case> cases = [
    SELECT Id
      FROM Case];
List<Contact> contacts=[
    select Id
      from Contact 
];
delete cases;
delete contacts;

    