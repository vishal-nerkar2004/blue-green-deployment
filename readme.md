# Blue-Green Deployment on AWS

A hands-on project that shows how to release a new version of an application with **zero downtime** using the Blue-Green deployment strategy on AWS. Traffic is moved between two identical environments at the load balancer level, and the old version stays running so a rollback takes only a few seconds.

## Project Details

| | |
|---|---|
| **Author** | Vishal Nerkar |
| **Region** | Asia Pacific (Mumbai) - ap-south-1 |
| **Services Used** | EC2, Application Load Balancer, Auto Scaling Group, Launch Templates, Target Groups |
| **Web Server** | Nginx (installed through EC2 User Data) |
| **Instance Type** | t3.micro |
| **Deployment Downtime** | Zero |
| **Rollback** | One listener change on the ALB |

## The Problem This Solves

In a traditional deployment the server is stopped, the code is updated and the server is started again, so users see downtime. If the new version has a bug, the rollback needs the same slow process again.

Blue-Green deployment avoids this by running two identical environments side by side. **Blue** serves live users while the new version is deployed and tested on **Green**. When Green is ready, the load balancer sends traffic to it. If something breaks, traffic goes straight back to Blue.

## Architecture

```
                         INTERNET
                             |
              +--------------+--------------+
              |   Application Load Balancer  |
              |         (myapp-alb)          |
              +--------------+--------------+
                             |
              +--------------+--------------+
              |   Listener HTTP:80 with      |
              |   weighted target groups     |
              +--------------+--------------+
                   |                    |
        +----------+----+    +----------+----+
        |  Blue Target  |    | Green Target  |
        |  Group        |    | Group         |
        |  (blue-tg)    |    | (green-tg)    |
        +----------+----+    +----------+----+
                   |                    |
        +----------+----+    +----------+----+
        |  Blue Auto    |    | Green Auto    |
        |  Scaling Group|    | Scaling Group |
        |  (blue-asg)   |    | (green-asg)   |
        |               |    |               |
        |  EC2 - 1a     |    |  EC2 - 1a     |
        |  Version 1.0  |    |  Version 2.0  |
        |               |    |               |
        |  EC2 - 1b     |    |  EC2 - 1b     |
        |  Version 1.0  |    |  Version 2.0  |
        +---------------+    +---------------+
```

Both environments are spread across two Availability Zones (ap-south-1a and ap-south-1b), so the application keeps running even if one zone has a problem.

## Repository Structure

```
blue-green-deployment-aws/
|
|-- README.md
|
|-- blue/
|   |-- user-data.sh          (Blue server startup script - Version 1.0)
|
|-- green/
|   |-- user-data.sh          (Green server startup script - Version 2.0)
|
|-- docs/
    |-- screenshots/
        |-- 01_Blue_Launch_Template_created.png
        |-- 02_Blue_TG_created.png
        |-- 03_Blue_ASG.png
        |-- 04_Blue_ASG_running_with_2_healthy_instances.png
        |-- 05_ALB_active.png
        |-- 06_Blue_website_live_in_browser.png
        |-- 07_Green_Launch_Template_created.png
        |-- 08_Green_TG_created.png
        |-- 09_Green_ASG_created.png
        |-- 10_Blue_and_Green_instances_running.png
        |-- 11_Green_website_verified_directly.png
        |-- 12_Green_now_live_through_ALB.png
        |-- 13_Rolled_back_to_Blue.png
        |-- 14_80_Green_20_Blue.png
        |-- 15_50-50_split.png
        |-- 16_0_Blue_100_Green.png
        |-- 17_Full_Green_deployment_complete.png
```

## How I Built This

### Phase 1 - Blue Environment (Version 1.0)

Blue is the live environment that serves real user traffic.

#### Step 1 - Launch Template

A Launch Template stores the settings used to create EC2 instances: instance type, security group and startup script. The Auto Scaling Group uses it to create identical servers.

I created `blue-launch-template` (t3.micro) with a User Data script that installs Nginx and deploys the Version 1.0 page on first boot, so no manual SSH is needed. The script is in [`blue/user-data.sh`](blue/user-data.sh).

Screenshot: `01_Blue_Launch_Template_created.png`

![Blue Launch Template](docs/screenshots/01_Blue_Launch_Template_created.png)

#### Step 2 - Target Group

A Target Group is the list of servers that the load balancer sends traffic to. The ALB runs health checks on each target and stops sending traffic to any server that fails.

I created `blue-tg` with protocol HTTP on port 80 and target type Instance.

Screenshot: `02_Blue_TG_created.png`

![Blue Target Group](docs/screenshots/02_Blue_TG_created.png)

#### Step 3 - Auto Scaling Group

The Auto Scaling Group keeps the required number of servers running. If a server fails, it launches a replacement from the Launch Template automatically.

I created `blue-asg` using `blue-launch-template` with desired capacity 2 and scaling limits 2 to 4. The group shows **2/2 Healthy** instances.

Screenshot: `03_Blue_ASG.png`

![Blue ASG](docs/screenshots/03_Blue_ASG.png)

Both Blue instances (one in ap-south-1a and one in ap-south-1b) are in the Running state and have passed 3/3 status checks.

Screenshot: `04_Blue_ASG_running_with_2_healthy_instances.png`

![Blue ASG instances running](docs/screenshots/04_Blue_ASG_running_with_2_healthy_instances.png)

#### Step 4 - Application Load Balancer

The ALB is the single entry point for users. They never connect to EC2 instances directly. The ALB receives each request and forwards it to a healthy server in the target group.

I created `myapp-alb` as an internet-facing Application Load Balancer with an HTTP:80 listener forwarding to `blue-tg`. The state is **Active**.

Screenshot: `05_ALB_active.png`

![ALB Active](docs/screenshots/05_ALB_active.png)

#### Step 5 - Verified Blue is Live

I opened the ALB DNS name in the browser and confirmed that Version 1.0 from the Blue environment is served.

Screenshot: `06_Blue_website_live_in_browser.png`

![Blue website live](docs/screenshots/06_Blue_website_live_in_browser.png)

### Phase 2 - Green Environment (Version 2.0)

Green is the new version. It is built and tested before any user traffic is sent to it.

#### Step 6 - Green Launch Template

I created `green-launch-template` with a new User Data script that deploys Version 2.0. The script is in [`green/user-data.sh`](green/user-data.sh).

Screenshot: `07_Green_Launch_Template_created.png`

![Green Launch Template](docs/screenshots/07_Green_Launch_Template_created.png)

#### Step 7 - Green Target Group

I created `green-tg` with the same settings as `blue-tg` (HTTP, port 80, target type Instance).

Screenshot: `08_Green_TG_created.png`

![Green Target Group](docs/screenshots/08_Green_TG_created.png)

#### Step 8 - Green Auto Scaling Group

I created `green-asg` from `green-launch-template` and attached it to `green-tg`, with desired capacity 2 and scaling limits 2 to 4. The group shows **2/2 Healthy** instances.

Screenshot: `09_Green_ASG_created.png`

![Green ASG](docs/screenshots/09_Green_ASG_created.png)

Now Blue and Green run side by side: 2 Blue and 2 Green instances in ap-south-1a and ap-south-1b. Blue serves all live traffic and Green receives none.

Screenshot: `10_Blue_and_Green_instances_running.png`

![Blue and Green instances](docs/screenshots/10_Blue_and_Green_instances_running.png)

#### Step 9 - Tested Green Directly

Before sending any user traffic to Green, I opened a Green instance by its public IP address and confirmed that Version 2.0 works. Never switch traffic to an environment that has not been tested.

Screenshot: `11_Green_website_verified_directly.png`

![Green verified directly](docs/screenshots/11_Green_website_verified_directly.png)

### Phase 3 - Zero Downtime Deployment

#### Step 10 - Switch Traffic from Blue to Green

I edited the ALB listener (HTTP:80) so that it forwards to `green-tg` instead of `blue-tg`. The same ALB URL now shows Version 2.0.

ALB -> Listeners -> Edit HTTP:80 -> change the target group from `blue-tg` to `green-tg`.

Screenshot: `12_Green_now_live_through_ALB.png`

![Green live through ALB](docs/screenshots/12_Green_now_live_through_ALB.png)

#### Step 11 - Rollback Test

To test the rollback, I pointed the listener back to `blue-tg`. The ALB URL immediately served Version 1.0 again. Blue was kept running for exactly this situation.

Screenshot: `13_Rolled_back_to_Blue.png`

![Rolled back to Blue](docs/screenshots/13_Rolled_back_to_Blue.png)

### Phase 4 - Canary Deployment

Instead of moving all users at once, a canary deployment shifts traffic to the new version in steps, so it can be checked at each step before it takes all the traffic. This is done with the weights of the target groups on the listener.

#### Step 12 - 80% Green / 20% Blue

| Target Group | Weight | % of Traffic |
|---|---|---|
| green-tg | 80 | 80% |
| blue-tg | 20 | 20% |

Screenshot: `14_80_Green_20_Blue.png`

![80/20 split](docs/screenshots/14_80_Green_20_Blue.png)

#### Step 13 - 50% Green / 50% Blue

| Target Group | Weight | % of Traffic |
|---|---|---|
| green-tg | 50 | 50% |
| blue-tg | 50 | 50% |

Screenshot: `15_50-50_split.png`

![50/50 split](docs/screenshots/15_50-50_split.png)

#### Step 14 - 0% Blue / 100% Green

Green stayed stable at 50%, so I moved all traffic to Green by setting the Blue weight to 0.

| Target Group | Weight | % of Traffic |
|---|---|---|
| green-tg | 100 | 100% |
| blue-tg | 0 | 0% |

Screenshot: `16_0_Blue_100_Green.png`

![0% Blue 100% Green](docs/screenshots/16_0_Blue_100_Green.png)

#### Step 15 - Full Green Deployment Complete

Finally, `blue-tg` was removed from the listener, so the listener forwards 100% of the traffic only to `green-tg`. The migration from Blue to Green is complete.

Screenshot: `17_Full_Green_deployment_complete.png`

![Full Green deployment complete](docs/screenshots/17_Full_Green_deployment_complete.png)

## Results Summary

| What was tested | Result |
|---|---|
| Deployment downtime | Zero |
| Rollback | Done by changing one listener rule |
| Canary steps completed | 80/20, 50/50, 100/0 (Green/Blue) |
| Availability Zones | 2 (ap-south-1a, ap-south-1b) |
| Total EC2 instances | 4 (2 Blue + 2 Green) |

## Key Concepts

**Blue-Green Deployment** - Two identical environments run at the same time. Blue is live and Green gets the new version. Traffic is switched at the load balancer, and Blue stays available for rollback.

**Canary Deployment** - Traffic moves to the new version in steps (for example 20%, 50%, 100%), which limits the impact of any issue.

**Auto Scaling Group** - Keeps the desired number of healthy instances running and replaces failed ones using the Launch Template.

**Multi-AZ Availability** - Servers in more than one Availability Zone keep the application running if one zone fails.

## Cost Note

The Application Load Balancer is not covered by the AWS Free Tier. After finishing the project, delete the resources in this order to stop all charges:

1. Delete both Auto Scaling Groups (this terminates the EC2 instances)
2. Delete the Application Load Balancer
3. Delete both Target Groups
4. Delete both Launch Templates

## What I Learned

- How weighted target groups on an ALB listener control the traffic split between two environments.
- Why the old (Blue) environment should keep running after the switch: it makes rollback instant.
- How Launch Templates and Auto Scaling Groups keep both environments identical.
- Why a new environment must be tested directly (by instance IP) before any user traffic is sent to it.

## Connect

- **LinkedIn:** https://www.linkedin.com/in/nerkarvishal
- **GitHub:** https://github.com/vishal-nerkar2004
- **Email:** vishalnerkar418@gmail.com
- **Location:** Pune, Maharashtra, India