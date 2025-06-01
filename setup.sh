# install Java
echo "installing java-21-amazon-corretto-devel ..." >> setup.log
sudo yum install -y java-21-amazon-corretto-devel

echo "copying cacerts to kafka_truststore.jks ..." >> setup.log
cp /usr/lib/jvm/java-21-amazon-corretto.x86_64/lib/security/cacerts kafka_truststore.jks

# Couchbase connector
echo "downloading couchbase-kafka-connect-couchbase-4.2.8.zip ..." >> setup.log
wget https://packages.couchbase.com/clients/kafka/4.2.8/couchbase-kafka-connect-couchbase-4.2.8.zip

echo "copying couchbase-kafka-connect-couchbase-4.2.8.zip to s3://$1 ..." >> setup.log
aws s3 cp couchbase-kafka-connect-couchbase-4.2.8.zip s3://$1

# Amazon DocumentDB connector
echo "create directories for Amazon DocumentDB custom plugin ..." >> setup.log
cd /home/ec2-user
mkdir -p docdb-custom-plugin
mkdir -p docdb-custom-plugin/mongo-connector
mkdir -p docdb-custom-plugin/msk-config-providers

echo "downloading mongo-kafka-connect-1.15.0-all.jar ..." >> setup.log
cd /home/ec2-user/docdb-custom-plugin/mongo-connector
wget https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/1.15.0/mongo-kafka-connect-1.15.0-all.jar

echo "downloading msk-config-providers-0.3.1-with-dependencies.zip ..." >> /home/ec2-user/setup.log
cd /home/ec2-user/docdb-custom-plugin/msk-config-providers
wget https://github.com/aws-samples/msk-config-providers/releases/download/r0.3.1/msk-config-providers-0.3.1-with-dependencies.zip

echo "unzipping msk-config-providers-0.3.1-with-dependencies.zip ..." >> /home/ec2-user/setup.log
unzip msk-config-providers-0.3.1-with-dependencies.zip

echo "deleting msk-config-providers-0.3.1-with-dependencies.zip ..." >> /home/ec2-user/setup.log
rm msk-config-providers-0.3.1-with-dependencies.zip

echo "creating docdb-custom-plugin.zip ..." >> /home/ec2-user/setup.log
cd /home/ec2-user
zip -r docdb-custom-plugin.zip docdb-custom-plugin

echo "creating docdb-custom-plugin.zip to s3://$1 ..." >> setup.log
aws s3 cp docdb-custom-plugin.zip s3://$1

# Kafka
echo "downloading kafka_2.13-4.0.0.tgz ..." >> setup.log
wget https://dlcdn.apache.org/kafka/4.0.0/kafka_2.13-4.0.0.tgz

echo "extracting kafka_2.13-4.0.0.tgz ..." >> setup.log
tar -xzf kafka_2.13-4.0.0.tgz

# AWS MSK IAM auth
echo "downloading aws-msk-iam-auth-2.3.2-all.jar ..." >> setup.log
wget https://github.com/aws/aws-msk-iam-auth/releases/download/v2.3.2/aws-msk-iam-auth-2.3.2-all.jar

echo "copying aws-msk-iam-auth-2.3.2-all.jar to kafka_2.13-4.0.0/libs/. ..." >> setup.log
cp aws-msk-iam-auth-2.3.2-all.jar kafka_2.13-4.0.0/libs/.

# Mongo shell
echo "installing mongodb-mongosh-shared-openssl3 ..." >> setup.log
echo -e "[mongodb-org-5.0] \nname=MongoDB Repository\nbaseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/5.0/x86_64/\ngpgcheck=1 \nenabled=1 \ngpgkey=https://pgp.mongodb.com/server-5.0.asc" | sudo tee /etc/yum.repos.d/mongodb-org-5.0.repo
sudo yum install -y mongodb-mongosh-shared-openssl3

# create Amazon DocumentDB trust store
echo "downloading https://raw.githubusercontent.com/dugbonsai/msk/refs/heads/main/createTruststore.sh ..." >> setup.log
wget https://raw.githubusercontent.com/dugbonsai/msk/refs/heads/main/createTruststore.sh

echo "making createTruststore.sh executable ..." >> setup.log
chmod 755 createTruststore.sh

echo "executing createTruststore.sh ..." >> setup.log
./createTruststore.sh

echo "copying docdb-truststore.jks to s3://$1 ..." >> setup.log
aws s3 cp docdb-truststore.jks s3://$1

# create Kafka client properties file
echo "creating /home/ec2-user/kafka_2.13-4.0.0/config/client.properties ..." >> setup.log
echo "ssl.truststore.location=/home/ec2-user/kafka_truststore.jks" >> kafka_2.13-4.0.0/config/client.properties
echo "security.protocol=SASL_SSL" >> kafka_2.13-4.0.0/config/client.properties
echo "sasl.mechanism=AWS_MSK_IAM " >> kafka_2.13-4.0.0/config/client.properties
echo "sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;" >> kafka_2.13-4.0.0/config/client.properties
echo "sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler" >> kafka_2.13-4.0.0/config/client.properties

# create Couchbase custom plugin
echo "creating Couchbase custom plugin JSON ..." >> setup.log
echo -e "{" >> couchbase-custom-plugin.json
echo -e "    \"name\": \"couchbase-custom-plugin\"," >> couchbase-custom-plugin.json
echo -e "    \"contentType\": \"ZIP\"," >> couchbase-custom-plugin.json
echo -e "    \"location\": {" >> couchbase-custom-plugin.json
echo -e "        \"s3Location\": {" >> couchbase-custom-plugin.json
echo -e "            \"bucketArn\": \"arn:aws:s3:::$1\"," >> couchbase-custom-plugin.json
echo -e "            \"fileKey\": \"couchbase-kafka-connect-couchbase-4.2.8.zip\"" >> couchbase-custom-plugin.json
echo -e "        }" >> couchbase-custom-plugin.json
echo -e "    }" >> couchbase-custom-plugin.json
echo -e "}" >> couchbase-custom-plugin.json

echo "creating Couchbase custom plugin ..." >> setup.log
aws kafkaconnect create-custom-plugin --cli-input-json file://couchbase-custom-plugin.json

# create DocumentDB custom plugin
echo "creating DocumentDB custom plugin JSON ..." >> setup.log
echo -e "{" >> documentdb-custom-plugin.json
echo -e "    \"name\": \"documentdb-custom-plugin\"," >> documentdb-custom-plugin.json
echo -e "    \"contentType\": \"ZIP\"," >> documentdb-custom-plugin.json
echo -e "    \"location\": {" >> documentdb-custom-plugin.json
echo -e "        \"s3Location\": {" >> documentdb-custom-plugin.json
echo -e "            \"bucketArn\": \"arn:aws:s3:::$1\"," >> documentdb-custom-plugin.json
echo -e "            \"fileKey\": \"docdb-custom-plugin.zip\"" >> documentdb-custom-plugin.json
echo -e "        }" >> documentdb-custom-plugin.json
echo -e "    }" >> documentdb-custom-plugin.json
echo -e "}" >> documentdb-custom-plugin.json

echo "creating DocumentDB custom plugin ..." >> setup.log
aws kafkaconnect create-custom-plugin --cli-input-json file://documentdb-custom-plugin.json

# setup complete
echo "setup complete ..." >> setup.log
