# gcloud-sql-kasten
This repo provides an example on how Kasten can backup and restore Google's Cloud SQL instance.

## What is Google's Cloud SQL?

Cloud SQL is a fully managed relational database service from Google for MySQL, PostgreSQL, and SQL Server. This makes it a good target for applications running on kubernetes to use Cloud SQL as a data service. In such scenarios, when Kasten is used for data protection of kubernetes applications, it is also essential that the Cloud SQL instance is protected at the same time. In the event of a disaster both the kubernetes components and the data service used by the applications can be restored to the same point in time resulting in an application consistent data protection. 

Cloud SQL supports performing on-demand managed backups as well database exports using gcloud SDK. In this repo, I talk about using Kasten blueprints to cover both these methods. 

## Method 1 : On-demand Managed Backups

Though Cloud SQL supports Automated backups, on-demand backups are always useful if you don't want to wait for the backup window. On-demand backups are not deleted using the set retention policies making it ideal to manage it's lifecycle using Kasten.  

Pre-Requisites

Create a service account with required permissions

Create a google service account to perform the backup and restore operations and grant the required IAM roles to operate on the Cloud SQL instance. 

 ```

