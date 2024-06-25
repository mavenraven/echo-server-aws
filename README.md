# echo-server-aws
The purpose of this repo is to be able to fully deploy the [echo-server](https://github.com/mavenraven/echo-server) from source onto AWS.

I've been recently using [render.com](render.com), and I wanted to try to replicate its workflow. Render automatically deploys whatever is on the main branch which makes for a nice developer experience.

To accomplish this, I used AWS CodePipeline and friends. I also set up the deployments to use the blue green functionality offered by CodeDeploy.

I used ECS Fargate for the deployment target. A NAT gateway is used to allow for the Fargate VMs to pull from ECR.

I could have potentially used an ECR VPC endpoint instead. However, we would likely need to call third party services in a real app anyways.

# setup
1. `terraform apply`
2. [Set up the OAuth connection to github.](https://docs.aws.amazon.com/dtconsole/latest/userguide/connections-update.html)

# limitations and future enhancements
* The load balancer is currenly set up to only support unecrypted traffic. It would be nice to set up TLS via AWS ACM.
* The solution only supports a single AZ. This could be changed to support multiple AZs at the cost of another NAT gateway.
* The instance count is set in terraform. There's a way to do this with the `appspec.yaml` file instead.
* In the interest of time, I used a number of AWS provided policies (e.g. AmazonAPIGatewayPushToCloudWatchLogs) that aren't really appropriate for the usecase and give more permissions than necessary.
* It would be nice to have a seperate codebuild stage just for building the templated files needed for deployment.
