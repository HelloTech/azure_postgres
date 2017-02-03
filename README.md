<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fhellotech%2Fazure_postgres%2Fmaster%2Ftemplate.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="
http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fhellotech%2Fazure_postgres%2Fmaster%2Ftemplate.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>

# Highly-Available PostgreSQL Cluster (Patroni) on Azure

This one click deployment of a Highly-Available PostgreSQL Cluster on Azure has automated replication, server management and leader election. This project contains a modified deployment version of Haufe's [blog post](http://dev.haufe.com/PostgreSQL-Cluster-Azure/).

This Azure template generates two sets of machines both running Ubuntu 16.04 LTS. The first set of three machines are used to run the distributed configuration store [ZooKeeper](https://zookeeper.apache.org/), while the second set is running PostgreSQL 9.6 together with [Patroni](https://github.com/zalando/patroni) providing a high-availability customizable PostgreSQL cluster deployment. This deployment also includes [PL/V8 v.2.0.0](https://github.com/plv8/plv8).

# Parameters

This template provides the following parameters, so you can customize your deployment to your needs:


* clusterName: What your cluster will be named.

* _artifactsLocation: The repo name from which you are deploying. Default("https://raw.githubusercontent.com/HelloTech/azure_postgres/master")

* newVnet: Whether or not you want to create a new vnet. Default("yes")

* vnetGroup: The resource group in which the vnet is located. If you select yes on newVnet this needs to be set to the resource group in which you are deploying.

* lbType: Whether you want to create an external or internal load balancer. If set to internal the load balancer will only be accessible from inside the virtual network. Default("internal")

* vnetName: If newVnet is set to yes, this will be name of the created vnet. Otherwise, this is the name of already existing vnet to which the deployment will be associated.

* zookeeperNetName: If newVnet is set to yes, this will be name of the created subnet for the zookeeper machines, otherwise this is the name of already existing subnet that will contain the zookeeper vm's.

* postgresNetName: If newVnet is set to yes, this will be name of the created subnet for the postgres machines, otherwise this is the name of already existing subnet that will contain the postgres vm's.

* zookeeperVMSize: The size of zookeeper vms.

* postgresVMSize: The size of the postgres vms.

* postgresDataSize: The size of the ssd used for pg_data for the postgres vms.

* instanceCount: The number of postgres vms.

* adminUsername: The Ubuntu username.

* adminPassword: The Ubuntu password.


# Scripts

### Zookeeper
The creation of the zookeeper instances is handled by the [zookeeper_startup.sh](https://github.com/HelloTech/azure_postgres/blob/custom_deploy/zookeeper_startup.sh) script. If you would like to make any changes to what is installed on those vm's modify this file.

### Mounts
The mounting of the data ssds is handled by the [autopart.sh](https://github.com/HelloTech/azure_postgres/blob/custom_deploy/autopart.sh) script.

### Postgres
The creation of the postgres instance is handles by the [postgres_startup.sh](https://github.com/HelloTech/azure_postgres/blob/custom_deploy/postgres_startup.sh) script. If you would like to make any changes to what is installed on those vm's modify that script.

# License

Released under the MIT license. See the LICENSE file for more info.