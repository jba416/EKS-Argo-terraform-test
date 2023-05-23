# EKS-Argo-terraform-test
With this repository you can create a Kubenernetes cluster on AWS (EKS). You must substitute the vpc, and subnet variables in the variables file. 
In the main file you must change the subnet for the ingress of argo. that will create an ingress of type load balancer. Then you can run terraform init, terraform plan and terraform apply.
once the cluster is created to access the argo application you must enter the url of the load balancer/argo.
To get the pass and user from argo: 
the user is admin.
For the password you must run the following command: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; threw out


this was created by me Jorge Arevalo-> Jba416@gmail.com
