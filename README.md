# Final Course Project
Opsschool final course project. Creates a VPC (on us-east-1 by default) with two availability zones, 
each one with two subnets, one public and one private. The public subnets contain a single NAT, a bastion 
host and two ELBs - one for Jenkins and one for ELK. The bastion host is used as an SSH jump host.
The private subnets contain an EKS master and a worker group with two autoscaling groups, one in each subnet, 
three Consul servers, an ELK server, a Jenkins master and Jenkins node and a MySQL server. All servers except for 
the bastion host are configured as Consul clients with the appropriate health checks.

The EKS contains a Prometheus and Grafana helm deployment, with a Grafana load-balancer to access it from outside.
Note that it's possible to also bring up a Prometheus load-balancer, if needed. There's also a Consul client, 
including Consul DNS and ServiceSync installed in the EKS via helm and an update to CoreDNS.

Prometheus scrapes data using consul_sd_config, and exporters: MySQL exporter, node exporter and consul exporter. 
Grafana provisioning defines Prometheus as its datasource, provisions relevant dashboards, including one tailor 
made for the myPhonebook app, and defines an alert channel.

Filebeats is installed on all servers except the bastion host, and on kubernetes. The MySQL and system modules are
enabled, and the myPhonebook application logs are collected and shipped to elasticsearch. Logstash is installed 
but currently not in use.

The Jenkins node is automatically configured to the Jenkins master. 

Metrics server is installed on EKS for HPA.

Once the Jenkins is up and the required credentials are entered, you can configure a pipeline job to get the 
phonebook app from git, dockerfy it, test it, and deploy it to EKS, on two pods with a load-balancer. 
The deployment includes and liveliness and readiness probe, and HPA definitions. 
The Jenkins pipeline also runs a basic load test on the application automatically. 

# How it's done:
Provisioning is done by terraform, as is the initial python installation and all the Consul definitions on non-k8s
servers.
Everything else is done via Ansible, running modules, scripts, helm installation, etc.  
Once the Jenkins server is up, an SSH node is defined with credentials (you will have to configure it to
select the ubuntu credentials and have a non verifying policy with the node). Docker credentials and a git
SSH key are required, before a Jenkins pipeline that pulls a Jenkinsfile from the following repo can be created
https://github.com/daximillian/phonebook.git
Define Slack credentials via a secret text to Jenkins, and then configure the Jenkins master to use them (via 
Manage Jenkins) to get a Slack message with the ELB DNS of the application. It takes the ELB several minutes to 
become available after the initial build.

# Requirements:
You will need a machine with the following installed on it to run the enviroment:
- AWS CLI (for aws configure)
- python 3.6
- terraform 0.12.20
- ansible 2.9.2 
- git

You will also need a valid AWS user configured (via aws configure or exporting your access key and secret key) 

# To run:
`git clone https://github.com/daximillian/final-course-project.git`

## Create terraform statefile S3 bucket: 
`cd terraform/global/s3`  
`terraform init`  
`terraform validate`  
`terraform plan -out S3_state.tfplan`  
`terraform apply "S3_state.tfplan"`  

## Provision:
`cd ../VPC `  
`terraform init`  
`terraform validate`  
`terraform plan -out VPC_project.tfplan`  
`terraform apply "VPC_project.tfplan"`  

## Configure/Install:
`chmod 400 VPC-demo-key.pem`
`ansible-playbook ../../../Ansible/jenkins_playbook.yml -i hosts.INI`

## To run the Jenkins playbook:
- logon to Jenkins master on port 8080 (u/p admin)
- add dockerhub credentials with the id "dockerhub.daximillian"
- add git credentials.
- add slack credentials (secret text) and configure them to Jenkins (manage Jenkins, scroll all the way to the bottom, and define slack)
- configure node to work with existing ubuntu credentials and no non-verifying host strategy
- create pipeline from scm, choose git, give it the https://github.com/daximillian/myPhonebook repo and 
your git credentials, and set it up to be triggered by git push. Then set up a webhook in GitHub on your copy of the 
phonebook repo.
- run the build job.
- After successful completion wait a minute or two for the LoadBalancer to finish provisioning. You can ssh to the 
Jenkins node using the VPC-demo-key.pem, then `export KUBECONFIG=<path_to_the_kubeconfig_opsSchool-eks_file>` and run 
`kubectl get svc` to get the address of the loadbalancer. You can also run the same from your workstation if you have kubectl and 
iam-authentication installed. Alternatively you can just logon to the AWS console and see the ELB address there,
or run `aws elb describe-load-balancers` to get the load balancer address. The build also sends the address via Slack, if you have 
that configured in your Jenkins.

## To get logon to Grafana:
- ssh to the Jenkins node using the VPC-demo-key.pem (`ssh -i "VPC-demo-key.pem" -F ssh_config ubuntu@<IP>`), then `export KUBECONFIG=./kubeconfig_opsSchool-eks` and run `kubectl get svc -n monitoring` to get the load balancer address and 
`kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo`
to get the password for Grafana.

## To access the Prometheus UI:
-  ssh to the Jenkins node using the VPC-demo-key.pem (`ssh -i "VPC-demo-key.pem" -F ssh_config ubuntu@<IP>`), then `export KUBECONFIG=./kubeconfig_opsSchool-eks` and run `kubectl patch svc prometheus-server --namespace monitoring -p '{"spec": {"type": "LoadBalancer"}}'` and `kubectl get svc -n monitoring` to get the prometheus-server load-balancer address. It takes several minutes for it to become accessible.

## To update Prometheus/Grafana:
- To change the slack token for grafana, add more scrape jobs or provision more dashboards, use the following commands to restart Prometheus and Grafana for the changes to take place:
`kubectl delete svc grafana -n monitoring`
`helm upgrade -f grafana-values.yml grafana stable/grafana -n monitoring`
`kubectl patch svc grafana --namespace monitoring -p '{"spec": {"type": "LoadBalancer"}}'`

`kubectl get svc -n monitoring`
`kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo`


`kubectl delete svc prometheus-server -n monitoring`
`helm upgrade -f prometheus-values.yml prometheus stable/prometheus -n monitoring`

## To load the ELK dashboard:
- To get to the ELK server, use the ELK load-balancer DNS address printed out by terraform and access it on the 5601 port.
- Go to Kibana
- Click on Management
- Click on Saved Objects
- Click on the Import button
- Browse ELK-dashboards.ndjson in this repo
- Import. The dashboards and info all start with `phonebook`.

## To bring everything down:
Terraform may have issues bringing the load balancers down. To avoid these issues you get bring it down yourself with `kubectl delete svc phonebook-lb` and `kubectl delete svc grafana -n monitoring` or by deleting the load balancers through the AWS console.  
Once the load-balancers is down, cd into the terraform/global/VPC directory and run:  
`terraform destroy`
Remeber - if you brought up the prometheus load-balancer, you have to delete it too via `kubectl delete svc prometheus-server -n monitoring`. 

The s3 statefile bucket is set to not allow it to be accidentaly destroyed. Make sure you know what you're doing before
destroying it.