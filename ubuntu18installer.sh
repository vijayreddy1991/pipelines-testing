!/bin/bash -e
echo "============install docker ==========================="
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "============== install-docker-compose ============================="

sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

echo "================ docker login ================"


sudo docker login docker.jfrog.io -u vijaykp -p $apikey

sudo docker login jfpip.jfrog.io -u vijaykp -p $apikey

sudo docker login entplus.jfrog.io -u vijaykp -p $apikey

echo "==============install jfrog cli ========="
curl -fL https://getcli.jfrog.io | sh
sudo chmod +x jfrog
sudo mv jfrog /usr/bin/jfrog

echo "============= setup entplus ======================"

jfrog config add entplus --artifactory-url=https://entplus.jfrog.io/artifactory --basic-auth-only=true --user=vijaykp --apikey=$apikey --interactive=false

echo "============= install artifactory =================="
export IP_ADDR=$(hostname -I | awk '{print $1}')
sudo docker run --name artifactory -d -p 8082:8082 -p 8081:8081 -e JF_SHARED_NODE_IP=$IP_ADDR docker.jfrog.io/jfrog/artifactory-pro:$ARTIFACTORY_VERSION

curl --head -X GET --retry 5 --retry-connrefused --retry-delay 30 http://$IP_ADDR:8082/artifactory/api/system/ping


echo "=====================adding artifactory license ========="
curl --request POST \
    --silent \
    --url "$IP_ADDR:8082/artifactory/api/system/licenses" \
    -u "admin:password" \
    --header 'Content-Type: application/json' \
    --data "{'licenseKey': "$licensekey"}" \
    > /dev/null

echo "============== download pipelines ==================="
jfrog rt dl --flat pipelines-installers/installer/pipelines-$pipelinesVersion.tar.gz
sudo tar -xzvf pipelines-$pipelinesVersion.tar.gz
cd pipelines-$pipelinesVersion

echo "==================== install pipelines ============="
export joinkey=$(sudo docker exec artifactory cat var/etc/security/join.key)
export masterkey=$(sudo docker exec artifactory cat var/etc/security/master.key)

sudo ./pipelines install    --base-url http://$IP_ADDR:8082    --base-url-ui http://$IP_ADDR:8082      --installer-ip $IP_ADDR      --api-url http://$IP_ADDR:8082/pipelines/api    --image-registry-url docker.jfrog.io     --artifactory-joinkey ${joinkey}     --devmode    --artifactory-masterkey ${masterkey}
