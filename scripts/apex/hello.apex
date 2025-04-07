// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

LIST <GDPR_Field_Cleanup__mdt> L =[SELECT Field_API_Name__c, Anonymization_Type__c FROM GDPR_Field_Cleanup__mdt];