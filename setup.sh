# install Java
sudo yum install -y java-21-amazon-corretto-devel
cp /usr/lib/jvm/java-21-amazon-corretto.x86_64/lib/security/cacerts kafka_truststore.jks

# Couchbase connector
wget https://packages.couchbase.com/clients/kafka/4.2.8/couchbase-kafka-connect-couchbase-4.2.8.zip
aws s3 cp couchbase-kafka-connect-couchbase-4.2.8.zip s3://dbonser-msk-bucket

# Amazon DocumentDB connector
cd ~
mkdir -p docdb-custom-plugin
mkdir -p docdb-custom-plugin/mongo-connector
mkdir -p docdb-custom-plugin/msk-config-providers
cd ~/docdb-custom-plugin/mongo-connector
wget https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/1.15.0/mongo-kafka-connect-1.15.0-all.jar
cd ~/docdb-custom-plugin/msk-config-providers
wget https://github.com/aws-samples/msk-config-providers/releases/download/r0.3.1/msk-config-providers-0.3.1-with-dependencies.zip
unzip msk-config-providers-0.3.1-with-dependencies.zip
rm msk-config-providers-0.3.1-with-dependencies.zip
cd ~
zip -r docdb-custom-plugin.zip docdb-custom-plugin
aws s3 cp docdb-custom-plugin.zip s3://dbonser-msk-bucket

# Kafka
wget https://dlcdn.apache.org/kafka/4.0.0/kafka_2.13-4.0.0.tgz
tar -xzf kafka_2.13-4.0.0.tgz

# AWS MSK IAM auth
wget https://github.com/aws/aws-msk-iam-auth/releases/download/v2.3.2/aws-msk-iam-auth-2.3.2-all.jar
cp aws-msk-iam-auth-2.3.2-all.jar kafka_2.13-4.0.0/libs/.

# Mongo shell
echo -e "[mongodb-org-5.0] \nname=MongoDB Repository\nbaseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/5.0/x86_64/\ngpgcheck=1 \nenabled=1 \ngpgkey=https://pgp.mongodb.com/server-5.0.asc" | sudo tee /etc/yum.repos.d/mongodb-org-5.0.repo
sudo yum install -y mongodb-mongosh-shared-openssl3

# create Amazon DocumentDB trust store
wget https://raw.githubusercontent.com/dugbonsai/msk/refs/heads/main/createTruststore.sh
chmod 755 createTruststore.sh
./createTruststore.sh
aws s3 cp docdb-truststore.jks s3://dbonser-msk-bucket