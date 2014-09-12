# BWSQlite3ORM

This is just a simple object-relational mapping set of classes for SQLite3.

It’s really easy to use, just make a data model and make it subclass of BWDataModel class, and a table will be created automatically, you can use the CRUD methods to get the info.

You can also make queries, for now they all are Select queries, you just have to make the string assuming the next is before “SELECT * FROM (table Name)” + your query.

For now the types that can be stored are :

- int, float, double, bool, NSString
- NSArray, NSMutableArray, NSDictionary, NSMutableDictionary
- NSDate

For now queries works only for the first ones, also NSDate if you convert it to timeIntervalSince1970 in your query.

Enjoy =)

# TODO List

- Include Transactions
- Store other BWDataModels
- Store NSData
- Define type of attributes based on property types when the table is created (right now they all are strings)

Author
----
Rodrigo Gálvez

Version
----

1.0

License
----

MIT


**Free Software, Hell Yeah!**
