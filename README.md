# gcloud-sql-kasten
This repo provides an example on how Kasten can backup and restore Google's Cloud SQL instance.

## What is Google's Cloud SQL?

Cloud SQL is a fully managed relational database service from Google for MySQL, PostgreSQL, and SQL Server. This makes it a good target for applications running on kubernetes to use Cloud SQL as a data service. In such scenarios, when Kasten is used for data protection of kubernetes applications, it is also essential that the Cloud SQL instance is protected at the same time. In the event of a disaster both the kubernetes components and the data service used by the applications can be restored to the same point in time resulting in an application consistent data protection. 

Cloud SQL supports performing on-demand managed backups as well database exports using gcloud SDK. In this repo, I talk about using Kasten blueprints to cover both these methods. 

## Method 1 : On-demand Managed Backups

Though Cloud SQL supports automated backups, on-demand backups are always useful if you don't want to wait for the backup window. It is extremely useful on scenarios where you would like to capture the state of the instance before applying a change. On-demand backups are not deleted using the set retention policies making it ideal to manage it's lifecycle using Kasten.  

1. Create a google service account and grant the required IAM roles to operate on the Cloud SQL instance.

```
PROJECT_ID="rich-access-174020"
CLOUD_SQL_SA="cloudsqlmanager"
INSTANCE_NAME="k10sqlinst"

gcloud config set project $PROJECT_ID
gcloud iam service-accounts create $CLOUD_SQL_SA --display-name="Service Account for Cloud SQL Data Protection"
gcloud iam service-accounts keys create --iam-account=$CLOUD_SQL_SA@$PROJECT_ID.iam.gserviceaccount.com $CLOUD_SQL_SA-sa-key.json
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$CLOUD_SQL_SA@$PROJECT_ID.iam.gserviceaccount.com --role roles/cloudsql.admin
```

Run a quick test to ensure the service account works as expected. The command list the current backups that exist for the specified SQL instance.

```
gcloud config set project $PROJECT_ID
gcloud auth activate-service-account --key-file=$CLOUD_SQL_SA-sa-key.json
gcloud sql backups list --instance ${INSTANCE_NAME}
```

2. Create a secret on the application namespace that holds the service account authentication json, Cloud SQL instance to be protected and the project id.

In this example, I set the application namespace to `gcloud-sql`
```
kubectl create ns gcloud-sql
oc create secret generic gcloud-sql-secret -n gcloud-sql \
  --from-file=json-file=$CLOUD_SQL_SA-sa-key.json \
  --from-literal=project=$PROJECT_ID \
  --from-literal=instance_name=$INSTANCE_NAME
```

3. Create the blueprint and annotate the secret

```
kubectl create -n kasten-io -f gcloud-sql-backup-bp.yaml
kubectl annotate secret gcloud-sql-secret kanister.kasten.io/blueprint=gcloud-sql-backup-bp
```

4. Create a Kasten policy to backup the `gcloud-sql` namespace. When the policy is run, kasten will auto-detect based on the annotation from step 3 and run the backup phase of the blueprint to create an on-demand backup of the SQL Instance. When performing a Kasten restore of the namespace, the restore action of the blueprint will perform the point-in-time restore of the SQL instance.

## Method 2: Backups using Database exports

Even though Cloud SQL on-demand backups are not deleted based on the retention policies of automated backups, the on-demand backups can be lost in the event the instance is deleted.  Cloud SQL also allows to export data of the full instance or a specific database in the instance as a SQL dump file to the Google storage bucket. In this method, I walk through the steps on how backups and restore can be performed using gcloud sql export and import.

1. Create a Google service account and grant the required IAM roles to operate on the Cloud SQL instance and the Google storage bucket.

```
PROJECT_ID="rich-access-174020"
CLOUD_SQL_SA="cloudsqlmanager"
INSTANCE_NAME="k10sqlinst"
BUCKET_NAME="cloudsql-sm-backup"

gcloud config set project $PROJECT_ID
gcloud iam service-accounts create $CLOUD_SQL_SA --display-name="Service Account for Cloud SQL Data Protection"
gcloud iam service-accounts keys create --iam-account=$CLOUD_SQL_SA@$PROJECT_ID.iam.gserviceaccount.com $CLOUD_SQL_SA-sa-key.json
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$CLOUD_SQL_SA@$PROJECT_ID.iam.gserviceaccount.com --role roles/cloudsql.admin
gsutil iam ch serviceAccount:$CLOUD_SQL_SA@$PROJECT_ID.iam.gserviceaccount.com:roles/storage.admin gs://${BUCKET_NAME}
```

Retrieve the Service Account of the Cloud SQL instance and grant permissions to operate on the Google storage bucket

```
SA_EMAIL_ADDRESS=`gcloud sql instances describe ${INSTANCE_NAME} | grep serviceAccountEmailAddress | awk '{print $2}'`
gsutil iam ch serviceAccount:${SA_EMAIL_ADDRESS}:roles/storage.objectAdmin gs://${BUCKET_NAME}
```

Run a quick test to ensure the service account works as expected. 

The following commands list the current backups that exist for the specified SQL instance.

```
gcloud config set project $PROJECT_ID
gcloud auth activate-service-account --key-file=$CLOUD_SQL_SA-sa-key.json
gcloud sql backups list --instance ${INSTANCE_NAME}

gsutil ls gs://${BUCKET_NAME}
```

The following commands writes a test file , copies to the bucket, lists the objects and removes the object

```
echo "Test file" > testaccess.txt
gsutil cp testaccess.txt gs://${BUCKET_NAME}
gsutil ls gs://${BUCKET_NAME}
gsutil rm -r gs://${BUCKET_NAME}/testaccess.txt
```

3. Create a secret on the application namespace that holds the service account authentication json, Cloud SQL instance to be protected, bucket name and the project id.

In this example, I set the application namespace to `gcloud-sql`

```
kubectl create ns gcloud-sql
oc create secret generic gcloud-sql-secret -n gcloud-sql \
  --from-file=json-file=$CLOUD_SQL_SA-sa-key.json \
  --from-literal=project_id=$PROJECT_ID \
  --from-literal=instance_name=$INSTANCE_NAME \
  --from-literal=bucket_name=$BUCKET_NAME
```

4. Create the blueprint and annotate the secret

```
kubectl create -n kasten-io -f gcloud-sql-export-bp.yaml
kubectl annotate secret gcloud-sql-secret kanister.kasten.io/blueprint=gcloud-sql-export-bp
```

5. Create a Kasten policy to backup the `gcloud-sql` namespace. When the policy is run, kasten will auto-detect based on the annotation from step 3 and run the backup phase of the blueprint to create an on-demand backup of the SQL Instance. When performing a Kasten restore of the namespace, the restore action of the blueprint will perform the point-in-time restore of the SQL instance.

   

